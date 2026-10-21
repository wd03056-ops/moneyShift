import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../models/enums/notification_type.dart';
import '../../../services/local_notification_service.dart';

/// 알림 수신 카테고리 (근무 / 출퇴근 / 공지)
enum NotificationCategory {
  /// 배정·일정 변경·대타·확인·결근·직원 등록
  schedule,

  /// 출·퇴근·근태 수정
  commute,

  /// 매장 공지
  notice;

  String get prefsKey => name;

  String get titleKo {
    switch (this) {
      case NotificationCategory.schedule:
        return '근무 알림';
      case NotificationCategory.commute:
        return '출퇴근 알림';
      case NotificationCategory.notice:
        return '공지 알림';
    }
  }

  String get subtitleKo {
    switch (this) {
      case NotificationCategory.schedule:
        return '배정·확인·일정 변경·대타·결근·직원 등록';
      case NotificationCategory.commute:
        return '출·퇴근·근태 수정 요청·결과';
      case NotificationCategory.notice:
        return '매장 공지사항';
    }
  }

  static NotificationCategory fromType(NotificationType type) {
    switch (type) {
      case NotificationType.commute:
      case NotificationType.commuteCorrection:
      case NotificationType.commuteCorrectionResult:
        return NotificationCategory.commute;
      case NotificationType.notice:
        return NotificationCategory.notice;
      case NotificationType.register:
      case NotificationType.assign:
      case NotificationType.scheduleConfirmed:
      case NotificationType.requestUpdate:
      case NotificationType.resultUpdate:
      case NotificationType.subRequest:
      case NotificationType.subAccept:
      case NotificationType.subConfirm:
      case NotificationType.absent:
      case NotificationType.generic:
        return NotificationCategory.schedule;
    }
  }

  static NotificationCategory fromFirestoreType(String? type) {
    if (type == null || type.isEmpty) {
      return NotificationCategory.schedule;
    }
    return fromType(NotificationType.fromFirestore(type));
  }
}

/// 사용자별 카테고리 알림 수신 설정
///
/// - 로컬: SharedPreferences `notif_cat_{uid}_{category}`
/// - 레거시: `notif_enabled_{uid}` → 전 카테고리 일괄 이전
class NotificationPreferenceStore extends ChangeNotifier {
  NotificationPreferenceStore._();

  static final NotificationPreferenceStore instance =
      NotificationPreferenceStore._();

  static const _legacyPrefix = 'notif_enabled_';
  static const _catPrefix = 'notif_cat_';

  /// userId → category → enabled
  final Map<String, Map<NotificationCategory, bool>> _cache = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith(_catPrefix)) {
          final rest = key.substring(_catPrefix.length);
          final i = rest.indexOf('_');
          if (i <= 0) continue;
          final uid = rest.substring(0, i);
          final catName = rest.substring(i + 1);
          final cat = NotificationCategory.values
              .where((c) => c.prefsKey == catName)
              .firstOrNull;
          if (cat == null || uid.isEmpty) continue;
          _cache.putIfAbsent(uid, () => {})[cat] =
              prefs.getBool(key) ?? true;
        }
      }
      // 레거시 마스터 플래그 → 카테고리 미설정 시에만 반영
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_legacyPrefix)) continue;
        final uid = key.substring(_legacyPrefix.length);
        if (uid.isEmpty) continue;
        final master = prefs.getBool(key) ?? true;
        final map = _cache.putIfAbsent(uid, () => {});
        for (final cat in NotificationCategory.values) {
          map.putIfAbsent(cat, () => master);
        }
      }
      _loaded = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[NotifPref] load FAIL: $e');
      debugPrint('$st');
      _loaded = true;
    }
  }

  /// 기본값: 허용(true)
  bool isCategoryEnabled(String userId, NotificationCategory category) {
    if (userId.isEmpty) return true;
    return _cache[userId]?[category] ?? true;
  }

  /// 레거시 호환 — 세 카테고리 모두 on 이면 true
  bool isEnabled(String userId) {
    if (userId.isEmpty) return true;
    return NotificationCategory.values
        .every((c) => isCategoryEnabled(userId, c));
  }

  /// 카테고리 on/off. 실패 시 이전 값으로 롤백하고 false.
  ///
  /// - 켤 때 시스템 권한 거부 → false (토글은 꺼진 상태 유지)
  /// - SharedPreferences 저장 실패 → 이전 값 복구 + false
  /// - Firestore 동기화 실패 → 로컬은 유지, true (소프트 실패, 로그만)
  Future<bool> setCategoryEnabled({
    required String userId,
    required NotificationCategory category,
    required bool enabled,
  }) async {
    if (userId.isEmpty) return false;
    await ensureLoaded();

    final previous = isCategoryEnabled(userId, category);
    if (previous == enabled) return true;

    if (enabled) {
      final ok = await ensureSystemPermission();
      if (!ok) {
        debugPrint('[NotifPref] system permission denied → keep OFF');
        _applyLocal(userId, category, false);
        await _persistCategory(userId, category, false);
        return false;
      }
    }

    // 낙관적 UI 반영
    _applyLocal(userId, category, enabled);

    final saved = await _persistCategory(userId, category, enabled);
    if (!saved) {
      debugPrint(
        '[NotifPref] persist FAIL → rollback '
        '${category.prefsKey} $enabled → $previous',
      );
      _applyLocal(userId, category, previous);
      return false;
    }

    final synced = await _syncFirestoreCategories(userId);
    if (!synced) {
      debugPrint(
        '[NotifPref] Firestore sync soft-fail '
        '(local OK) ${category.prefsKey}=$enabled',
      );
    }

    debugPrint(
      '[NotifPref] OK uid=$userId ${category.prefsKey}=$enabled '
      'firestoreSynced=$synced',
    );
    return true;
  }

  void _applyLocal(
    String userId,
    NotificationCategory category,
    bool enabled,
  ) {
    _cache.putIfAbsent(userId, () => {})[category] = enabled;
    notifyListeners();
  }

  /// 레거시: 전 카테고리 일괄
  Future<bool> setEnabled(String userId, bool enabled) async {
    if (userId.isEmpty) return false;
    if (enabled) {
      final ok = await ensureSystemPermission();
      if (!ok) {
        for (final cat in NotificationCategory.values) {
          _cache.putIfAbsent(userId, () => {})[cat] = false;
          await _persistCategory(userId, cat, false);
        }
        notifyListeners();
        return false;
      }
    }
    for (final cat in NotificationCategory.values) {
      _cache.putIfAbsent(userId, () => {})[cat] = enabled;
      await _persistCategory(userId, cat, enabled);
    }
    notifyListeners();
    await _syncFirestoreCategories(userId);
    return true;
  }

  Future<bool> _persistCategory(
    String userId,
    NotificationCategory category,
    bool enabled,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setBool(
        '$_catPrefix${userId}_${category.prefsKey}',
        enabled,
      );
      return ok;
    } catch (e, st) {
      debugPrint('[NotifPref] save FAIL: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Firestore `users/{uid}.notificationCategories` 동기화. 미초기화·비로그인 시 true(스킵).
  Future<bool> _syncFirestoreCategories(String userId) async {
    if (!FirebaseBootstrap.isInitialized) return true;
    final authUid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null || authUid != userId) return true;
    try {
      final cats = {
        for (final c in NotificationCategory.values)
          c.prefsKey: isCategoryEnabled(userId, c),
      };
      await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(userId)
          .set({
        'notificationCategories': cats,
        'isNotificationEnabled': isEnabled(userId),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e, st) {
      debugPrint('[NotifPref] Firestore sync FAIL: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// 탈퇴·로컬 초기화 시 메모리 캐시만 비움 (prefs는 LocalDataCleaner가 clear)
  void clearMemoryCache() {
    _cache.clear();
    _loaded = false;
    notifyListeners();
  }

  /// 디버그/테스트용 — 카테고리별 on/off 요약
  String debugSummary(String userId) {
    if (userId.isEmpty) return '(no uid)';
    return NotificationCategory.values
        .map(
          (c) =>
              '${c.titleKo}:${isCategoryEnabled(userId, c) ? 'ON' : 'OFF'}',
        )
        .join(' · ');
  }

  Future<bool> ensureSystemPermission() async {
    var ok = true;
    try {
      if (FirebaseBootstrap.isInitialized) {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        final status = settings.authorizationStatus;
        ok = status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional;
        debugPrint('[NotifPref] FCM permission=$status');
      }
    } catch (e) {
      debugPrint('[NotifPref] FCM permission check FAIL: $e');
    }
    final localOk = await LocalNotificationService.instance.requestPermission();
    return ok && localOk;
  }

  /// 카테고리별 수신 여부 (타입 문자열 = firestoreValue)
  bool shouldDeliver({
    required String userId,
    required String type,
  }) {
    final cat = NotificationCategory.fromFirestoreType(type);
    final ok = isCategoryEnabled(userId, cat);
    if (!ok) {
      debugPrint(
        '[NotifPref] block deliver uid=$userId type=$type '
        'category=${cat.prefsKey}',
      );
    }
    return ok;
  }
}
