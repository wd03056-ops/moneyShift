/**
 * 월간 인건비 집계 (사업장 · 1일~오늘 또는 해당 월 전체)
 *
 * 데이터: Firestore schedules + room_members(시급)
 * 기본: 실근로시간(휴게 차감) × 시급
 * 옵션: 주휴수당, 사업주 4대보험 추정
 */
const { getAdmin, isConfigured } = require('./firebaseAdmin');

/** 사업주 4대보험 부담률 추정 (연금·건강·고용·산재 대략치) */
const DEFAULT_EMPLOYER_INSURANCE_RATE = 0.099;

const WEEKLY_STANDARD_HOURS = 40;
const WEEKLY_HOLIDAY_HOURS = 8;

function pad2(n) {
  return String(n).padStart(2, '0');
}

function dateKey(y, m, d) {
  return `${y}-${pad2(m)}-${pad2(d)}`;
}

function daysInMonth(y, m) {
  return new Date(y, m, 0).getDate();
}

function parseDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') {
    try {
      return value.toDate();
    } catch {
      return null;
    }
  }
  if (typeof value === 'string' || typeof value === 'number') {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof value === 'object' && value._seconds != null) {
    return new Date(value._seconds * 1000);
  }
  return null;
}

function suggestedBreakMinutes(totalWorkedMinutes) {
  if (totalWorkedMinutes >= 8 * 60) return 60;
  if (totalWorkedMinutes >= 4 * 60) return 30;
  return 0;
}

function resolveBreakMinutes(data, totalWorkedMinutes) {
  const type = data.breakTimeType || data.breakType;
  if (type === 'none') return 0;
  if (typeof data.breakMinutes === 'number') {
    return Math.max(0, Math.min(data.breakMinutes, totalWorkedMinutes));
  }
  if (typeof data.fixedBreakMinutes === 'number' && type === 'fixed') {
    return Math.max(0, Math.min(data.fixedBreakMinutes, totalWorkedMinutes));
  }
  return suggestedBreakMinutes(totalWorkedMinutes);
}

/**
 * @param {{
 *   roomId: string,
 *   year: number,
 *   month: number,
 *   includeWeeklyHoliday?: boolean,
 *   includeEmployerSocialInsurance?: boolean,
 *   employerSocialInsuranceRate?: number,
 * }} input
 */
async function computeMonthlyLaborCost(input) {
  if (!isConfigured()) {
    const err = new Error('firebase_admin_not_configured');
    err.code = 'firebase_admin_not_configured';
    throw err;
  }

  const { db } = getAdmin();
  if (!db) {
    const err = new Error('firebase_admin_not_configured');
    err.code = 'firebase_admin_not_configured';
    throw err;
  }

  const roomId = String(input.roomId || '').trim();
  const year = Number(input.year);
  const month = Number(input.month);
  if (!roomId) {
    const err = new Error('room_id_required');
    err.code = 'room_id_required';
    throw err;
  }
  if (!Number.isInteger(year) || year < 2000 || year > 2100) {
    const err = new Error('invalid_year');
    err.code = 'invalid_year';
    throw err;
  }
  if (!Number.isInteger(month) || month < 1 || month > 12) {
    const err = new Error('invalid_month');
    err.code = 'invalid_month';
    throw err;
  }

  const includeWeeklyHoliday = Boolean(input.includeWeeklyHoliday);
  const includeEmployerSocialInsurance = Boolean(
    input.includeEmployerSocialInsurance,
  );
  const insuranceRate =
    typeof input.employerSocialInsuranceRate === 'number' &&
    input.employerSocialInsuranceRate >= 0 &&
    input.employerSocialInsuranceRate <= 1
      ? input.employerSocialInsuranceRate
      : DEFAULT_EMPLOYER_INSURANCE_RATE;

  const now = new Date();
  const dim = daysInMonth(year, month);
  const isCurrentMonth =
    now.getFullYear() === year && now.getMonth() + 1 === month;
  const endDay = isCurrentMonth
    ? Math.min(now.getDate(), dim)
    : dim;
  const fromKey = dateKey(year, month, 1);
  const toKey = dateKey(year, month, endDay);

  // 멤버 시급 맵
  const wageByUser = new Map();
  const nameByUser = new Map();
  try {
    const membersSnap = await db
      .collection('room_members')
      .where('roomId', '==', roomId)
      .limit(200)
      .get();
    for (const doc of membersSnap.docs) {
      const m = doc.data() || {};
      const uid = String(m.userId || '').trim();
      if (!uid) continue;
      const contract = m.contract && typeof m.contract === 'object'
        ? m.contract
        : null;
      const wage = Number(
        (contract && contract.hourlyWage) || m.hourlyWage || 0,
      );
      wageByUser.set(uid, wage > 0 ? Math.round(wage) : 10320);
      const name = String(m.displayName || m.realName || '').trim();
      if (name) nameByUser.set(uid, name);
      // 계약 옵션 — 주휴 기본은 요청 플래그, 멤버 계약이 켜져 있으면 OR
      if (contract && contract.isWeekPayEnabled) {
        // per-worker flag stored later via wage map side channel
        wageByUser.set(`${uid}__week`, 1);
      }
    }
  } catch (e) {
    console.error('[laborCost] room_members query', e.message || e);
  }

  // 스케줄 — roomId 조회 후 기간 필터 (인덱스 의존 최소화)
  let scheduleDocs = [];
  try {
    const snap = await db
      .collection('schedules')
      .where('roomId', '==', roomId)
      .limit(2000)
      .get();
    scheduleDocs = snap.docs;
  } catch (e) {
    console.error('[laborCost] schedules query', e.message || e);
    const err = new Error('schedules_query_failed');
    err.code = 'schedules_query_failed';
    err.cause = e;
    throw err;
  }

  /** @type {Map<string, { workerId: string, displayName: string, hours: number, basePay: number, weeklyHolidayPay: number, shifts: number }>} */
  const byWorker = new Map();

  let totalBasePay = 0;
  let totalWeeklyHolidayPay = 0;
  let totalNetMinutes = 0;

  for (const doc of scheduleDocs) {
    const s = doc.data() || {};
    if (s.isAbsent === true) continue;
    const date = String(s.date || '').trim();
    if (!date || date < fromKey || date > toKey) continue;

    const workerId = String(s.workerId || s.userId || '').trim();
    if (!workerId) continue;

    const start = parseDate(s.startTime);
    const end = parseDate(s.endTime);
    if (!start || !end) continue;

    let totalMinutes = Math.round((end.getTime() - start.getTime()) / 60000);
    if (totalMinutes <= 0) continue;
    if (totalMinutes > 24 * 60) totalMinutes = 24 * 60;

    const breakMin = resolveBreakMinutes(s, totalMinutes);
    const netMinutes = Math.max(0, totalMinutes - breakMin);
    const netHours = netMinutes / 60;

    let wage = wageByUser.get(workerId);
    if (wage == null || wage <= 0) {
      wage = Number(s.hourlyWage) || Number(s.payEstimate?.hourlyWage) || 10320;
    }

    let basePay = 0;
    let weeklyHolidayPay = 0;

    if (s.payEstimate && typeof s.payEstimate === 'object') {
      const pe = s.payEstimate;
      basePay = Math.round(Number(pe.basePay) || 0);
      weeklyHolidayPay = Math.round(Number(pe.weeklyHolidayPay) || 0);
      const peNet = Number(pe.netWorkedMinutes ?? pe.workedMinutes);
      if (Number.isFinite(peNet) && peNet > 0) {
        // prefer estimate minutes if present
        totalNetMinutes += peNet;
      } else {
        totalNetMinutes += netMinutes;
      }
    } else if (typeof s.estimatedPay === 'number' && s.estimatedPay > 0) {
      basePay = Math.round(s.estimatedPay);
      totalNetMinutes += netMinutes;
    } else {
      basePay = Math.round(netHours * wage);
      totalNetMinutes += netMinutes;
    }

    const workerWantsWeek =
      includeWeeklyHoliday ||
      s.includeWeeklyHoliday === true ||
      wageByUser.get(`${workerId}__week`) === 1;

    if (workerWantsWeek && weeklyHolidayPay <= 0) {
      weeklyHolidayPay = Math.round(
        (netHours / WEEKLY_STANDARD_HOURS) * WEEKLY_HOLIDAY_HOURS * wage,
      );
    }
    if (!workerWantsWeek) {
      weeklyHolidayPay = 0;
    }

    totalBasePay += basePay;
    totalWeeklyHolidayPay += weeklyHolidayPay;

    const row = byWorker.get(workerId) || {
      workerId,
      displayName: nameByUser.get(workerId) || workerId,
      hours: 0,
      basePay: 0,
      weeklyHolidayPay: 0,
      shifts: 0,
    };
    row.hours += netHours;
    row.basePay += basePay;
    row.weeklyHolidayPay += weeklyHolidayPay;
    row.shifts += 1;
    byWorker.set(workerId, row);
  }

  const totalLaborCost = totalBasePay + totalWeeklyHolidayPay;
  const employerSocialInsuranceEstimate = includeEmployerSocialInsurance
    ? Math.round(totalLaborCost * insuranceRate)
    : 0;

  const workers = [...byWorker.values()]
    .map((w) => ({
      workerId: w.workerId,
      displayName: w.displayName,
      workHours: Math.round(w.hours * 100) / 100,
      laborCost: w.basePay + w.weeklyHolidayPay,
      basePay: w.basePay,
      weeklyHolidayPay: w.weeklyHolidayPay,
      shiftCount: w.shifts,
    }))
    .sort((a, b) => b.laborCost - a.laborCost);

  const totalWorkHours = Math.round((totalNetMinutes / 60) * 100) / 100;

  return {
    ok: true,
    roomId,
    year,
    month,
    period: { from: fromKey, to: toKey },
    totalLaborCost,
    totalWorkHours,
    activeWorkerCount: workers.length,
    options: {
      includeWeeklyHoliday,
      includeEmployerSocialInsurance,
      employerSocialInsuranceRate: insuranceRate,
    },
    breakdown: {
      basePay: totalBasePay,
      weeklyHolidayPay: totalWeeklyHolidayPay,
      employerSocialInsuranceEstimate,
      totalWithEmployerBurden:
        totalLaborCost + employerSocialInsuranceEstimate,
    },
    byWorker: workers,
  };
}

module.exports = {
  computeMonthlyLaborCost,
  DEFAULT_EMPLOYER_INSURANCE_RATE,
};
