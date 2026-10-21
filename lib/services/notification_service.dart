import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../core/security/secure_log.dart';
import '../features/notifications/data/notification_preference_store.dart';
import '../features/notifications/domain/notification_dedupe.dart';
import '../features/notifications/domain/notification_sanitizer.dart';
import '../features/notifications/domain/notification_templates.dart';
import '../models/notification_model.dart';

/// 공통 알림 서비스
///
/// 1) `users/{userId}/notifications/{id}` 인박스 저장
/// 2) `notification_jobs` 큐 → Cloud Functions FCM 전송
class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static final NotificationService instance = NotificationService();

  /// 수신 수신 — [NotificationModel] 스키마로 저장 + FCM 잡
  Future<void> notifyUser({
    required String recipientUid,
    required NotificationEventKind kind,
    required String title,
    required String body,
    String storeId = '',
    Map<String, String> data = const {},
  }) async {
    if (recipientUid.isEmpty) return;
    try {
      final type = kind.notificationType;
      final prefs = NotificationPreferenceStore.instance;
      await prefs.ensureLoaded();
      if (!prefs.shouldDeliver(
        userId: recipientUid,
        type: type.firestoreValue,
      )) {
        SecureLog.d(
          '[Notification] skip opted-out uid=$recipientUid '
          'type=${type.firestoreValue}',
        );
        return;
      }

      final resolvedStoreId = storeId.isNotEmpty
          ? storeId
          : (data['storeId'] ?? '');
      final safeTitle = NotificationSanitizer.sanitizeTitle(title);
      final safeBody = NotificationSanitizer.sanitizeBody(body);
      final safeStoreId =
          NotificationSanitizer.sanitize(resolvedStoreId, maxLength: 64);

      // 멱등성: 동일 수신·타입·문구 짧은 시간 재큐잉 차단 (FCM 요금 방어)
      final jobIdempotencyKey = NotificationDedupe.contentFingerprint(
        userId: recipientUid,
        type: type.firestoreValue,
        title: safeTitle,
        body: safeBody,
        storeId: safeStoreId,
      );
      if (NotificationDedupe.shouldSkip(
        'fcm:$jobIdempotencyKey',
        window: NotificationDedupe.contentWindow,
      )) {
        SecureLog.d(
          '[Notification] skip idempotent dup uid=$recipientUid '
          'type=${type.firestoreValue}',
        );
        return;
      }

      final userSnap =
          await _db.collection(FirestorePaths.users).doc(recipientUid).get();
      final userData = userSnap.data() ?? {};
      final token = userSnap.exists ? _resolveToken(userData) : null;

      final inboxRef = _db
          .collection(FirestorePaths.userNotifications(recipientUid))
          .doc();

      final model = NotificationModel.withDeepLink(
        id: inboxRef.id,
        userId: recipientUid,
        storeId: safeStoreId,
        type: type,
        title: safeTitle,
        body: safeBody,
        isRead: false,
        createdAt: DateTime.now(),
        data: data,
      );

      await inboxRef.set({
        ...model.toFirestore(forCreate: true),
        'fcmToken': ?token,
        'status': token == null ? 'no_token' : 'queued',
      });
      SecureLog.d(
        '[Notification] inbox type=${type.firestoreValue} '
        'to=$recipientUid hasToken=${token != null}',
      );

      final jobRef = _db.collection(FirestorePaths.notificationJobs).doc();
      await jobRef.set({
        'recipientUid': recipientUid,
        'userId': recipientUid,
        'storeId': safeStoreId,
        'type': type.firestoreValue,
        'title': safeTitle,
        'body': safeBody,
        'data': model.data,
        'fcmToken': ?token,
        'status': token == null ? 'no_token' : 'queued',
        'inboxId': inboxRef.id,
        'inboxPath': inboxRef.path,
        'idempotencyKey': jobIdempotencyKey,
        'createdAt': FieldValue.serverTimestamp(),
      });
      SecureLog.d(
        '[Notification] job queued id=${jobRef.id} hasToken=${token != null}',
      );
    } on FirebaseException catch (e, st) {
      SecureLog.d(
        '[Notification] FAIL code=${e.code} message=${e.message}',
      );
      SecureLog.d('$st');
    } catch (e, st) {
      SecureLog.d('[Notification] FAIL: $e');
      SecureLog.d('$st');
    }
  }

  Future<void> notifyMany({
    required Iterable<String> recipientUids,
    required NotificationEventKind kind,
    required String title,
    required String body,
    String storeId = '',
    Map<String, String> data = const {},
  }) async {
    final unique = recipientUids.where((e) => e.isNotEmpty).toSet();
    await Future.wait(
      unique.map(
        (uid) => notifyUser(
          recipientUid: uid,
          kind: kind,
          title: title,
          body: body,
          storeId: storeId,
          data: data,
        ),
      ),
    );
  }

  Future<void> notifyStaffJoined({
    required String ownerUid,
    required String staffDisplayName,
    required String storeId,
    String? memberId,
  }) {
    return notifyUser(
      recipientUid: ownerUid,
      kind: NotificationEventKind.staffJoined,
      title: NotificationTemplates.staffJoinedTitle,
      body: NotificationTemplates.staffJoinedBody(staffDisplayName),
      storeId: storeId,
      data: {
        if (memberId != null) 'memberId': memberId,
      },
    );
  }

  Future<void> notifyScheduleAssigned({
    required String workerUid,
    required String storeId,
    required String scheduleId,
    required String storeName,
  }) {
    return notifyUser(
      recipientUid: workerUid,
      kind: NotificationEventKind.scheduleAssigned,
      title: NotificationTemplates.scheduleAssignedTitle,
      body: NotificationTemplates.scheduleAssignedBody(storeName),
      storeId: storeId,
      data: {'scheduleId': scheduleId},
    );
  }

  Future<void> notifyScheduleConfirmed({
    required String ownerUid,
    required String staffDisplayName,
    required String storeId,
    required String scheduleId,
  }) {
    return notifyUser(
      recipientUid: ownerUid,
      kind: NotificationEventKind.scheduleConfirmed,
      title: NotificationTemplates.scheduleConfirmedTitle,
      body: NotificationTemplates.scheduleConfirmedBody(staffDisplayName),
      storeId: storeId,
      data: {'scheduleId': scheduleId},
    );
  }

  Future<void> notifyScheduleChangeRequested({
    required String ownerUid,
    required String staffDisplayName,
    required String storeId,
    required String scheduleId,
  }) {
    return notifyUser(
      recipientUid: ownerUid,
      kind: NotificationEventKind.scheduleChangeRequested,
      title: NotificationTemplates.scheduleChangeRequestTitle,
      body: NotificationTemplates.scheduleChangeRequestBody(staffDisplayName),
      storeId: storeId,
      data: {'scheduleId': scheduleId},
    );
  }

  Future<void> notifyScheduleChangeResult({
    required String workerUid,
    required bool approved,
    required String storeId,
    required String scheduleId,
  }) {
    return notifyUser(
      recipientUid: workerUid,
      kind: approved
          ? NotificationEventKind.scheduleChangeApproved
          : NotificationEventKind.scheduleChangeRejected,
      title: NotificationTemplates.scheduleChangeResultTitle,
      body: NotificationTemplates.scheduleChangeResultBody(approved: approved),
      storeId: storeId,
      data: {
        'scheduleId': scheduleId,
        'approved': '$approved',
      },
    );
  }

  Future<void> notifySwapRequested({
    required String toWorkerUid,
    required String fromDisplayName,
    required String storeId,
    required String swapId,
    required String scheduleId,
  }) {
    return notifyUser(
      recipientUid: toWorkerUid,
      kind: NotificationEventKind.swapRequested,
      title: NotificationTemplates.swapRequestTitle,
      body: NotificationTemplates.swapRequestBody(fromDisplayName),
      storeId: storeId,
      data: {
        'swapId': swapId,
        'scheduleId': scheduleId,
      },
    );
  }

  Future<void> notifySwapColleagueAccepted({
    required String ownerUid,
    required String storeName,
    required String fromName,
    required String toName,
    required String storeId,
    required String swapId,
  }) {
    return notifyUser(
      recipientUid: ownerUid,
      kind: NotificationEventKind.swapColleagueAccepted,
      title: NotificationTemplates.swapOwnerApprovalTitle,
      body: NotificationTemplates.swapOwnerApprovalBody(
        storeName: storeName,
        fromName: fromName,
        toName: toName,
      ),
      storeId: storeId,
      data: {'swapId': swapId},
    );
  }

  Future<void> notifySwapOwnerApproved({
    required String fromWorkerUid,
    required String toWorkerUid,
    required String storeName,
    required String storeId,
    required String swapId,
  }) {
    return notifyMany(
      recipientUids: [fromWorkerUid, toWorkerUid],
      kind: NotificationEventKind.swapOwnerApproved,
      title: NotificationTemplates.swapConfirmedTitle,
      body: NotificationTemplates.swapConfirmedBody(storeName),
      storeId: storeId,
      data: {'swapId': swapId},
    );
  }

  Future<void> notifyAttendance({
    required String ownerUid,
    required String staffDisplayName,
    required bool isClockIn,
    required String storeId,
  }) {
    return notifyUser(
      recipientUid: ownerUid,
      kind: isClockIn
          ? NotificationEventKind.attendanceClockIn
          : NotificationEventKind.attendanceClockOut,
      title: NotificationTemplates.attendanceTitle,
      body: NotificationTemplates.attendanceBody(
        displayName: staffDisplayName,
        isClockIn: isClockIn,
      ),
      storeId: storeId,
      data: {'action': isClockIn ? 'clock_in' : 'clock_out'},
    );
  }

  Future<void> notifyScheduleAbsent({
    required String workerUid,
    required String storeName,
    required String storeId,
    required String scheduleId,
  }) {
    return notifyUser(
      recipientUid: workerUid,
      kind: NotificationEventKind.scheduleAbsent,
      title: NotificationTemplates.absentTitle,
      body: NotificationTemplates.absentBody(storeName),
      storeId: storeId,
      data: {'scheduleId': scheduleId},
    );
  }

  Future<void> notifyStoreNotice({
    required Iterable<String> staffUids,
    required String storeName,
    required String storeId,
    required String noticeId,
  }) {
    return notifyMany(
      recipientUids: staffUids,
      kind: NotificationEventKind.storeNotice,
      title: NotificationTemplates.noticeTitle,
      body: NotificationTemplates.noticeBody(storeName),
      storeId: storeId,
      data: {'noticeId': noticeId},
    );
  }

  String? _resolveToken(Map<String, dynamic> userData) {
    final single = userData['fcmToken'] as String?;
    if (single != null && single.isNotEmpty) return single;
    final list = userData['fcmTokens'];
    if (list is List && list.isNotEmpty) {
      final first = list.first;
      if (first is String && first.isNotEmpty) return first;
    }
    return null;
  }
}
