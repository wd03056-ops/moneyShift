import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/firebase/firebase_bootstrap.dart';
import '../../../services/local_notification_service.dart';

/// 사용자별 푸시/알림함 수신 허용 (`isNotificationEnabled`)
///
/// - 로컬: SharedPreferences `notif_enabled_{uid}`
/// - 원격: `users/{uid}.isNotificationEnabled` (본인만 수정 — Security Rules)
class NotificationPreferenceStore extends ChangeNotifier {
  NotificationPreferenceStore._();

  static final NotificationPreferenceStore instance =
      NotificationPreferenceStore._();

  static const _keyPrefix = 'notif_enabled_';

  final Map<String, bool> _cache = {};
  bool _loaded = false;

  /// 기본값: 허용(true)
  bool isEnabled(String userId) {
    if (userId.isEmpty) return true;
    return _cache[userId] ?? true;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_keyPrefix)) continue;
        final uid = key.substring(_keyPrefix.length);
        if (uid.isEmpty) continue;
        _cache[uid] = prefs.getBool(key) ?? true;
      }
      _loaded = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[NotifPref] load FAIL: $e');
      debugPrint('$st');
      _loaded = true;
    }
  }

  /// 토글 변경 — 시스템 권한 확인 + 로컬/원격 저장
  Future<bool> setEnabled(String userId, bool enabled) async {
    if (userId.isEmpty) return false;

    if (enabled) {
      final ok = await ensureSystemPermission();
      if (!ok) {
        debugPrint('[NotifPref] system permission denied — keep disabled');
        _cache[userId] = false;
        notifyListeners();
        await _persist(userId, false);
        return false;
      }
    }

    _cache[userId] = enabled;
    notifyListeners();
    await _persist(userId, enabled);
    await _syncFirestore(userId, enabled);
    return true;
  }

  Future<void> _persist(String userId, bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_keyPrefix$userId', enabled);
      debugPrint('[NotifPref] uid=$userId enabled=$enabled');
    } catch (e, st) {
      debugPrint('[NotifPref] save FAIL: $e');
      debugPrint('$st');
    }
  }

  /// Firestore 본인 문서만 갱신 (Rules: isSelf)
  Future<void> _syncFirestore(String userId, bool enabled) async {
    if (!FirebaseBootstrap.isInitialized) return;
    final authUid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    // Mock UID 와 Auth UID 가 다를 수 있음 — Auth 본인일 때만 원격 동기화
    if (authUid == null || authUid != userId) {
      debugPrint(
        '[NotifPref] skip Firestore sync authUid=$authUid userId=$userId',
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(userId)
          .set({
        'isNotificationEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('[NotifPref] Firestore sync FAIL: $e');
      debugPrint('$st');
    }
  }

  /// FCM + 로컬 알림 시스템 권한
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

  /// 긴급 운영 알림은 수신 거부 시에도 전달
  static bool isMandatoryType(String type) {
    switch (type) {
      case 'assign':
      case 'schedule_assigned':
      case 'absent':
      case 'schedule_absent':
      case 'commute_correction':
      case 'commute_correction_result':
        return true;
      default:
        return false;
    }
  }

  /// 수신 여부 — 거부 + 비긴급이면 false
  bool shouldDeliver({
    required String userId,
    required String type,
  }) {
    if (isMandatoryType(type)) return true;
    return isEnabled(userId);
  }
}
