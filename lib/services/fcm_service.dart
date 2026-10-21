import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_paths.dart';
import '../core/firebase/firebase_bootstrap.dart';
import '../core/navigation/app_navigator.dart';
import '../core/security/secure_log.dart';
import '../features/notifications/domain/notification_router.dart';

/// FCM 토큰 등록·포그라운드/백그라운드 수신 핸들러
///
/// - 로그인 후 [bindUser] → `users/{uid}.fcmToken` 저장·갱신
/// - 포그라운드: SnackBar + [onForegroundMessage] 콜백
/// - 알림 탭(백그라운드→포그라운드): [onNotificationOpened]
/// - 백그라운드 isolate: [firebaseMessagingBackgroundHandler] (bootstrap)
class FcmService {
  FcmService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  static final FcmService instance = FcmService();

  /// Android 기본 채널 (Manifest meta-data 와 동일)
  static const String androidChannelId = 'money_shift_default';

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _handlersAttached = false;
  String? _boundUid;

  /// 앱에서 포그라운드 메시지 커스텀 처리 (선택)
  void Function(RemoteMessage message)? onForegroundMessage;

  /// 알림 탭으로 앱이 열렸을 때 (선택)
  void Function(RemoteMessage message)? onNotificationOpened;

  /// 로그인 UID 에 현재 디바이스 FCM 토큰을 바인딩하고 리스너 시작
  Future<void> bindUser(String uid) async {
    if (!FirebaseBootstrap.isInitialized) {
      SecureLog.d('[FCM] skip bind — Firebase not initialized');
      return;
    }
    _boundUid = uid;
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final settings = await _messaging.getNotificationSettings();
      SecureLog.d(
        '[FCM] permission=${settings.authorizationStatus} uid=$uid',
      );

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await saveToken(uid: uid, token: token);
      } else {
        SecureLog.d('[FCM] getToken returned null uid=$uid');
      }

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
        final current = _boundUid;
        if (current == null) return;
        await saveToken(uid: current, token: token);
      });

      await _attachMessageHandlers();

      SecureLog.d('[FCM] bound uid=$uid');
    } catch (e, st) {
      SecureLog.d('[FCM] bind FAIL: $e');
      SecureLog.d('$st');
    }
  }

  /// 핸들러는 앱 생애주기 동안 1회만 등록
  Future<void> _attachMessageHandlers() async {
    if (_handlersAttached) return;
    _handlersAttached = true;

    await _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForeground);

    await _openedSub?.cancel();
    _openedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      SecureLog.d(
        '[FCM][COLD] opened from terminated id=${initial.messageId}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationOpened(initial);
      });
    }
  }

  /// 로그인 전에도 포그라운드 리스너만 미리 붙일 때 사용
  Future<void> ensureHandlers() => _attachMessageHandlers();

  Future<void> saveToken({
    required String uid,
    required String token,
  }) async {
    // 바인딩된 본인 UID 만 토큰 기록 (타 계정 덮어쓰기 방지)
    if (_boundUid != null && _boundUid != uid) {
      SecureLog.d(
        '[FCM] saveToken refused — bound=$_boundUid requested=$uid',
      );
      return;
    }
    if (token.isEmpty) return;
    try {
      final ref = _db.collection(FirestorePaths.users).doc(uid);
      await ref.set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      SecureLog.d(
        '[FCM] token saved uid=$uid token=${SecureLog.redactToken(token)}',
      );
    } on FirebaseException catch (e, st) {
      SecureLog.d('[FCM] saveToken FAIL code=${e.code} message=${e.message}');
      SecureLog.d('$st');
    }
  }

  /// 시스템 알림 권한 상태 조회
  Future<AuthorizationStatus> checkPermissionStatus() async {
    if (!FirebaseBootstrap.isInitialized) {
      return AuthorizationStatus.notDetermined;
    }
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<bool> requestSystemPermission() async {
    if (!FirebaseBootstrap.isInitialized) return false;
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> unbind() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _boundUid = null;
    // 메시지 구독은 앱 전역으로 유지 (재로그인 대비)
  }

  void _handleForeground(RemoteMessage message) {
    SecureLog.d(
      '[FCM][FG] id=${message.messageId} '
      'title=${message.notification?.title}',
    );
    onForegroundMessage?.call(message);
    _showInAppBanner(message);
  }

  void _handleNotificationOpened(RemoteMessage message) {
    SecureLog.d('[FCM][OPEN] id=${message.messageId}');
    onNotificationOpened?.call(message);
    NotificationRouter.openFromRemoteMessage(message);
  }

  /// 포그라운드에서는 OS 배너가 안 뜨는 경우가 많아 SnackBar 로 대체
  void _showInAppBanner(RemoteMessage message) {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    final title = message.notification?.title ??
        message.data['title'] ??
        AppConstants.appName;
    final body = message.notification?.body ??
        message.data['body'] ??
        '새 알림이 있습니다.';

    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$title\n$body',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: '보기',
            onPressed: () => NotificationRouter.openFromRemoteMessage(message),
          ),
          onVisible: () {},
        ),
      );
  }
}
