/// `schedule_logs` 액션 유형
enum ScheduleLogAction {
  changeRequested,
  changeApproved,
  changeRejected;

  String get firestoreValue {
    switch (this) {
      case ScheduleLogAction.changeRequested:
        return 'change_requested';
      case ScheduleLogAction.changeApproved:
        return 'change_approved';
      case ScheduleLogAction.changeRejected:
        return 'change_rejected';
    }
  }

  String get labelKo {
    switch (this) {
      case ScheduleLogAction.changeRequested:
        return '변경 요청';
      case ScheduleLogAction.changeApproved:
        return '변경 확인';
      case ScheduleLogAction.changeRejected:
        return '변경 거절';
    }
  }

  static ScheduleLogAction fromFirestore(String? value) {
    switch (value) {
      case 'change_approved':
        return ScheduleLogAction.changeApproved;
      case 'change_rejected':
        return ScheduleLogAction.changeRejected;
      case 'change_requested':
      default:
        return ScheduleLogAction.changeRequested;
    }
  }
}
