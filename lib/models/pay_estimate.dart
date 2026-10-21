import 'package:equatable/equatable.dart';

/// 근무 1건 기준 예상 급여 산정 결과
class PayEstimate extends Equatable {
  const PayEstimate({
    required this.hourlyWage,
    required this.totalWorkedMinutes,
    required this.breakMinutes,
    required this.netWorkedMinutes,
    required this.basePay,
    this.weeklyHolidayPay = 0,
    this.overtimeNightPay = 0,
    this.includeWeeklyHoliday = false,
    this.includeOvertimeNight = false,
    this.overtimeMinutes = 0,
    this.nightMinutes = 0,
  });

  final int hourlyWage;

  /// 출퇴근 차이 (총 근무 시간)
  final int totalWorkedMinutes;

  /// 무급 휴게 차감(분)
  final int breakMinutes;

  /// 인정 실 근로시간 = 총 근무 − 휴게
  final int netWorkedMinutes;

  final int basePay;

  /// 주휴수당 (옵션)
  final int weeklyHolidayPay;

  /// 연장·야간 가산 수당 (옵션)
  final int overtimeNightPay;

  final bool includeWeeklyHoliday;
  final bool includeOvertimeNight;

  final int overtimeMinutes;
  final int nightMinutes;

  /// 하위 호환 별칭
  int get workedMinutes => netWorkedMinutes;

  int get total => basePay + weeklyHolidayPay + overtimeNightPay;

  double get workedHours => netWorkedMinutes / 60.0;

  bool get hasAllowances =>
      weeklyHolidayPay > 0 || overtimeNightPay > 0;

  /// `9시간` / `8시간 30분` / `30분` — 0분은 생략
  static String formatDuration(int minutes) {
    final safe = minutes < 0 ? 0 : minutes;
    final h = safe ~/ 60;
    final m = safe % 60;
    if (h > 0 && m == 0) return '$h시간';
    if (h > 0) return '$h시간 $m분';
    return '$m분';
  }

  String get totalWorkedLabel => formatDuration(totalWorkedMinutes);
  String get breakLabel => formatDuration(breakMinutes);
  String get netWorkedLabel => formatDuration(netWorkedMinutes);

  Map<String, dynamic> toMap() => {
        'hourlyWage': hourlyWage,
        'totalWorkedMinutes': totalWorkedMinutes,
        'breakMinutes': breakMinutes,
        'netWorkedMinutes': netWorkedMinutes,
        'workedMinutes': netWorkedMinutes,
        'basePay': basePay,
        'weeklyHolidayPay': weeklyHolidayPay,
        'overtimeNightPay': overtimeNightPay,
        'includeWeeklyHoliday': includeWeeklyHoliday,
        'includeOvertimeNight': includeOvertimeNight,
        'overtimeMinutes': overtimeMinutes,
        'nightMinutes': nightMinutes,
        'total': total,
      };

  factory PayEstimate.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const PayEstimate(
        hourlyWage: 0,
        totalWorkedMinutes: 0,
        breakMinutes: 0,
        netWorkedMinutes: 0,
        basePay: 0,
      );
    }
    final total = map['totalWorkedMinutes'] as int? ??
        map['workedMinutes'] as int? ??
        0;
    final brk = map['breakMinutes'] as int? ?? 0;
    final net = map['netWorkedMinutes'] as int? ?? (total - brk).clamp(0, total);
    return PayEstimate(
      hourlyWage: map['hourlyWage'] as int? ?? 0,
      totalWorkedMinutes: total,
      breakMinutes: brk,
      netWorkedMinutes: net,
      basePay: map['basePay'] as int? ?? 0,
      weeklyHolidayPay: map['weeklyHolidayPay'] as int? ?? 0,
      overtimeNightPay: map['overtimeNightPay'] as int? ?? 0,
      includeWeeklyHoliday: map['includeWeeklyHoliday'] as bool? ?? false,
      includeOvertimeNight: map['includeOvertimeNight'] as bool? ?? false,
      overtimeMinutes: map['overtimeMinutes'] as int? ?? 0,
      nightMinutes: map['nightMinutes'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        hourlyWage,
        totalWorkedMinutes,
        breakMinutes,
        netWorkedMinutes,
        basePay,
        weeklyHolidayPay,
        overtimeNightPay,
        includeWeeklyHoliday,
        includeOvertimeNight,
        overtimeMinutes,
        nightMinutes,
      ];
}
