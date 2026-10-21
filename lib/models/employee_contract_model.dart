import 'package:equatable/equatable.dart';

import '../core/constants/app_constants.dart';
import '../services/payroll_calculator.dart';
import 'enums/break_time_type.dart';

/// 직원별 기본 급여·근무 조건 (프로필 — 개별 근무 배정과 독립)
class EmployeeContractModel extends Equatable {
  const EmployeeContractModel({
    this.hourlyWage = AppConstants.minimumHourlyWage,
    this.breakTimeType = BreakTimeType.auto,
    this.fixedBreakMinutes = 60,
    this.isWeekPayEnabled = false,
    this.isNightPayEnabled = false,
    this.isOvertimePayEnabled = false,
  });

  final int hourlyWage;
  final BreakTimeType breakTimeType;
  final int fixedBreakMinutes;
  final bool isWeekPayEnabled;
  final bool isNightPayEnabled;
  final bool isOvertimePayEnabled;

  /// 야간·연장 가산 (급여 엔진 호환 — 둘 중 하나라도 on)
  bool get includeOvertimeNight =>
      isNightPayEnabled || isOvertimePayEnabled;

  /// 근무 총 시간(분) 기준 이번 배정에 쓸 휴게(분)
  int resolveBreakMinutes(int totalWorkedMinutes) {
    switch (breakTimeType) {
      case BreakTimeType.none:
        return 0;
      case BreakTimeType.fixed:
        return fixedBreakMinutes.clamp(0, totalWorkedMinutes.clamp(0, 24 * 60));
      case BreakTimeType.auto:
        return PayrollCalculator.suggestedBreakMinutes(totalWorkedMinutes);
    }
  }

  factory EmployeeContractModel.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const EmployeeContractModel();
    }
    return EmployeeContractModel(
      hourlyWage: (map['hourlyWage'] as num?)?.toInt() ??
          AppConstants.minimumHourlyWage,
      breakTimeType: BreakTimeType.fromFirestore(map['breakTimeType'] as String?),
      fixedBreakMinutes: (map['fixedBreakMinutes'] as num?)?.toInt() ?? 60,
      isWeekPayEnabled: map['isWeekPayEnabled'] as bool? ?? false,
      isNightPayEnabled: map['isNightPayEnabled'] as bool? ?? false,
      isOvertimePayEnabled: map['isOvertimePayEnabled'] as bool? ?? false,
    );
  }

  /// 레거시: hourlyWage만 있던 멤버 문서
  factory EmployeeContractModel.fromLegacyHourlyWage(int? wage) {
    return EmployeeContractModel(
      hourlyWage: wage ?? AppConstants.minimumHourlyWage,
    );
  }

  Map<String, dynamic> toMap() => {
        'hourlyWage': hourlyWage,
        'breakTimeType': breakTimeType.firestoreValue,
        'fixedBreakMinutes': fixedBreakMinutes,
        'isWeekPayEnabled': isWeekPayEnabled,
        'isNightPayEnabled': isNightPayEnabled,
        'isOvertimePayEnabled': isOvertimePayEnabled,
      };

  EmployeeContractModel copyWith({
    int? hourlyWage,
    BreakTimeType? breakTimeType,
    int? fixedBreakMinutes,
    bool? isWeekPayEnabled,
    bool? isNightPayEnabled,
    bool? isOvertimePayEnabled,
  }) {
    return EmployeeContractModel(
      hourlyWage: hourlyWage ?? this.hourlyWage,
      breakTimeType: breakTimeType ?? this.breakTimeType,
      fixedBreakMinutes: fixedBreakMinutes ?? this.fixedBreakMinutes,
      isWeekPayEnabled: isWeekPayEnabled ?? this.isWeekPayEnabled,
      isNightPayEnabled: isNightPayEnabled ?? this.isNightPayEnabled,
      isOvertimePayEnabled:
          isOvertimePayEnabled ?? this.isOvertimePayEnabled,
    );
  }

  @override
  List<Object?> get props => [
        hourlyWage,
        breakTimeType,
        fixedBreakMinutes,
        isWeekPayEnabled,
        isNightPayEnabled,
        isOvertimePayEnabled,
      ];
}
