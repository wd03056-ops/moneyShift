import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/navigation/notification_deep_link.dart';
import '../../../core/navigation/room_navigation.dart';
import '../../../core/security/secure_log.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_store.dart';
import '../../../models/enums/notification_type.dart';
import '../../../models/notification_model.dart';
import '../../attendance/presentation/commute_correction_review_dialog.dart';
import '../../attendance/presentation/owner_commute_dashboard_screen.dart';
import '../../notices/presentation/notice_board_screen.dart';
import '../../schedules/presentation/staff_assigned_schedule_screen.dart';
import '../presentation/notification_inbox_screen.dart';

/// FCM 탭 / 알림함 / 로컬 푸시 → targetRoute 기반 화면 이동
///
/// 방 상세는 [RoomNavigation.openRoom]으로 싱글탑 처리해
/// 알림마다 RoomDetail이 스택에 쌓이지 않도록 한다.
abstract final class NotificationRouter {
  NotificationRouter._();

  static void openInbox([BuildContext? context]) {
    final uid = MockSession.instance.currentUser?.uid;
    if (uid == null) return;
    RoomNavigation.pushSingleTop(
      name: AppRouteNames.inbox,
      builder: (_) => NotificationInboxScreen(uid: uid),
    );
  }

  static void openFromRemoteMessage(RemoteMessage message) {
    final data = <String, String>{};
    message.data.forEach((k, v) => data[k] = '$v');
    final type = NotificationType.fromFirestore(data['type']);
    openDeepLink(
      NotificationDeepLink.parse(
        targetRoute: data['targetRoute'],
        type: type,
        storeId: data['storeId'] ?? '',
        data: data,
      ),
    );
  }

  /// 알림함 항목 클릭 (호출 측에서 isRead 처리 후 호출)
  static void openFromNotification(NotificationModel item) {
    openDeepLink(item.deepLink);
  }

  /// 로컬 푸시 payload (JSON 문자열)
  static void openFromLocalPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final data = <String, String>{};
        for (final e in decoded.entries) {
          data[e.key.toString()] = '${e.value}';
        }
        openDeepLink(
          NotificationDeepLink.parse(
            targetRoute: data['targetRoute'],
            type: NotificationType.fromFirestore(data['type']),
            storeId: data['storeId'] ?? '',
            data: data,
          ),
        );
        return;
      }
    } catch (_) {
      openDeepLink(
        NotificationDeepLink.fromType(
          type: NotificationType.fromFirestore(payload),
          storeId: MockStore.demoRoomId,
        ),
      );
    }
  }

  static void openFromPayload({
    required NotificationType type,
    required String storeId,
    Map<String, String> data = const {},
    String? targetRoute,
  }) {
    openDeepLink(
      NotificationDeepLink.parse(
        targetRoute: targetRoute,
        type: type,
        storeId: storeId,
        data: data,
      ),
    );
  }

  /// 프레임 이후 네비게이션 (콜드 스타트·스낵바 액션 안전)
  static void openDeepLink(NotificationDeepLink link) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigate(link));
    } else {
      _navigate(link);
    }
  }

  static void _navigate(NotificationDeepLink link) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) {
      SecureLog.d('[NotifRouter] no navigator — drop ${link.uriString}');
      return;
    }

    SecureLog.d('[NotifRouter] → ${link.uriString}');

    final route = NotificationDeepLink.pathOnly(link.targetRoute);

    if (route == NotificationRoutes.inbox || route.isEmpty) {
      openInbox();
      return;
    }

    if (route == NotificationRoutes.noticeDetail) {
      _openNotice(link);
      return;
    }

    if (route == NotificationRoutes.commuteCorrection) {
      final requestId = link.requestId?.trim() ?? '';
      if (requestId.isEmpty) {
        openInbox();
        return;
      }
      CommuteCorrectionReview.openById(requestId);
      return;
    }

    final storeId = link.storeId?.trim() ?? '';
    if (storeId.isEmpty) {
      openInbox();
      return;
    }

    final entry = MockStore.instance.roomEntry(storeId);
    final isOwner = entry?.role.isAdminDashboard ?? false;
    final uid = MockSession.instance.currentUser?.uid;

    // 근무 배정 알림 → 직원 근무 배정표(확인 대기)
    if (route == NotificationRoutes.assignedSchedule) {
      if (uid == null || isOwner) {
        RoomNavigation.openRoom(
          roomId: storeId,
          entry: entry,
          tabIndex: 1, // 사장 근무표
          focusScheduleId: link.shiftId,
        );
        return;
      }
      // 방 상세(직원) 위에 배정표만 싱글탑
      RoomNavigation.openRoom(
        roomId: storeId,
        entry: entry,
        tabIndex: 0,
      );
      RoomNavigation.pushSingleTop(
        name: AppRouteNames.assignedSchedule(storeId),
        stopAtNames: [AppRouteNames.room(storeId)],
        builder: (_) => StaffAssignedScheduleScreen(
          roomId: storeId,
          workerId: uid,
        ),
      );
      return;
    }

    if (route == NotificationRoutes.commuteHistory && isOwner) {
      RoomNavigation.openRoom(
        roomId: storeId,
        entry: entry,
        tabIndex: 0, // 사장 직원목록 (출퇴근 대시보드는 push)
      );
      RoomNavigation.pushSingleTop(
        name: AppRouteNames.ownerCommute(storeId),
        stopAtNames: [AppRouteNames.room(storeId)],
        builder: (_) => OwnerCommuteDashboardScreen(roomId: storeId),
      );
      return;
    }

    final tab = NotificationDeepLink.tabIndexFor(
      targetRoute: route,
      isOwner: isOwner,
    );

    // 메인 탭 목적지 → push 없이 방 상세 싱글탑 + 탭 인덱스만 변경
    RoomNavigation.openRoom(
      roomId: storeId,
      entry: entry,
      tabIndex: tab,
      focusRequestId: link.requestId,
      focusScheduleId: link.shiftId,
      focusSwapId: link.swapId,
    );
  }

  static void _openNotice(NotificationDeepLink link) {
    final storeId = link.storeId?.trim() ?? '';
    final noticeId = link.noticeId?.trim() ?? '';
    if (noticeId.isEmpty) {
      if (storeId.isNotEmpty) {
        RoomNavigation.openRoom(roomId: storeId, tabIndex: 0);
      } else {
        openInbox();
      }
      return;
    }

    final entry =
        storeId.isNotEmpty ? MockStore.instance.roomEntry(storeId) : null;
    final canManage = entry?.role.isAdminDashboard ?? false;

    if (storeId.isNotEmpty) {
      RoomNavigation.openRoom(roomId: storeId, entry: entry, tabIndex: 0);
    }

    RoomNavigation.pushSingleTop(
      name: AppRouteNames.noticeDetail(noticeId),
      stopAtNames: [
        if (storeId.isNotEmpty) AppRouteNames.room(storeId),
      ],
      builder: (_) => NoticeDetailScreen(
        noticeId: noticeId,
        canManage: canManage,
      ),
    );
  }

  /// Mock/테스트: 8종 타입 라우트 문자열 검증
  static Map<NotificationType, String> debugRouteMap() {
    return {
      for (final t in NotificationType.values)
        if (t != NotificationType.generic)
          t: NotificationDeepLink.routeForType(t),
    };
  }
}
