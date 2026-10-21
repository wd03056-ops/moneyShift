/// 휴게시간 산정 방식
enum BreakTimeType {
  /// 근무시간에 따라 법정 권장 휴게 자동 적용
  auto,

  /// 고정 분 단위
  fixed,

  /// 휴게 없음 (0분)
  none;

  String get firestoreValue {
    switch (this) {
      case BreakTimeType.auto:
        return 'auto';
      case BreakTimeType.fixed:
        return 'fixed';
      case BreakTimeType.none:
        return 'none';
    }
  }

  String get labelKo {
    switch (this) {
      case BreakTimeType.auto:
        return '자동';
      case BreakTimeType.fixed:
        return '고정';
      case BreakTimeType.none:
        return '없음';
    }
  }

  static BreakTimeType fromFirestore(String? value) {
    switch (value) {
      case 'fixed':
        return BreakTimeType.fixed;
      case 'none':
        return BreakTimeType.none;
      default:
        return BreakTimeType.auto;
    }
  }
}
