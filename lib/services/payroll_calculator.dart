import '../models/pay_estimate.dart';
import '../models/schedule_model.dart';

/// 시급·근무시간·휴게·수당 옵션 기준 예상 급여 계산
///
/// - 총 근무: 출퇴근 차이
/// - 실 근로: 총 근무 − 무급 휴게
/// - 기본급: 시급 × 실 근로시간
/// - 연장: 실 근로 8시간 초과분에 시급 × 0.5 가산
/// - 야간: 22:00~06:00 구간에 시급 × 0.5 가산
/// - 주휴: `(실근로시간/40)×8×시급`
class PayrollCalculator {
  PayrollCalculator._();

  static const int standardDayMinutes = 8 * 60;
  static const double weeklyHolidayHours = 8;
  static const double weeklyStandardHours = 40;
  static const double weeklyHolidayThresholdHours = 15;

  /// 총 근무 시간 기준 권장 휴게(분) — 4h↑ 30분, 8h↑ 60분
  static int suggestedBreakMinutes(int totalWorkedMinutes) {
    if (totalWorkedMinutes >= standardDayMinutes) return 60;
    if (totalWorkedMinutes >= 4 * 60) return 30;
    return 0;
  }

  /// 하위 호환: 총액만 필요할 때
  static int estimatePay({
    required DateTime startTime,
    required DateTime endTime,
    required int hourlyWage,
    int breakMinutes = 0,
    bool includeWeeklyHoliday = false,
    bool includeOvertimeNight = false,
  }) {
    return estimate(
      startTime: startTime,
      endTime: endTime,
      hourlyWage: hourlyWage,
      breakMinutes: breakMinutes,
      includeWeeklyHoliday: includeWeeklyHoliday,
      includeOvertimeNight: includeOvertimeNight,
    ).total;
  }

  static PayEstimate estimate({
    required DateTime startTime,
    required DateTime endTime,
    required int hourlyWage,
    int breakMinutes = 0,
    bool includeWeeklyHoliday = false,
    bool includeOvertimeNight = false,
  }) {
    final totalMinutes = endTime.difference(startTime).inMinutes;
    if (hourlyWage <= 0 || totalMinutes <= 0) {
      return PayEstimate(
        hourlyWage: hourlyWage,
        totalWorkedMinutes: totalMinutes.clamp(0, 24 * 60),
        breakMinutes: 0,
        netWorkedMinutes: 0,
        basePay: 0,
        includeWeeklyHoliday: includeWeeklyHoliday,
        includeOvertimeNight: includeOvertimeNight,
      );
    }

    final safeBreak = breakMinutes.clamp(0, totalMinutes);
    final netMinutes = totalMinutes - safeBreak;
    final netHours = netMinutes / 60.0;
    final basePay = (netHours * hourlyWage).round();

    var overtimeMinutes = 0;
    var nightMinutes = 0;
    var overtimeNightPay = 0;
    if (includeOvertimeNight) {
      overtimeMinutes = netMinutes > standardDayMinutes
          ? netMinutes - standardDayMinutes
          : 0;
      nightMinutes = _nightOverlapMinutes(startTime, endTime);
      final premiumHours = (overtimeMinutes + nightMinutes) / 60.0;
      overtimeNightPay = (premiumHours * hourlyWage * 0.5).round();
    }

    var weeklyHolidayPay = 0;
    if (includeWeeklyHoliday) {
      weeklyHolidayPay =
          ((netHours / weeklyStandardHours) * weeklyHolidayHours * hourlyWage)
              .round();
    }

    return PayEstimate(
      hourlyWage: hourlyWage,
      totalWorkedMinutes: totalMinutes,
      breakMinutes: safeBreak,
      netWorkedMinutes: netMinutes,
      basePay: basePay,
      weeklyHolidayPay: weeklyHolidayPay,
      overtimeNightPay: overtimeNightPay,
      includeWeeklyHoliday: includeWeeklyHoliday,
      includeOvertimeNight: includeOvertimeNight,
      overtimeMinutes: overtimeMinutes,
      nightMinutes: nightMinutes,
    );
  }

  static PayEstimate fromSchedule(ScheduleModel schedule, int hourlyWage) {
    if (schedule.payEstimate != null) {
      return schedule.payEstimate!;
    }
    return estimate(
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      hourlyWage: hourlyWage,
      breakMinutes: schedule.breakMinutes,
      includeWeeklyHoliday: schedule.includeWeeklyHoliday,
      includeOvertimeNight: schedule.includeOvertimeNight,
    );
  }

  /// 22:00~06:00 야간 구간 겹침(분). 자정 넘김 근무 지원.
  static int _nightOverlapMinutes(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return 0;
    var total = 0;
    var t = start;
    while (t.isBefore(end)) {
      final hourStart = DateTime(t.year, t.month, t.day, t.hour);
      final nextHour = hourStart.add(const Duration(hours: 1));
      final segmentEnd = nextHour.isBefore(end) ? nextHour : end;
      final hour = t.hour;
      if (hour >= 22 || hour < 6) {
        total += segmentEnd.difference(t).inMinutes;
      }
      t = segmentEnd;
    }
    return total;
  }
}
