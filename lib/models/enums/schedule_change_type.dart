/// 사장 → 직원 근무 일정 변경 요청 구분
enum ScheduleChangeType {
  /// 시작·종료 시간 변경
  timeChange,

  /// 근무 날짜 변경 (시간 포함 가능)
  dateChange,

  /// 근무 취소(휴무) 요청
  cancel,

  /// 대체 직원 지명 요청
  substitute;

  String get labelKo {
    switch (this) {
      case ScheduleChangeType.timeChange:
        return '시간 변경';
      case ScheduleChangeType.dateChange:
        return '날짜 변경';
      case ScheduleChangeType.cancel:
        return '근무 취소(휴무)';
      case ScheduleChangeType.substitute:
        return '대체 직원 지명';
    }
  }

  String get firestoreValue {
    switch (this) {
      case ScheduleChangeType.timeChange:
        return 'time_change';
      case ScheduleChangeType.dateChange:
        return 'date_change';
      case ScheduleChangeType.cancel:
        return 'cancel';
      case ScheduleChangeType.substitute:
        return 'substitute';
    }
  }

  static ScheduleChangeType fromFirestore(String? value) {
    switch (value) {
      case 'date_change':
        return ScheduleChangeType.dateChange;
      case 'cancel':
        return ScheduleChangeType.cancel;
      case 'substitute':
        return ScheduleChangeType.substitute;
      case 'time_change':
      default:
        return ScheduleChangeType.timeChange;
    }
  }
}
