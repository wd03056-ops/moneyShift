/// 대타 요청 상태
enum ShiftSwapStatus {
  /// 동료 수락 대기
  pendingColleague,

  /// 사장 승인 대기 (동료 수락 후 또는 사장 직행)
  pendingOwner,

  approved,
  rejected,
  cancelled;

  String get labelKo {
    switch (this) {
      case ShiftSwapStatus.pendingColleague:
        return '동료 수락 대기';
      case ShiftSwapStatus.pendingOwner:
        return '승인 대기';
      case ShiftSwapStatus.approved:
        return '승인 완료';
      case ShiftSwapStatus.rejected:
        return '거절됨';
      case ShiftSwapStatus.cancelled:
        return '취소됨';
    }
  }

  bool get isOpen =>
      this == ShiftSwapStatus.pendingColleague ||
      this == ShiftSwapStatus.pendingOwner;
}
