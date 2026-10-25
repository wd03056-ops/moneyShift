import '../models/pay_estimate.dart';
import '../models/schedule_model.dart';

/// 시급·근무시간·휴게·수당 옵션 기준 예상 급여 계산
///
/// - 총 근무: 출퇴근 차이
/// - 실 근로: 총 근무 − 무급 휴게
/// - 기본급: 시급 × 실 근로시간
/// - 연장: 실 근로 8시간 초과분에 시급 × 0.5 가산
/// - 야간: 22:00~06:00 구간에 시급 × 0.5 가산
/// - 주휴: 주 실근로 ≥15시간일 때 `(실근로/40)×8×시급` (주 단위 집계 권장)
class PayrollCalculator {
  PayrollCalculator._();

  static const int standardDayMinutes = 8 * 60;
  static const double weeklyHolidayHours = 8;
  static const double weeklyStandardHours = 40;
  static const double weeklyHolidayThresholdHours = 15;
  static const int weeklyHolidayThresholdMinutes = 15 * 60;

  /// 총 근무 시간 기준 권장 휴게(분) — 4h↑ 30분, 8h↑ 60분
  static int suggestedBreakMinutes(int totalWorkedMinutes) {
    if (totalWorkedMinutes >= standardDayMinutes) return 60;
    if (totalWorkedMinutes >= 4 * 60) return 30;
    return 0;
  }

  /// 주 실근로 분 기준 주휴수당. 15시간 미만이면 0.
  static int weeklyHolidayPayForNetMinutes({
    required int netWorkedMinutes,
    required int hourlyWage,
  }) {
    if (hourlyWage <= 0 ||
        netWorkedMinutes < weeklyHolidayThresholdMinutes) {
      return 0;
    }
    final netHours = netWorkedMinutes / 60.0;
    return ((netHours / weeklyStandardHours) *
            weeklyHolidayHours *
            hourlyWage)
        .round();
  }

  /// 하위 호환: 총액만 필요할 때
  static int estimatePay({
    required DateTime startTime,
    required DateTime endTime,
    required int hourlyWage,
    int breakMinutes = 0,
    bool includeWeeklyHoliday = false,
    bool includeOvertimeNight = false,
    bool? includeOvertime,
    bool? includeNight,
  }) {
    return estimate(
      startTime: startTime,
      endTime: endTime,
      hourlyWage: hourlyWage,
      breakMinutes: breakMinutes,
      includeWeeklyHoliday: includeWeeklyHoliday,
      includeOvertimeNight: includeOvertimeNight,
      includeOvertime: includeOvertime,
      includeNight: includeNight,
    ).total;
  }

  /// 1건(또는 1구간) 급여 산정.
  ///
  /// 주휴는 구간 비례 `(실근로/40)×8×시급`로 미리보기합니다.
  /// 월간·주간 **확정 주휴**는 [weeklyHolidayPayForNetMinutes]로
  /// 주 합산 ≥15시간일 때만 적용하세요.
  static PayEstimate estimate({
    required DateTime startTime,
    required DateTime endTime,
    required int hourlyWage,
    int breakMinutes = 0,
    bool includeWeeklyHoliday = false,
    bool includeOvertimeNight = false,
    bool? includeOvertime,
    bool? includeNight,
  }) {
    final wantOt = includeOvertime ?? includeOvertimeNight;
    final wantNight = includeNight ?? includeOvertimeNight;

    final totalMinutes = endTime.difference(startTime).inMinutes;
    if (hourlyWage <= 0 || totalMinutes <= 0) {
      return PayEstimate(
        hourlyWage: hourlyWage,
        totalWorkedMinutes: totalMinutes.clamp(0, 24 * 60),
        breakMinutes: 0,
        netWorkedMinutes: 0,
        basePay: 0,
        includeWeeklyHoliday: includeWeeklyHoliday,
        includeOvertimeNight: wantOt || wantNight,
      );
    }

    final safeBreak = breakMinutes.clamp(0, totalMinutes);
    final netMinutes = totalMinutes - safeBreak;
    final netHours = netMinutes / 60.0;
    final basePay = (netHours * hourlyWage).round();

    var overtimeMinutes = 0;
    var nightMinutes = 0;
    var overtimeNightPay = 0;
    if (wantOt) {
      overtimeMinutes = netMinutes > standardDayMinutes
          ? netMinutes - standardDayMinutes
          : 0;
    }
    if (wantNight) {
      nightMinutes = _nightOverlapMinutes(startTime, endTime);
    }
    if (overtimeMinutes > 0 || nightMinutes > 0) {
      final premiumHours = (overtimeMinutes + nightMinutes) / 60.0;
      overtimeNightPay = (premiumHours * hourlyWage * 0.5).round();
    }

    // 주휴는 주 실근로 ≥15시간일 때만 (단일 구간 미리보기도 동일 게이트)
    final weeklyHolidayPay = includeWeeklyHoliday
        ? weeklyHolidayPayForNetMinutes(
            netWorkedMinutes: netMinutes,
            hourlyWage: hourlyWage,
          )
        : 0;

    return PayEstimate(
      hourlyWage: hourlyWage,
      totalWorkedMinutes: totalMinutes,
      breakMinutes: safeBreak,
      netWorkedMinutes: netMinutes,
      basePay: basePay,
      weeklyHolidayPay: weeklyHolidayPay,
      overtimeNightPay: overtimeNightPay,
      includeWeeklyHoliday: includeWeeklyHoliday,
      includeOvertimeNight: wantOt || wantNight,
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

  /// 같은 주의 실근로 분들을 합산해 주휴수당 산출 (월~일 또는 ISO 주 키 단위).
  static int weeklyHolidayPayForWeekNetMinutes({
    required Iterable<int> netMinutesParts,
    required int hourlyWage,
  }) {
    final sum = netMinutesParts.fold<int>(0, (a, b) => a + b);
    return weeklyHolidayPayForNetMinutes(
      netWorkedMinutes: sum,
      hourlyWage: hourlyWage,
    );
  }

  /// 주 키: 해당 일자가 속한 주의 월요일 `yyyy-MM-dd` (KST 날짜 기준).
  static String weekMondayKey(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final monday = d.subtract(Duration(days: d.weekday - DateTime.monday));
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final dd = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  /// 22:00~06:00 야간 구간 겹침(분). 자정 넘김 근무 지원.
  static int nightOverlapMinutes(DateTime start, DateTime end) {
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

  static int _nightOverlapMinutes(DateTime start, DateTime end) =>
      nightOverlapMinutes(start, end);
}