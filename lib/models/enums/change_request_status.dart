/// 근무 일정 변경 요청 처리 상태
enum ChangeRequestStatus {
  pending,
  accepted,
  rejected;

  String get labelKo {
    switch (this) {
      case ChangeRequestStatus.pending:
        return '변경 요청 중';
      case ChangeRequestStatus.accepted:
        return '수락됨';
      case ChangeRequestStatus.rejected:
        return '거절됨';
    }
  }

  String get firestoreValue {
    switch (this) {
      case ChangeRequestStatus.pending:
        return 'PENDING';
      case ChangeRequestStatus.accepted:
        return 'ACCEPTED';
      case ChangeRequestStatus.rejected:
        return 'REJECTED';
    }
  }

  static ChangeRequestStatus fromFirestore(String? value) {
    switch (value?.toUpperCase()) {
      case 'ACCEPTED':
        return ChangeRequestStatus.accepted;
      case 'REJECTED':
        return ChangeRequestStatus.rejected;
      case 'PENDING':
      default:
        return ChangeRequestStatus.pending;
    }
  }
}
