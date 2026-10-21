import 'package:flutter/material.dart';

import 'app_navigator.dart';
import 'app_route_names.dart';

/// 앱 전역 싱글탑 네비게이션 — 동일 라우트 중복 push 방지
abstract final class AppNavigation {
  AppNavigation._();

  /// 동일 [name]이 스택에 있으면 그 위로 쌓인 화면만 제거하고 재사용.
  /// 없으면 [stopAtNames] / 방 상세 / 루트까지 pop 한 뒤 push.
  static Future<T?> pushSingleTop<T extends Object?>({
    required String name,
    required WidgetBuilder builder,
    List<String> stopAtNames = const [],
  }) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) {
      return Future<T?>.value(null);
    }

    var alreadyPresent = false;
    nav.popUntil((route) {
      final n = route.settings.name;
      if (n == name) {
        alreadyPresent = true;
        return true;
      }
      if (route.isFirst) return true;
      if (n != null && stopAtNames.contains(n)) return true;
      // 방 상세는 하위 화면의 바닥으로 유지
      if (AppRouteNames.isRoomDetail(n)) return true;
      return false;
    });

    if (alreadyPresent) {
      return Future<T?>.value(null);
    }

    return nav.push<T>(
      MaterialPageRoute<T>(
        settings: RouteSettings(name: name),
        builder: builder,
      ),
    );
  }
}
