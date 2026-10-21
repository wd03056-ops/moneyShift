import 'package:flutter/material.dart';

import '../../features/rooms/presentation/room_detail_screen.dart';
import '../../mock/mock_store.dart';
import '../../models/models.dart';
import 'app_navigation.dart';
import 'app_navigator.dart';
import 'app_route_names.dart';

/// 방 상세 딥링크 의도 — 이미 열린 [RoomDetailScreen]이 구독해 탭만 전환
class RoomNavIntent {
  const RoomNavIntent({
    required this.roomId,
    this.tabIndex,
    this.focusRequestId,
    this.focusScheduleId,
    this.focusSwapId,
    required this.token,
  });

  final String roomId;
  final int? tabIndex;
  final String? focusRequestId;
  final String? focusScheduleId;
  final String? focusSwapId;

  /// 동일 탭 재진입도 감지하기 위한 단조 증가 토큰
  final int token;
}

/// 방 상세 싱글탑 네비게이션 (알림 딥링크 · 목록 진입 공용)
abstract final class RoomNavigation {
  RoomNavigation._();

  static final ValueNotifier<RoomNavIntent?> intent =
      ValueNotifier<RoomNavIntent?>(null);

  static int _token = 0;

  static String routeName(String roomId) => AppRouteNames.room(roomId);

  /// [roomId] 방 상세로 이동. 이미 스택에 있으면 push 없이 탭만 갱신.
  static void openRoom({
    required String roomId,
    RoomMembershipEntry? entry,
    int? tabIndex,
    String? focusRequestId,
    String? focusScheduleId,
    String? focusSwapId,
  }) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    final name = routeName(roomId);
    final resolvedEntry = entry ?? MockStore.instance.roomEntry(roomId);

    var found = false;
    nav.popUntil((route) {
      if (route.settings.name == name) {
        found = true;
        return true;
      }
      if (route.isFirst) return true;
      return false;
    });

    _publishIntent(
      roomId: roomId,
      tabIndex: tabIndex,
      focusRequestId: focusRequestId,
      focusScheduleId: focusScheduleId,
      focusSwapId: focusSwapId,
    );

    if (!found) {
      nav.push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => RoomDetailScreen(
            roomId: roomId,
            initialEntry: resolvedEntry,
            initialTabIndex: tabIndex,
            focusRequestId: focusRequestId,
            focusScheduleId: focusScheduleId,
            focusSwapId: focusSwapId,
          ),
        ),
      );
    }
  }

  static void _publishIntent({
    required String roomId,
    int? tabIndex,
    String? focusRequestId,
    String? focusScheduleId,
    String? focusSwapId,
  }) {
    intent.value = RoomNavIntent(
      roomId: roomId,
      tabIndex: tabIndex,
      focusRequestId: focusRequestId,
      focusScheduleId: focusScheduleId,
      focusSwapId: focusSwapId,
      token: ++_token,
    );
  }

  /// 해당 방 의도만 소비 (다른 방 화면은 무시)
  static RoomNavIntent? takeIntentFor(String roomId) {
    final current = intent.value;
    if (current == null || current.roomId != roomId) return null;
    intent.value = null;
    return current;
  }

  /// 하위 화면 싱글탑 (알림함·배정표 등)
  static Future<T?> pushSingleTop<T extends Object?>({
    required String name,
    required WidgetBuilder builder,
    List<String> stopAtNames = const [],
  }) =>
      AppNavigation.pushSingleTop<T>(
        name: name,
        builder: builder,
        stopAtNames: stopAtNames,
      );
}
