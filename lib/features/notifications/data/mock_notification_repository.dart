import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../models/enums/notification_type.dart';
import '../../../models/notification_model.dart';
import '../domain/notification_dedupe.dart';

/// Mock / MockStore 전용 — 수신자(`targetUserId`)별 인메모리 알림함
///
/// 계정 전환 후에도 사장·직원 각각의 알림이 유지되며,
/// [ChangeNotifier] + [watch] 로 배지·알림함이 즉시 갱신됩니다.
class MockNotificationRepository extends ChangeNotifier {
  MockNotificationRepository._();

  static final MockNotificationRepository instance =
      MockNotificationRepository._();

  final _uuid = const Uuid();
  final Map<String, List<NotificationModel>> _byUser = {};
  final _changeController = StreamController<void>.broadcast();

  /// 수신자 알림함에 추가 (발신자≠수신자 강제)
  NotificationModel addNotification(
    String targetUserId,
    NotificationModel notificationData, {
    bool notify = true,
  }) {
    if (targetUserId.isEmpty) {
      debugPrint('[MockNotif] skip — empty targetUserId');
      return notificationData;
    }

    final id = notificationData.id.isNotEmpty
        ? notificationData.id
        : _uuid.v4();
    final item = notificationData.copyWith(
      id: id,
      userId: targetUserId,
    );

    final fp = NotificationDedupe.contentFingerprint(
      userId: targetUserId,
      type: item.type.firestoreValue,
      title: item.title,
      body: item.body,
      storeId: item.storeId,
    );
    if (NotificationDedupe.shouldSkip(fp)) {
      debugPrint(
        '[MockNotif] skip duplicate → $targetUserId '
        'type=${item.type.firestoreValue}',
      );
      return item;
    }

    final list = _byUser.putIfAbsent(targetUserId, () => []);
    list.insert(0, item);
    // 사용자당 최근 200건 유지
    if (list.length > 200) {
      list.removeRange(200, list.length);
    }

    debugPrint(
      '[MockNotif] + ${item.type.firestoreValue} → $targetUserId '
      'title=${item.title}',
    );

    if (notify) {
      _emit();
    }
    return item;
  }

  /// 동일 알림을 여러 수신자에게 복제 저장 (공지·대타 확정 등)
  void addNotificationToMany(
    Iterable<String> targetUserIds,
    NotificationModel template,
  ) {
    final unique = targetUserIds.where((e) => e.isNotEmpty).toSet();
    for (final uid in unique) {
      addNotification(
        uid,
        template.copyWith(id: _uuid.v4(), userId: uid),
        notify: false,
      );
    }
    if (unique.isNotEmpty) _emit();
  }

  /// 편의: 템플릿 필드만으로 생성
  NotificationModel createAndAdd({
    required String targetUserId,
    required NotificationType type,
    required String title,
    required String body,
    String storeId = '',
    Map<String, String> data = const {},
  }) {
    return addNotification(
      targetUserId,
      NotificationModel.withDeepLink(
        id: _uuid.v4(),
        userId: targetUserId,
        storeId: storeId,
        type: type,
        title: title,
        body: body,
        isRead: false,
        createdAt: DateTime.now(),
        data: data,
      ),
    );
  }

  List<NotificationModel> listFor(String userId) {
    final list = List<NotificationModel>.from(_byUser[userId] ?? const []);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int unreadCount(String userId) =>
      (_byUser[userId] ?? const []).where((e) => !e.isRead).length;

  Stream<List<NotificationModel>> watch(String userId) async* {
    yield listFor(userId);
    await for (final _ in _changeController.stream) {
      yield listFor(userId);
    }
  }

  void markRead({
    required String userId,
    required Iterable<String> ids,
    required bool isRead,
  }) {
    final list = _byUser[userId];
    if (list == null) return;
    final idSet = ids.toSet();
    var changed = false;
    for (var i = 0; i < list.length; i++) {
      if (idSet.contains(list[i].id) && list[i].isRead != isRead) {
        list[i] = list[i].copyWith(isRead: isRead);
        changed = true;
      }
    }
    if (changed) _emit();
  }

  void deleteMany({
    required String userId,
    required Iterable<String> ids,
  }) {
    final list = _byUser[userId];
    if (list == null) return;
    final idSet = ids.toSet();
    final before = list.length;
    list.removeWhere((e) => idSet.contains(e.id));
    if (list.length != before) _emit();
  }

  void clearUser(String userId) {
    if (_byUser.remove(userId) != null) _emit();
  }

  void clearAll() {
    _byUser.clear();
    _emit();
  }

  void _emit() {
    notifyListeners();
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }
}
