import '../core/time/kst_date_time.dart';

/// `yyyy-MM-dd` → `M.d` (예: 10.1)
String formatLaborPeriodMonthDay(String ymd) {
  if (ymd.length < 10) return ymd;
  final m = int.tryParse(ymd.substring(5, 7));
  final d = int.tryParse(ymd.substring(8, 10));
  if (m == null || d == null) return ymd.substring(5);
  return '$m.$d';
}

/// 인건비 기간 표기: `10.1 ~ 오늘 (10.5)` (집계 종료일이 오늘일 때)
String formatLaborCostPeriodLabel(
  String periodFrom,
  String periodTo, {
  String? todayKey,
}) {
  if (periodFrom.length < 10 || periodTo.length < 10) return '';
  final from = formatLaborPeriodMonthDay(periodFrom);
  final to = formatLaborPeriodMonthDay(periodTo);
  final today = todayKey ?? KstDateTime.todayKey();
  if (periodTo == today) {
    // 오늘 ↔ ( 사이 공백 1칸: "오늘 (10.5)"
    return '$from ~ 오늘 ($to)';
  }
  return '$from ~ $to';
}

/// 사장 대시보드 — 월간 인건비 집계 결과
class MonthlyLaborCost {
  const MonthlyLaborCost({
    required this.roomId,
    required this.year,
    required this.month,
    required this.periodFrom,
    required this.periodTo,
    required this.totalLaborCost,
    required this.totalWorkHours,
    required this.activeWorkerCount,
    this.includeWeeklyHoliday = false,
    this.includeEmployerSocialInsurance = false,
    this.employerSocialInsuranceRate = 0.099,
    this.basePay = 0,
    this.weeklyHolidayPay = 0,
    this.employerSocialInsuranceEstimate = 0,
    this.source = 'api',
  });

  final String roomId;
  final int year;
  final int month;
  final String periodFrom;
  final String periodTo;
  final int totalLaborCost;
  final double totalWorkHours;
  final int activeWorkerCount;
  final bool includeWeeklyHoliday;
  final bool includeEmployerSocialInsurance;
  final double employerSocialInsuranceRate;
  final int basePay;
  final int weeklyHolidayPay;
  final int employerSocialInsuranceEstimate;

  /// `api` | `mock`
  final String source;

  int get totalWithEmployerBurden =>
      totalLaborCost + employerSocialInsuranceEstimate;

  /// `10.1 ~ 오늘 (10.5)` 형식
  String get periodLabel =>
      formatLaborCostPeriodLabel(periodFrom, periodTo);

  factory MonthlyLaborCost.fromJson(Map<String, dynamic> json) {
    final period = json['period'];
    final periodMap = period is Map
        ? Map<String, dynamic>.from(period)
        : const <String, dynamic>{};
    final options = json['options'];
    final optionsMap = options is Map
        ? Map<String, dynamic>.from(options)
        : const <String, dynamic>{};
    final breakdown = json['breakdown'];
    final breakdownMap = breakdown is Map
        ? Map<String, dynamic>.from(breakdown)
        : const <String, dynamic>{};

    return MonthlyLaborCost(
      roomId: json['roomId']?.toString() ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      periodFrom: periodMap['from']?.toString() ?? '',
      periodTo: periodMap['to']?.toString() ?? '',
      totalLaborCost: (json['totalLaborCost'] as num?)?.toInt() ?? 0,
      totalWorkHours: (json['totalWorkHours'] as num?)?.toDouble() ?? 0,
      activeWorkerCount: (json['activeWorkerCount'] as num?)?.toInt() ?? 0,
      includeWeeklyHoliday:
          optionsMap['includeWeeklyHoliday'] as bool? ?? false,
      includeEmployerSocialInsurance:
          optionsMap['includeEmployerSocialInsurance'] as bool? ?? false,
      employerSocialInsuranceRate:
          (optionsMap['employerSocialInsuranceRate'] as num?)?.toDouble() ??
              0.099,
      basePay: (breakdownMap['basePay'] as num?)?.toInt() ?? 0,
      weeklyHolidayPay:
          (breakdownMap['weeklyHolidayPay'] as num?)?.toInt() ?? 0,
      employerSocialInsuranceEstimate:
          (breakdownMap['employerSocialInsuranceEstimate'] as num?)?.toInt() ??
              0,
      source: json['source']?.toString() ?? 'api',
    );
  }

  MonthlyLaborCost copyWith({String? source}) {
    return MonthlyLaborCost(
      roomId: roomId,
      year: year,
      month: month,
      periodFrom: periodFrom,
      periodTo: periodTo,
      totalLaborCost: totalLaborCost,
      totalWorkHours: totalWorkHours,
      activeWorkerCount: activeWorkerCount,
      includeWeeklyHoliday: includeWeeklyHoliday,
      includeEmployerSocialInsurance: includeEmployerSocialInsurance,
      employerSocialInsuranceRate: employerSocialInsuranceRate,
      basePay: basePay,
      weeklyHolidayPay: weeklyHolidayPay,
      employerSocialInsuranceEstimate: employerSocialInsuranceEstimate,
      source: source ?? this.source,
    );
  }
}
