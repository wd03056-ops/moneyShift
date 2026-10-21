/// 짧은 시간 내 동일 이벤트 알림 중복 차단
abstract final class NotificationDedupe {
  NotificationDedupe._();

  static final Map<String, DateTime> _recent = {};
  static const Duration defaultWindow = Duration(seconds: 45);

  /// 공지·동일 문구 연속 발송 억제 (요금·스팸 방어)
  static const Duration contentWindow = Duration(minutes: 2);

  /// 동일 공지 ID 재발송 억제
  static const Duration noticeWindow = Duration(minutes: 5);

  /// true 이면 이번 발송을 건너뛴다
  static bool shouldSkip(
    String key, {
    Duration window = defaultWindow,
  }) {
    if (key.isEmpty) return false;
    final now = DateTime.now();
    final prev = _recent[key];
    if (prev != null && now.difference(prev) < window) {
      return true;
    }
    _recent[key] = now;
    _prune(now);
    return false;
  }

  static void clear([String? key]) {
    if (key == null) {
      _recent.clear();
    } else {
      _recent.remove(key);
    }
  }

  static void _prune(DateTime now) {
    if (_recent.length < 64) return;
    _recent.removeWhere(
      (_, t) => now.difference(t) > const Duration(minutes: 10),
    );
  }

  static String staffJoinedKey(String storeId, String staffUidOrName) =>
      'register:$storeId:$staffUidOrName';

  static String scheduleAssignKey({
    required String storeId,
    required String workerUid,
    required String scheduleOrBatchId,
  }) =>
      'assign:$storeId:$workerUid:$scheduleOrBatchId';

  /// 동일 직원·매장에 짧은 시간 연속 배정 알림 억제 (일괄 배정 누락 대비)
  static String scheduleAssignBurstKey({
    required String storeId,
    required String workerUid,
  }) =>
      'assign_burst:$storeId:$workerUid';

  static String scheduleConfirmKey(String scheduleOrBatchId) =>
      'schedule_confirm:$scheduleOrBatchId';

  static String scheduleChangeRequestKey(String scheduleId, {String dir = 'to_owner'}) =>
      'change_req:$dir:$scheduleId';

  static String scheduleChangeResultKey(
    String scheduleId,
    bool approved, {
    String dir = 'to_worker',
  }) =>
      'change_res:$dir:$scheduleId:${approved ? 'ok' : 'no'}';

  static String scheduleAbsentKey(String scheduleId) => 'absent:$scheduleId';

  static String storeNoticeKey(String noticeId) => 'notice:$noticeId';

  /// true면 동일 내용 알림을 최근 [contentWindow] 내 이미 보냄
  static bool shouldSkipContent({
    required String userId,
    required String type,
    required String title,
    required String body,
    required String storeId,
    Duration window = contentWindow,
  }) {
    return shouldSkip(
      contentFingerprint(
        userId: userId,
        type: type,
        title: title,
        body: body,
        storeId: storeId,
      ),
      window: window,
    );
  }

  static String attendanceKey({
    required String storeId,
    required String workerUid,
    required bool isClockIn,
    required String dayKey,
  }) =>
      'commute:$storeId:$workerUid:${isClockIn ? 'in' : 'out'}:$dayKey';

  static String correctionRequestKey(String requestId) =>
      'commute_corr_req:$requestId';

  static String correctionResultKey(String requestId, bool approved) =>
      'commute_corr_res:$requestId:${approved ? 'ok' : 'no'}';

  static String swapKey(String swapId, String stage) => 'swap:$swapId:$stage';

  /// 알림함 내용 지문 (동일 문구 연속 적재 방지)
  static String contentFingerprint({
    required String userId,
    required String type,
    required String title,
    required String body,
    required String storeId,
  }) =>
      'inbox:$userId:$type:$storeId:$title:$body';
}
