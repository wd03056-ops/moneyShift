/// `shift_requests` 상태
enum ShiftRequestStatus {
  pending,
  approved,
  rejected;

  String get firestoreValue => name;

  String get labelKo {
    switch (this) {
      case ShiftRequestStatus.pending:
        return '대기';
      case ShiftRequestStatus.approved:
        return '승인';
      case ShiftRequestStatus.rejected:
        return '거절';
    }
  }

  static ShiftRequestStatus fromFirestore(String? value) {
    return ShiftRequestStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ShiftRequestStatus.pending,
    );
  }
}
