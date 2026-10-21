/// Firestore 컬렉션 경로 헬퍼
class FirestorePaths {
  FirestorePaths._();

  static const String users = 'users';
  static const String rooms = 'rooms';
  static const String stores = 'stores';
  static const String storeMembers = 'store_members';
  static const String roomMembers = 'room_members';
  static const String roomInvites = 'room_invites';
  static const String schedules = 'schedules';
  static const String scheduleLogs = 'schedule_logs';
  static const String shiftRequests = 'shift_requests';
  static const String attendanceLogs = 'attendance_logs';
  static const String attendances = 'attendances';
  static const String payrolls = 'payrolls';
  static const String notifications = 'notifications';
  static const String notificationJobs = 'notification_jobs';
  static const String notices = 'notices';
  static const String shiftSwaps = 'shift_swaps';
  static const String connectionTest = 'connection_test';

  static String user(String userId) => '$users/$userId';

  /// `users/{uid}/notifications` — 인앱 알림함
  static String userNotifications(String userId) =>
      '$users/$userId/$notifications';

  static String userNotification(String userId, String id) =>
      '${userNotifications(userId)}/$id';

  static String room(String roomId) => '$rooms/$roomId';
  static String store(String storeId) => '$stores/$storeId';
  static String notice(String id) => '$notices/$id';
  static String shiftSwap(String id) => '$shiftSwaps/$id';

  /// store_members 문서 ID: `{storeId}_{userId}`
  static String storeMemberDocId(String storeId, String userId) =>
      '${storeId}_$userId';

  static String storeMember(String storeId, String userId) =>
      '$storeMembers/${storeMemberDocId(storeId, userId)}';

  /// room_members 문서 ID: `{roomId}_{userId}` (레거시)
  static String roomMemberDocId(String roomId, String userId) =>
      '${roomId}_$userId';

  static String roomMember(String roomId, String userId) =>
      '$roomMembers/${roomMemberDocId(roomId, userId)}';

  static String roomInvite(String inviteId) => '$roomInvites/$inviteId';
  static String schedule(String scheduleId) => '$schedules/$scheduleId';
  static String scheduleLog(String logId) => '$scheduleLogs/$logId';
  static String shiftRequest(String requestId) => '$shiftRequests/$requestId';
  static String attendanceLog(String logId) => '$attendanceLogs/$logId';
  static String attendance(String attendanceId) =>
      '$attendances/$attendanceId';
  static String payroll(String payrollId) => '$payrolls/$payrollId';
  /// 레거시 루트 컬렉션 (마이그레이션 호환)
  static String notification(String id) => '$notifications/$id';
  static String notificationJob(String id) => '$notificationJobs/$id';
  static String connectionTestDoc(String docId) => '$connectionTest/$docId';
}
