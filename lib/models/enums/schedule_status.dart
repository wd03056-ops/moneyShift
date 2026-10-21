/// 근무 일정 상호 승인 상태
enum ScheduleStatus {
  /// 확정·정상 (변경 요청 없음)
  normal,

  /// 사장이 변경 요청 → 알바생 승인 대기
  changeRequestedByOwner,

  /// 알바생이 변경 요청 → 사장/매니저 승인 대기
  changeRequestedByStaff;

  String get firestoreValue {
    switch (this) {
      case ScheduleStatus.normal:
        return 'normal';
      case ScheduleStatus.changeRequestedByOwner:
        return 'change_requested_by_owner';
      case ScheduleStatus.changeRequestedByStaff:
        return 'change_requested_by_staff';
    }
  }

  String get labelKo {
    switch (this) {
      case ScheduleStatus.normal:
        return '확정';
      case ScheduleStatus.changeRequestedByOwner:
        return '사장 변경 요청';
      case ScheduleStatus.changeRequestedByStaff:
        return '알바 변경 요청';
    }
  }

  bool get hasPendingChange => this != ScheduleStatus.normal;

  static ScheduleStatus fromFirestore(String? value) {
    switch (value) {
      case 'change_requested_by_owner':
        return ScheduleStatus.changeRequestedByOwner;
      case 'change_requested_by_staff':
        return ScheduleStatus.changeRequestedByStaff;
      case 'normal':
      default:
        return ScheduleStatus.normal;
    }
  }
}
