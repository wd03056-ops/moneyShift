import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/navigation/notification_deep_link.dart';
import '../../../core/time/kst_date_time.dart';
import '../../../mock/mock_session.dart';
import '../../../models/enums/notification_type.dart';
import '../../../models/notification_model.dart';
import '../../../services/local_notification_service.dart';
import '../../../services/notification_service.dart';
import '../data/mock_notification_repository.dart';
import '../data/notification_preference_store.dart';
import 'notification_dedupe.dart';
import 'notification_sanitizer.dart';
import 'notification_templates.dart';

/// MockStore / UI 플로우에서 알림 발송
///
/// 1) Mock 인박스 (수신자 UID별, 계정 전환 즉시 반영)
/// 2) 현재 계정이 수신자면 로컬 알림 배너
/// 3) Firestore 인박스 + `notification_jobs` → FCM
abstract final class AppNotificationDispatcher {
  AppNotificationDispatcher._();

  static MockNotificationRepository get _mock =>
      MockNotificationRepository.instance;

  static NotificationService get _svc => NotificationService.instance;

  static void staffJoined({
    required String ownerUid,
    required String staffDisplayName,
    required String storeId,
    String? staffUid,
  }) {
    final key = NotificationDedupe.staffJoinedKey(
      storeId,
      staffUid ?? staffDisplayName,
    );
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [ownerUid],
      type: NotificationType.register,
      title: NotificationTemplates.staffJoinedTitle,
      body: NotificationTemplates.staffJoinedBody(staffDisplayName),
      storeId: storeId,
      kind: NotificationEventKind.staffJoined,
      dedupeKey: key,
    );
  }

  static void scheduleAssigned({
    required String workerUid,
    required String storeId,
    required String scheduleId,
    required String storeName,
    String? assignmentBatchId,
  }) {
    final idKey = NotificationDedupe.scheduleAssignKey(
      storeId: storeId,
      workerUid: workerUid,
      scheduleOrBatchId: assignmentBatchId ?? scheduleId,
    );
    final burstKey = NotificationDedupe.scheduleAssignBurstKey(
      storeId: storeId,
      workerUid: workerUid,
    );
    // id·burst 를 각각 검사 — || 단락 평가로 burst 키가 잘못 마킹되지 않게
    if (NotificationDedupe.shouldSkip(idKey)) return;
    if (NotificationDedupe.shouldSkip(burstKey)) return;
    _deliver(
      targetUserIds: [workerUid],
      type: NotificationType.assign,
      title: NotificationTemplates.scheduleAssignedTitle,
      body: NotificationTemplates.scheduleAssignedBody(storeName),
      storeId: storeId,
      data: {'scheduleId': scheduleId},
      kind: NotificationEventKind.scheduleAssigned,
      dedupeKey: idKey,
    );
  }

  /// 직원이 배정 근무를 확인 → 사장
  static void scheduleConfirmed({
    required String ownerUid,
    required String staffDisplayName,
    required String storeId,
    required String scheduleId,
    String? assignmentBatchId,
  }) {
    final key = NotificationDedupe.scheduleConfirmKey(
      assignmentBatchId ?? scheduleId,
    );
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [ownerUid],
      type: NotificationType.scheduleConfirmed,
      title: NotificationTemplates.scheduleConfirmedTitle,
      body: NotificationTemplates.scheduleConfirmedBody(staffDisplayName),
      storeId: storeId,
      data: {'scheduleId': scheduleId},
      kind: NotificationEventKind.scheduleConfirmed,
      dedupeKey: key,
    );
  }

  static void scheduleChangeRequested({
    required String ownerUid,
    required String staffDisplayName,
    required String storeId,
    required String scheduleId,
  }) {
    final key = NotificationDedupe.scheduleChangeRequestKey(
      scheduleId,
      dir: 'to_owner',
    );
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [ownerUid],
      type: NotificationType.requestUpdate,
      title: NotificationTemplates.scheduleChangeRequestTitle,
      body: NotificationTemplates.scheduleChangeRequestBody(staffDisplayName),
      storeId: storeId,
      data: {'scheduleId': scheduleId},
      kind: NotificationEventKind.scheduleChangeRequested,
      dedupeKey: key,
    );
  }

  /// 사장 → 직원 일정 변경 요청
  static void ownerScheduleChangeRequested({
    required String workerUid,
    required String storeName,
    required String storeId,
    required String scheduleId,
  }) {
    final key = NotificationDedupe.scheduleChangeRequestKey(
      scheduleId,
      dir: 'to_worker',
    );
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [workerUid],
      type: NotificationType.requestUpdate,
      title: NotificationTemplates.ownerScheduleChangeRequestTitle,
      body: NotificationTemplates.ownerScheduleChangeRequestBody(storeName),
      storeId: storeId,
      data: {'scheduleId': scheduleId},
      kind: NotificationEventKind.scheduleChangeRequested,
      dedupeKey: key,
    );
  }

  static void scheduleChangeResult({
    required String workerUid,
    required bool approved,
    required String storeId,
    required String scheduleId,
  }) {
    final key = NotificationDedupe.scheduleChangeResultKey(
      scheduleId,
      approved,
      dir: 'to_worker',
    );
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [workerUid],
      type: NotificationType.resultUpdate,
      title: NotificationTemplates.scheduleChangeResultTitle,
      body: NotificationTemplates.scheduleChangeResultBody(approved: approved),
      storeId: storeId,
      data: {
        'scheduleId': scheduleId,
        'approved': '$approved',
      },
      kind: approved
          ? NotificationEventKind.scheduleChangeApproved
          : NotificationEventKind.scheduleChangeRejected,
      dedupeKey: key,
    );
  }

  /// 직원이 사장 변경 요청을 수락/거절 → 사장
  static void staffScheduleChangeResult({
    required String ownerUid,
    required String staffDisplayName,
    required bool approved,
    required String storeId,
    required String scheduleId,
  }) {
    final key = NotificationDedupe.scheduleChangeResultKey(
      scheduleId,
      approved,
      dir: 'to_owner',
    );
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [ownerUid],
      type: NotificationType.resultUpdate,
      title: NotificationTemplates.staffScheduleChangeResultTitle,
      body: NotificationTemplates.staffScheduleChangeResultBody(
        displayName: staffDisplayName,
        approved: approved,
      ),
      storeId: storeId,
      data: {
        'scheduleId': scheduleId,
        'approved': '$approved',
      },
      kind: approved
          ? NotificationEventKind.scheduleChangeApproved
          : NotificationEventKind.scheduleChangeRejected,
      dedupeKey: key,
    );
  }

  static void swapRequested({
    required String toWorkerUid,
    required String fromDisplayName,
    required String storeId,
    required String swapId,
    required String scheduleId,
  }) {
    final key = NotificationDedupe.swapKey(swapId, 'request');
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [toWorkerUid],
      type: NotificationType.subRequest,
      title: NotificationTemplates.swapRequestTitle,
      body: NotificationTemplates.swapRequestBody(fromDisplayName),
      storeId: storeId,
      data: {
        'swapId': swapId,
        'scheduleId': scheduleId,
        'requestId': swapId,
      },
      kind: NotificationEventKind.swapRequested,
      dedupeKey: key,
    );
  }

  static void swapColleagueAccepted({
    required String ownerUid,
    required String storeName,
    required String fromName,
    required String toName,
    required String storeId,
    required String swapId,
  }) {
    final key = NotificationDedupe.swapKey(swapId, 'colleague');
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [ownerUid],
      type: NotificationType.subAccept,
      title: NotificationTemplates.swapOwnerApprovalTitle,
      body: NotificationTemplates.swapOwnerApprovalBody(
        storeName: storeName,
        fromName: fromName,
        toName: toName,
      ),
      storeId: storeId,
      data: {'swapId': swapId, 'requestId': swapId},
      kind: NotificationEventKind.swapColleagueAccepted,
      dedupeKey: key,
    );
  }

  static void swapOwnerApproved({
    required String fromWorkerUid,
    required String toWorkerUid,
    required String storeName,
    required String storeId,
    required String swapId,
  }) {
    final key = NotificationDedupe.swapKey(swapId, 'owner');
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [fromWorkerUid, toWorkerUid],
      type: NotificationType.subConfirm,
      title: NotificationTemplates.swapConfirmedTitle,
      body: NotificationTemplates.swapConfirmedBody(storeName),
      storeId: storeId,
      data: {'swapId': swapId, 'requestId': swapId},
      kind: NotificationEventKind.swapOwnerApproved,
      dedupeKey: key,
    );
  }

  /// 동료가 대타 거절 → 요청자
  static void swapColleagueRejected({
    required String fromWorkerUid,
    required String toDisplayName,
    required String storeId,
    required String swapId,
  }) {
    final key = NotificationDedupe.swapKey(swapId, 'colleague_reject');
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [fromWorkerUid],
      type: NotificationType.resultUpdate,
      title: NotificationTemplates.swapRejectedTitle,
      body: NotificationTemplates.swapRejectedByColleagueBody(toDisplayName),
      storeId: storeId,
      data: {'swapId': swapId, 'requestId': swapId},
      kind: NotificationEventKind.swapRejected,
      dedupeKey: key,
    );
  }

  /// 사장이 대타 거절 → 요청자·대상자
  static void swapOwnerRejected({
    required String fromWorkerUid,
    required String toWorkerUid,
    required String storeName,
    required String storeId,
    required String swapId,
  }) {
    final key = NotificationDedupe.swapKey(swapId, 'owner_reject');
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [fromWorkerUid, toWorkerUid],
      type: NotificationType.resultUpdate,
      title: NotificationTemplates.swapRejectedTitle,
      body: NotificationTemplates.swapRejectedByOwnerBody(storeName),
      storeId: storeId,
      data: {'swapId': swapId, 'requestId': swapId},
      kind: NotificationEventKind.swapRejected,
      dedupeKey: key,
    );
  }

  static void attendance({
    required String ownerUid,
    required String staffDisplayName,
    required bool isClockIn,
    required String storeId,
    String? workerUid,
  }) {
    final dayKey = KstDateTime.todayKey();
    final dedupeKey = NotificationDedupe.attendanceKey(
      storeId: storeId,
      workerUid: workerUid ?? staffDisplayName,
      isClockIn: isClockIn,
      dayKey: dayKey,
    );
    if (NotificationDedupe.shouldSkip(dedupeKey)) return;

    _deliver(
      targetUserIds: [ownerUid],
      type: NotificationType.commute,
      title: NotificationTemplates.attendanceTitle,
      body: NotificationTemplates.attendanceBody(
        displayName: staffDisplayName,
        isClockIn: isClockIn,
      ),
      storeId: storeId,
      data: {
        'action': isClockIn ? 'clock_in' : 'clock_out',
        'workerId': ?workerUid,
      },
      kind: isClockIn
          ? NotificationEventKind.attendanceClockIn
          : NotificationEventKind.attendanceClockOut,
      dedupeKey: dedupeKey,
    );
  }

  static void commuteCorrectionRequested({
    required String workerUid,
    required String storeName,
    required String storeId,
    required String requestId,
  }) {
    final key = NotificationDedupe.correctionRequestKey(requestId);
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [workerUid],
      type: NotificationType.commuteCorrection,
      title: NotificationTemplates.commuteCorrectionRequestTitle,
      body: NotificationTemplates.commuteCorrectionRequestBody(storeName),
      storeId: storeId,
      data: {'requestId': requestId, 'id': requestId},
      kind: NotificationEventKind.commuteCorrectionRequested,
      dedupeKey: key,
    );
  }

  static void commuteCorrectionResult({
    required String ownerUid,
    required String staffDisplayName,
    required bool approved,
    required String storeId,
    required String requestId,
  }) {
    final key = NotificationDedupe.correctionResultKey(requestId, approved);
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [ownerUid],
      type: NotificationType.commuteCorrectionResult,
      title: approved
          ? NotificationTemplates.commuteCorrectionApprovedTitle
          : NotificationTemplates.commuteCorrectionRejectedTitle,
      body: approved
          ? NotificationTemplates.commuteCorrectionApprovedBody(staffDisplayName)
          : NotificationTemplates.commuteCorrectionRejectedBody(
              staffDisplayName,
            ),
      storeId: storeId,
      data: {
        'requestId': requestId,
        'approved': '$approved',
      },
      kind: approved
          ? NotificationEventKind.commuteCorrectionApproved
          : NotificationEventKind.commuteCorrectionRejected,
      dedupeKey: key,
    );
  }

  static void scheduleAbsent({
    required String workerUid,
    required String storeName,
    required String storeId,
    required String scheduleId,
  }) {
    final key = NotificationDedupe.scheduleAbsentKey(scheduleId);
    if (NotificationDedupe.shouldSkip(key)) return;
    _deliver(
      targetUserIds: [workerUid],
      type: NotificationType.absent,
      title: NotificationTemplates.absentTitle,
      body: NotificationTemplates.absentBody(storeName),
      storeId: storeId,
      data: {'scheduleId': scheduleId},
      kind: NotificationEventKind.scheduleAbsent,
      dedupeKey: key,
    );
  }

  static void storeNotice({
    required Iterable<String> staffUids,
    required String storeName,
    required String storeId,
    required String noticeId,
  }) {
    final key = NotificationDedupe.storeNoticeKey(noticeId);
    if (NotificationDedupe.shouldSkip(
      key,
      window: NotificationDedupe.noticeWindow,
    )) {
      return;
    }
    _deliver(
      targetUserIds: staffUids,
      type: NotificationType.notice,
      title: NotificationTemplates.noticeTitle,
      body: NotificationTemplates.noticeBody(storeName),
      storeId: storeId,
      data: {'noticeId': noticeId},
      kind: NotificationEventKind.storeNotice,
      dedupeKey: key,
    );
  }

  /// 수신자별로 Mock 저장 + Firestore/FCM + (현재 계정일 때) 로컬 배너
  ///
  /// 카테고리 토글 OFF 수신자는 스킵.
  /// 내용 중복 차단은 [MockNotificationRepository] / [NotificationService] 한 곳에서만
  /// (여기서 미리 shouldSkipContent 하면 인박스 적재가 영원히 스킵되던 버그 방지).
  static void _deliver({
    required Iterable<String> targetUserIds,
    required NotificationType type,
    required String title,
    required String body,
    required String storeId,
    required NotificationEventKind kind,
    Map<String, String> data = const {},
    String? dedupeKey,
  }) {
    if (dedupeKey != null &&
        NotificationDedupe.shouldSkip(
          'deliver:$dedupeKey',
          window: const Duration(seconds: 2),
        )) {
      debugPrint('[AppNotif] skip duplicate deliver key=$dedupeKey');
      return;
    }

    _run(() async {
      final prefs = NotificationPreferenceStore.instance;
      await prefs.ensureLoaded();
      final typeKey = type.firestoreValue;
      final requested = targetUserIds.where((e) => e.isNotEmpty).toSet();
      final targets = requested
          .where(
            (uid) => prefs.shouldDeliver(userId: uid, type: typeKey),
          )
          .toSet();
      final blocked = requested.difference(targets);

      if (blocked.isNotEmpty) {
        debugPrint(
          '[AppNotif] preference block type=$typeKey '
          'blocked=${blocked.length} allowed=${targets.length}',
        );
      }

      if (targets.isEmpty) {
        debugPrint(
          '[AppNotif] skip — no enabled targets type=$typeKey '
          '(opted-out or empty)',
        );
        return;
      }

      final safeTitle = NotificationSanitizer.sanitizeTitle(title);
      final safeBody = NotificationSanitizer.sanitizeBody(body);
      final safeStoreId =
          NotificationSanitizer.sanitize(storeId, maxLength: 64);

      final link = NotificationDeepLink.fromType(
        type: type,
        storeId: safeStoreId,
        data: data,
      );
      final template = NotificationModel.withDeepLink(
        id: '',
        userId: '',
        storeId: safeStoreId,
        type: type,
        title: safeTitle,
        body: safeBody,
        isRead: false,
        createdAt: DateTime.now(),
        data: data,
        targetRoute: link.targetRoute,
        params: link.params,
      );

      // 1) Mock 인박스 — 계정 전환·배지용 (내용 중복은 repo 내부에서만 차단)
      _mock.addNotificationToMany(targets, template);

      // 2) 현재 로그인 수신자면 로컬 배너 (포그라운드·Mock에서도 체감)
      final currentUid = MockSession.instance.currentUser?.uid;
      if (currentUid != null && targets.contains(currentUid)) {
        await LocalNotificationService.instance.show(
          title: safeTitle,
          body: safeBody,
          type: type,
          storeId: safeStoreId,
          data: data,
        );
      }

      // 3) Firestore 인박스 + FCM job (릴리즈·Mock 공통 — 토큰 있으면 푸시)
      await _svc.notifyMany(
        recipientUids: targets,
        kind: kind,
        title: safeTitle,
        body: safeBody,
        storeId: safeStoreId,
        data: data,
      );
    });
  }

  static void _run(Future<void> Function() fn) {
    unawaited(
      Future<void>(() async {
        try {
          await fn();
        } catch (e, st) {
          debugPrint('[AppNotificationDispatcher] $e');
          debugPrint('$st');
        }
      }),
    );
  }
}
