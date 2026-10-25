import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/notifications/data/mock_notification_repository.dart';
import '../../features/notifications/data/notification_preference_store.dart';
import '../../features/notifications/domain/notification_dedupe.dart';
import '../deeplink/invite_deep_link_service.dart';
import 'dashboard_pay_view_store.dart';
import 'secure_session_storage.dart';

/// 탈퇴·로그아웃 시 기기 로컬 데이터 정리
abstract final class LocalDataCleaner {
  LocalDataCleaner._();

  /// 계정 탈퇴용 — SecureStorage + SharedPreferences 전량 + 메모리 캐시
  static Future<void> clearAllForAccountDeletion({String? userId}) async {
    await SecureSessionStorage.instance.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('[LocalDataCleaner] SharedPreferences.clear OK');
    } catch (e, st) {
      debugPrint('[LocalDataCleaner] SharedPreferences.clear FAIL: $e');
      debugPrint('$st');
    }

    await _clearMemoryCaches(userId: userId);
  }

  /// 로그아웃 로그아웃용 — 세션 토큰만 (고지 동의 등 prefs는 유지)
  static Future<void> clearSessionOnly({String? userId}) async {
    await SecureSessionStorage.instance.clear();
    try {
      await InviteDeepLinkService.instance.clearPendingCode();
    } catch (_) {}
    if (userId != null && userId.isNotEmpty) {
      MockNotificationRepository.instance.clearUser(userId);
    }
    NotificationDedupe.clear();
  }

  static Future<void> _clearMemoryCaches({String? userId}) async {
    try {
      await InviteDeepLinkService.instance.clearPendingCode();
    } catch (_) {}

    NotificationPreferenceStore.instance.clearMemoryCache();
    DashboardPayViewStore.instance.clearMemoryCache();
    NotificationDedupe.clear();

    if (userId != null && userId.isNotEmpty) {
      MockNotificationRepository.instance.clearUser(userId);
    } else {
      MockNotificationRepository.instance.clearAll();
    }
  }
}
