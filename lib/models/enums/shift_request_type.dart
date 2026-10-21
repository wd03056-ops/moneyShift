/// 근무 변경 / 교대 / 휴가 요청 유형
enum ShiftRequestType {
  change,
  swap,
  leave;

  String get firestoreValue => name;

  String get labelKo {
    switch (this) {
      case ShiftRequestType.change:
        return '근무 변경';
      case ShiftRequestType.swap:
        return '교대';
      case ShiftRequestType.leave:
        return '휴가';
    }
  }

  static ShiftRequestType fromFirestore(String? value) {
    return ShiftRequestType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ShiftRequestType.change,
    );
  }
}
