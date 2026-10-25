/**
 * 월간 인건비 집계 (사업장 · 1일~오늘 또는 해당 월 전체)
 *
 * 기준: attendance_logs 퇴근 확정분만 + room_members 계약 수당
 * (배정 확인만으로는 집계하지 않음)
 * 주휴: 주 실근로 ≥15시간일 때만 (주 단위 합산)
 */
const { getAdmin, isConfigured } = require('./firebaseAdmin');
const {
  suggestedBreakMinutes,
  estimate,
  weekMondayKey,
  weeklyHolidayPayForNetMinutes,
  nightOverlapMinutes,
} = require('./payrollCalc');

/** 사업주 4대보험 부담률 추정 */
const DEFAULT_EMPLOYER_INSURANCE_RATE = 0.099;

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

function resolveBreakMinutes(data, totalWorkedMinutes, contract) {
  if (contract) {
    const type = contract.breakTimeType || contract.breakType;
    if (type === 'none') return 0;
    if (type === 'fixed') {
      const fixed = Number(contract.fixedBreakMinutes);
      if (Number.isFinite(fixed)) {
        return Math.max(0, Math.min(fixed, totalWorkedMinutes));
      }
    }
  }
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

function dayKeyFromDate(d) {
  return dateKey(d.getFullYear(), d.getMonth() + 1, d.getDate());
}

/**
 * attendance_logs → userId → dayKey → [{start,end}]
 */
function pairAttendanceIntervals(logs) {
  /** @type {Map<string, Map<string, Array<{start: Date, end: Date}>>>} */
  const byUserDay = new Map();

  /** @type {Map<string, Array<{type: string, at: Date}>>} */
  const byUser = new Map();
  for (const log of logs) {
    const uid = String(log.userId || '').trim();
    const type = String(log.type || '').trim();
    const at = parseDate(log.timestamp);
    if (!uid || !at) continue;
    if (type !== 'clock_in' && type !== 'clock_out' && type !== 'clockIn' && type !== 'clockOut') {
      continue;
    }
    const normalized =
      type === 'clock_in' || type === 'clockIn' ? 'in' : 'out';
    if (!byUser.has(uid)) byUser.set(uid, []);
    byUser.get(uid).push({ type: normalized, at });
  }

  for (const [uid, events] of byUser.entries()) {
    events.sort((a, b) => a.at - b.at);
    let openIn = null;
    for (const ev of events) {
      if (ev.type === 'in') {
        openIn = ev.at;
      } else if (ev.type === 'out' && openIn) {
        const key = dayKeyFromDate(openIn);
        if (!byUserDay.has(uid)) byUserDay.set(uid, new Map());
        const dayMap = byUserDay.get(uid);
        if (!dayMap.has(key)) dayMap.set(key, []);
        dayMap.get(key).push({ start: openIn, end: ev.at });
        openIn = null;
      }
    }
  }
  return byUserDay;
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
  const endDay = isCurrentMonth ? Math.min(now.getDate(), dim) : dim;
  const fromKey = dateKey(year, month, 1);
  const toKey = dateKey(year, month, endDay);
  const monthPrefix = `${year}-${pad2(month)}`;

  /** @type {Map<string, { wage: number, name: string, week: boolean, ot: boolean, night: boolean, contract: object|null }>} */
  const members = new Map();
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
      if (m.isActive === false) continue;
      const contract =
        m.contract && typeof m.contract === 'object' ? m.contract : null;
      const wage = Number(
        (contract && contract.hourlyWage) || m.hourlyWage || 0,
      );
      members.set(uid, {
        wage: wage > 0 ? Math.round(wage) : 10320,
        name: String(m.displayName || m.realName || '').trim() || uid,
        week: Boolean(contract && contract.isWeekPayEnabled),
        ot: Boolean(contract && contract.isOvertimePayEnabled),
        night: Boolean(contract && contract.isNightPayEnabled),
        contract,
      });
    }
  } catch (e) {
    console.error('[laborCost] room_members query', e.message || e);
  }

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

  /** date → schedules[] */
  const schedulesByWorkerDay = new Map();
  for (const doc of scheduleDocs) {
    const s = doc.data() || {};
    if (s.isAbsent === true) continue;
    const date = String(s.date || '').trim();
    if (!date || date < fromKey || date > toKey) continue;
    const workerId = String(s.workerId || s.userId || '').trim();
    if (!workerId) continue;
    const key = `${workerId}__${date}`;
    if (!schedulesByWorkerDay.has(key)) schedulesByWorkerDay.set(key, []);
    schedulesByWorkerDay.get(key).push(s);
  }

  let attendanceLogs = [];
  try {
    const snap = await db
      .collection('attendance_logs')
      .where('roomId', '==', roomId)
      .limit(5000)
      .get();
    attendanceLogs = snap.docs.map((d) => d.data() || {});
  } catch (e) {
    console.error('[laborCost] attendance_logs query', e.message || e);
    // 인덱스/권한 문제 시 실출퇴근 없이 0원 집계
  }

  const intervalsByUser = pairAttendanceIntervals(attendanceLogs);

  /** @type {Map<string, { workerId: string, displayName: string, hours: number, basePay: number, weeklyHolidayPay: number, overtimePay: number, shifts: number }>} */
  const byWorker = new Map();

  let totalBasePay = 0;
  let totalWeeklyHolidayPay = 0;
  let totalOvertimePay = 0;
  let totalNetMinutes = 0;

  const workerIds = new Set([
    ...members.keys(),
    ...intervalsByUser.keys(),
  ]);
  for (const key of schedulesByWorkerDay.keys()) {
    workerIds.add(key.split('__')[0]);
  }

  for (const workerId of workerIds) {
    const meta = members.get(workerId) || {
      wage: 10320,
      name: workerId,
      week: false,
      ot: false,
      night: false,
      contract: null,
    };
    const wantWeek = includeWeeklyHoliday || meta.week;
    const dayMap = intervalsByUser.get(workerId) || new Map();

    /** @type {Record<string, number>} */
    const netByWeek = {};
    let workerBase = 0;
    let workerOt = 0;
    let workerNet = 0;
    let workerShifts = 0;

    // 실출퇴근(퇴근 확정)만 집계
    for (const [day, intervals] of dayMap.entries()) {
      if (!day.startsWith(monthPrefix) || day < fromKey || day > toKey) {
        continue;
      }
      const daySchedules = schedulesByWorkerDay.get(`${workerId}__${day}`) || [];
      if (daySchedules.length === 0) continue; // 배정 없는 날 미산정

      const scheduleOt = daySchedules.some((s) => s.includeOvertimeNight === true);
      const wantOt = meta.ot || scheduleOt;
      const wantNight = meta.night || scheduleOt;

      let dayNet = 0;
      let dayBase = 0;
      let dayOtPay = 0;
      for (const iv of intervals) {
        const gross = Math.round(
          (iv.end.getTime() - iv.start.getTime()) / 60000,
        );
        if (gross <= 0) continue;
        const br = resolveBreakMinutes(
          daySchedules[0] || {},
          gross,
          meta.contract,
        );
        const e = estimate({
          startTime: iv.start,
          endTime: iv.end,
          hourlyWage: meta.wage,
          breakMinutes: br,
          includeWeeklyHoliday: false,
          includeOvertime: wantOt,
          includeNight: wantNight,
        });
        dayBase += e.basePay;
        dayOtPay += e.overtimeNightPay;
        dayNet += e.netWorkedMinutes;
      }
      if (dayNet <= 0) continue;

      // 다구간 연장 합산 보정
      if (wantOt && intervals.length > 1 && dayNet > 8 * 60) {
        const otMin = dayNet - 8 * 60;
        let nightMin = 0;
        if (wantNight) {
          for (const iv of intervals) {
            nightMin += nightOverlapMinutes(iv.start, iv.end);
          }
        }
        dayOtPay = Math.round(((otMin + nightMin) / 60) * meta.wage * 0.5);
      }

      workerBase += dayBase;
      workerOt += dayOtPay;
      workerNet += dayNet;
      workerShifts += 1;
      const wk = weekMondayKey(new Date(day + 'T12:00:00'));
      netByWeek[wk] = (netByWeek[wk] || 0) + dayNet;
    }

    // 배정만 있고 퇴근 없으면 인건비에 포함하지 않음
    if (workerNet <= 0 && workerShifts === 0) continue;

    let workerWeekly = 0;
    if (wantWeek) {
      for (const net of Object.values(netByWeek)) {
        workerWeekly += weeklyHolidayPayForNetMinutes(net, meta.wage);
      }
    }

    totalBasePay += workerBase;
    totalOvertimePay += workerOt;
    totalWeeklyHolidayPay += workerWeekly;
    totalNetMinutes += workerNet;

    byWorker.set(workerId, {
      workerId,
      displayName: meta.name,
      hours: workerNet / 60,
      basePay: workerBase + workerOt,
      weeklyHolidayPay: workerWeekly,
      overtimePay: workerOt,
      shifts: workerShifts,
    });
  }

  const totalLaborCost =
    totalBasePay + totalOvertimePay + totalWeeklyHolidayPay;
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
      basePay: totalBasePay + totalOvertimePay,
      weeklyHolidayPay: totalWeeklyHolidayPay,
      overtimeNightPay: totalOvertimePay,
      employerSocialInsuranceEstimate,
      totalWithEmployerBurden:
        totalLaborCost + employerSocialInsuranceEstimate,
    },
    byWorker: workers,
    source: 'api',
  };
}

module.exports = {
  computeMonthlyLaborCost,
  DEFAULT_EMPLOYER_INSURANCE_RATE,
};
