import 'package:flutter/foundation.dart';

import '../features/notifications/data/mock_notification_repository.dart';
import 'mock_session.dart';
import 'mock_store.dart';

/// 앱 전역 Listenable — build() 안에서 Listenable.merge 를 매번 만들지 말 것
/// (dispose 중 _dependents 깨짐 / 리스너 누수 방지)
abstract final class AppListenables {
  AppListenables._();

  static final Listenable sessionAndStore = Listenable.merge([
    MockSession.instance,
    MockStore.instance,
  ]);

  /// 계정 전환 + 알림함 배지용
  static final Listenable sessionAndNotifications = Listenable.merge([
    MockSession.instance,
    MockNotificationRepository.instance,
  ]);
}
