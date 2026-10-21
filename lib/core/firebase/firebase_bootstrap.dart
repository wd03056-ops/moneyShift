import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../security/secure_log.dart';
import 'firebase_connection_test.dart';

/// FCM 백그라운드/종료 상태 핸들러 (top-level + @pragma 필수)
///
/// 시스템이 isolate 에서 호출합니다. UI / Navigator 사용 금지.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 이미 초기화된 경우 중복 초기화는 Firebase가 무시합니다.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // payload/data 전문은 릴리즈 로그에 남기지 않음
  SecureLog.d(
    '[FCM][BG] id=${message.messageId} '
    'title=${message.notification?.title}',
  );
}

/// Firebase Auth / Firestore / FCM 초기화
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Firebase 초기화. [runConnectionTest] 는 디버그에서만 Firestore 프로브 실행.
  static Future<void> init({bool runConnectionTest = true}) async {
    if (_initialized) {
      SecureLog.d('[Firebase] already initialized — skip');
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final opts = DefaultFirebaseOptions.currentPlatform;
      SecureLog.d(
        '[Firebase] initialized projectId=${opts.projectId}',
      );

      try {
        // 반드시 runApp 전에 등록
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        final messaging = FirebaseMessaging.instance;
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        final token = await messaging.getToken();
        SecureLog.d(
          '[FCM] bootstrap token=${token != null ? "ok" : "null"}',
        );
      } catch (e, st) {
        SecureLog.d('[FCM] setup skipped/failed: $e');
        SecureLog.d('[FCM] stack: $st');
      }

      _initialized = true;

      if (runConnectionTest && kDebugMode) {
        await FirebaseConnectionTest.run();
      }
    } on FirebaseException catch (e, st) {
      SecureLog.d(
        '[Firebase] init FAIL code=${e.code} message=${e.message}',
      );
      SecureLog.d('[Firebase] stack: $st');
      rethrow;
    } catch (e, st) {
      SecureLog.d('[Firebase] init FAIL error=$e');
      SecureLog.d('[Firebase] stack: $st');
      rethrow;
    }
  }
}
