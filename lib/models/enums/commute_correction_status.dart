/// 근태 수정 요청 상태
enum CommuteCorrectionStatus {
  pending,
  approved,
  rejected;

  String get firestoreValue {
    switch (this) {
      case CommuteCorrectionStatus.pending:
        return 'pending';
      case CommuteCorrectionStatus.approved:
        return 'approved';
      case CommuteCorrectionStatus.rejected:
        return 'rejected';
    }
  }

  String get labelKo {
    switch (this) {
      case CommuteCorrectionStatus.pending:
        return '승인 대기';
      case CommuteCorrectionStatus.approved:
        return '승인됨';
      case CommuteCorrectionStatus.rejected:
        return '거절됨';
    }
  }

  bool get isOpen => this == CommuteCorrectionStatus.pending;

  static CommuteCorrectionStatus fromFirestore(String? value) {
    switch (value) {
      case 'approved':
        return CommuteCorrectionStatus.approved;
      case 'rejected':
        return CommuteCorrectionStatus.rejected;
      default:
        return CommuteCorrectionStatus.pending;
    }
  }
}

/// 사장이 요청하는 근태 상태 의도
enum CommuteCorrectionIntent {
  /// 정상 출근·퇴근 시각 보정
  normal,

  /// 지각으로 표기 (출근 시각 보정 가능)
  late,

  /// 결근 처리
  absent,

  /// 수동 퇴근 시각만 보정
  manualClockOut;

  String get firestoreValue {
    switch (this) {
      case CommuteCorrectionIntent.normal:
        return 'normal';
      case CommuteCorrectionIntent.late:
        return 'late';
      case CommuteCorrectionIntent.absent:
        return 'absent';
      case CommuteCorrectionIntent.manualClockOut:
        return 'manual_clock_out';
    }
  }

  String get labelKo {
    switch (this) {
      case CommuteCorrectionIntent.normal:
        return '정상출근';
      case CommuteCorrectionIntent.late:
        return '지각';
      case CommuteCorrectionIntent.absent:
        return '결근';
      case CommuteCorrectionIntent.manualClockOut:
        return '수동퇴근';
    }
  }

  static CommuteCorrectionIntent fromFirestore(String? value) {
    switch (value) {
      case 'late':
        return CommuteCorrectionIntent.late;
      case 'absent':
        return CommuteCorrectionIntent.absent;
      case 'manual_clock_out':
        return CommuteCorrectionIntent.manualClockOut;
      default:
        return CommuteCorrectionIntent.normal;
    }
  }
}
