import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/navigation/notification_deep_link.dart';
import '../features/notifications/domain/notification_router.dart';
import '../models/enums/notification_type.dart';
import 'fcm_service.dart';

/// 기기 상단 알림창 로컬 푸시 (테스트·포그라운드 보조)
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  int _seq = 1000;

  Future<void> init() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          FcmService.androidChannelId,
          'Money Shift',
          description: '근무·출퇴근·공지 알림',
          importance: Importance.high,
        ),
      );

      // 종료 상태에서 로컬 알림 탭으로 앱이 열린 경우
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        final payload = launch!.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          // runApp 이후 네비게이션을 위해 약간 지연
          Future<void>.delayed(const Duration(milliseconds: 600), () {
            NotificationRouter.openFromLocalPayload(payload);
          });
        }
      }

      _ready = true;
      debugPrint('[LocalNotif] initialized');
    } catch (e, st) {
      debugPrint('[LocalNotif] init FAIL: $e');
      debugPrint('$st');
    }
  }

  static void _onNotificationResponse(NotificationResponse response) {
    NotificationRouter.openFromLocalPayload(response.payload);
  }

  Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final ok = (granted ?? true) && (iosGranted ?? true);
      debugPrint('[LocalNotif] permission android=$granted ios=$iosGranted');
      return ok;
    } catch (e) {
      debugPrint('[LocalNotif] requestPermission FAIL: $e');
      return false;
    }
  }

  Future<void> show({
    required String title,
    required String body,
    String? payload,
    NotificationType? type,
    String storeId = '',
    Map<String, String> data = const {},
  }) async {
    await init();
    try {
      final id = ++_seq;
      final resolvedPayload = payload ??
          (type != null
              ? jsonEncode(
                  NotificationDeepLink.fromType(
                    type: type,
                    storeId: storeId,
                    data: data,
                  ).toPayloadMap(type: type.firestoreValue),
                )
              : null);

      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            FcmService.androidChannelId,
            'Money Shift',
            channelDescription: '근무·출퇴근·공지 알림',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: resolvedPayload,
      );
      debugPrint('[LocalNotif] show id=$id title=$title');
    } catch (e, st) {
      debugPrint('[LocalNotif] show FAIL: $e');
      debugPrint('$st');
    }
  }
}
