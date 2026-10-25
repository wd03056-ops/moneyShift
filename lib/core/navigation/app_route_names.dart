/// Navigator [RouteSettings.name] 상수 — 딥링크·싱글탑용
abstract final class AppRouteNames {
  AppRouteNames._();

  static const home = '/';
  static const login = '/login';
  static const inbox = '/notifications';
  static const createRoom = '/create-room';
  static const joinRoom = '/join-room';
  static const editProfile = '/edit-profile';
  static const notificationTest = '/notification-test';

  static String room(String roomId) => '/room/$roomId';

  static String assignedSchedule(String roomId) =>
      '/room/$roomId/assigned-schedule';

  static String noticeBoard(String roomId) => '/room/$roomId/notices';

  static String noticeCompose(String roomId) => '/room/$roomId/notices/compose';

  static String noticeDetail(String noticeId) => '/notices/$noticeId';

  static String scheduleLogs(String roomId) => '/room/$roomId/schedule-logs';

  static String ownerCommute(String roomId) => '/room/$roomId/commute';

  static String laborCostDetail(String roomId) =>
      '/room/$roomId/labor-cost';

  static String invite(String roomId) => '/room/$roomId/invite';

  static String employeeContract(String roomId, String workerId) =>
      '/room/$roomId/employee/$workerId';

  static String createSchedule(String roomId) => '/room/$roomId/assign';

  static String ownerStaffSchedule(String roomId, String workerId) =>
      '/room/$roomId/staff-schedule/$workerId';

  static String assignedDetail(String scheduleOrBatchId) =>
      '/assigned-detail/$scheduleOrBatchId';

  static String legal(String slug) => '/legal/$slug';

  static bool isRoomDetail(String? name) {
    if (name == null) return false;
    final parts = name.split('/');
    // /room/{id} 만 (하위 경로 제외)
    return parts.length == 3 && parts[1] == 'room' && parts[2].isNotEmpty;
  }

  static String? roomIdFromName(String? name) {
    if (!isRoomDetail(name)) return null;
    return name!.split('/')[2];
  }
}
