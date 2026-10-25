/**
 * Dart PayrollCalculator 와 동일한 규칙 (시급·휴게·연장·야간·주휴)
 */

const STANDARD_DAY_MINUTES = 8 * 60;
const WEEKLY_HOLIDAY_HOURS = 8;
const WEEKLY_STANDARD_HOURS = 40;
const WEEKLY_HOLIDAY_THRESHOLD_MINUTES = 15 * 60;

function suggestedBreakMinutes(totalWorkedMinutes) {
  if (totalWorkedMinutes >= STANDARD_DAY_MINUTES) return 60;
  if (totalWorkedMinutes >= 4 * 60) return 30;
  return 0;
}

function nightOverlapMinutes(start, end) {
  if (!(end instanceof Date) || !(start instanceof Date)) return 0;
  if (end.getTime() <= start.getTime()) return 0;
  let total = 0;
  let t = new Date(start.getTime());
  while (t < end) {
    const hourStart = new Date(
      t.getFullYear(),
      t.getMonth(),
      t.getDate(),
      t.getHours(),
      0,
      0,
      0,
    );
    const nextHour = new Date(hourStart.getTime() + 60 * 60 * 1000);
    const segmentEnd = nextHour < end ? nextHour : end;
    const hour = t.getHours();
    if (hour >= 22 || hour < 6) {
      total += Math.round((segmentEnd.getTime() - t.getTime()) / 60000);
    }
    t = segmentEnd;
  }
  return total;
}

function weeklyHolidayPayForNetMinutes(netWorkedMinutes, hourlyWage) {
  if (hourlyWage <= 0 || netWorkedMinutes < WEEKLY_HOLIDAY_THRESHOLD_MINUTES) {
    return 0;
  }
  const netHours = netWorkedMinutes / 60;
  return Math.round(
    (netHours / WEEKLY_STANDARD_HOURS) * WEEKLY_HOLIDAY_HOURS * hourlyWage,
  );
}

/**
 * @param {{
 *   startTime: Date,
 *   endTime: Date,
 *   hourlyWage: number,
 *   breakMinutes?: number,
 *   includeWeeklyHoliday?: boolean,
 *   includeOvertime?: boolean,
 *   includeNight?: boolean,
 *   includeOvertimeNight?: boolean,
 * }} input
 */
function estimate(input) {
  const hourlyWage = Number(input.hourlyWage) || 0;
  const start = input.startTime;
  const end = input.endTime;
  const wantOt =
    input.includeOvertime != null
      ? Boolean(input.includeOvertime)
      : Boolean(input.includeOvertimeNight);
  const wantNight =
    input.includeNight != null
      ? Boolean(input.includeNight)
      : Boolean(input.includeOvertimeNight);
  const includeWeeklyHoliday = Boolean(input.includeWeeklyHoliday);

  let totalMinutes = Math.round((end.getTime() - start.getTime()) / 60000);
  if (hourlyWage <= 0 || totalMinutes <= 0) {
    return {
      hourlyWage,
      totalWorkedMinutes: Math.max(0, Math.min(totalMinutes, 24 * 60)),
      breakMinutes: 0,
      netWorkedMinutes: 0,
      basePay: 0,
      weeklyHolidayPay: 0,
      overtimeNightPay: 0,
      overtimeMinutes: 0,
      nightMinutes: 0,
    };
  }
  if (totalMinutes > 24 * 60) totalMinutes = 24 * 60;

  const safeBreak = Math.max(
    0,
    Math.min(Number(input.breakMinutes) || 0, totalMinutes),
  );
  const netMinutes = totalMinutes - safeBreak;
  const basePay = Math.round((netMinutes / 60) * hourlyWage);

  let overtimeMinutes = 0;
  let nightMinutes = 0;
  if (wantOt && netMinutes > STANDARD_DAY_MINUTES) {
    overtimeMinutes = netMinutes - STANDARD_DAY_MINUTES;
  }
  if (wantNight) {
    nightMinutes = nightOverlapMinutes(start, end);
  }
  const overtimeNightPay = Math.round(
    ((overtimeMinutes + nightMinutes) / 60) * hourlyWage * 0.5,
  );

  let weeklyHolidayPay = 0;
  if (includeWeeklyHoliday) {
    weeklyHolidayPay = weeklyHolidayPayForNetMinutes(netMinutes, hourlyWage);
  }

  return {
    hourlyWage,
    totalWorkedMinutes: totalMinutes,
    breakMinutes: safeBreak,
    netWorkedMinutes: netMinutes,
    basePay,
    weeklyHolidayPay,
    overtimeNightPay,
    overtimeMinutes,
    nightMinutes,
  };
}

/** 월요일 yyyy-MM-dd (로컬 타임존) */
function weekMondayKey(date) {
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const day = d.getDay(); // 0 Sun
  const diff = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${dd}`;
}

function weeklyHolidayPayForWeekMap(netByWeekMonday, hourlyWage) {
  let total = 0;
  for (const net of Object.values(netByWeekMonday)) {
    total += weeklyHolidayPayForNetMinutes(net, hourlyWage);
  }
  return total;
}

module.exports = {
  STANDARD_DAY_MINUTES,
  WEEKLY_HOLIDAY_THRESHOLD_MINUTES,
  suggestedBreakMinutes,
  nightOverlapMinutes,
  weeklyHolidayPayForNetMinutes,
  estimate,
  weekMondayKey,
  weeklyHolidayPayForWeekMap,
};
