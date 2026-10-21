/// 출퇴근 로그 유형
enum AttendanceType {
  clockIn,
  clockOut;

  String get firestoreValue {
    switch (this) {
      case AttendanceType.clockIn:
        return 'clock_in';
      case AttendanceType.clockOut:
        return 'clock_out';
    }
  }

  static AttendanceType fromFirestore(String value) {
    switch (value) {
      case 'clock_in':
        return AttendanceType.clockIn;
      case 'clock_out':
        return AttendanceType.clockOut;
      default:
        return AttendanceType.clockIn;
    }
  }
}
