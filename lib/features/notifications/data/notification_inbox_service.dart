import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/dev_auth_config.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../models/notification_item.dart';
import 'mock_notification_repository.dart';

/// 알림함 CRUD
///
/// Mock 인증: [MockNotificationRepository] (수신자 UID별 인메모리)
/// 실서비스: `users/{uid}/notifications`
class NotificationInboxService {
  NotificationInboxService({
    FirebaseFirestore? firestore,
    MockNotificationRepository? mock,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _mock = mock ?? MockNotificationRepository.instance;

  final FirebaseFirestore _db;
  final MockNotificationRepository _mock;

  bool get _useMock => DevAuthConfig.isMockAuthEnabled;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection(FirestorePaths.userNotifications(uid));

  Stream<List<NotificationItem>> watchInbox(String recipientUid) {
    if (_useMock) {
      return _mock.watch(recipientUid);
    }
    return _col(recipientUid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map(
            (d) => NotificationItem.fromFirestore(
              d,
              fallbackUserId: recipientUid,
            ),
          )
          .toList();
      debugPrint(
        '[Inbox] snapshot uid=$recipientUid count=${list.length}',
      );
      return list;
    });
  }

  Future<List<NotificationItem>> fetchInbox(String recipientUid) async {
    if (_useMock) {
      return _mock.listFor(recipientUid);
    }
    try {
      final snap = await _col(recipientUid)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      return snap.docs
          .map(
            (d) => NotificationItem.fromFirestore(
              d,
              fallbackUserId: recipientUid,
            ),
          )
          .toList();
    } on FirebaseException catch (e) {
      debugPrint(
        '[Inbox] ordered fetch FAIL code=${e.code} — try unordered',
      );
      try {
        return await _fetchUnordered(recipientUid);
      } on FirebaseException catch (e2) {
        debugPrint('[Inbox] unordered FAIL code=${e2.code}');
        if (_isEmptyLikeError(e2)) return const [];
        rethrow;
      }
    }
  }

  bool _isEmptyLikeError(FirebaseException e) {
    return e.code == 'not-found' ||
        e.code == 'permission-denied' ||
        e.code == 'failed-precondition';
  }

  Future<List<NotificationItem>> _fetchUnordered(String recipientUid) async {
    final snap = await _col(recipientUid).limit(100).get();
    final list = snap.docs
        .map(
          (d) => NotificationItem.fromFirestore(
            d,
            fallbackUserId: recipientUid,
          ),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> markRead({
    required String recipientUid,
    required Iterable<String> ids,
    required bool isRead,
  }) async {
    final idList = ids.where((e) => e.isNotEmpty).toList();
    if (idList.isEmpty) return;

    if (_useMock) {
      _mock.markRead(
        userId: recipientUid,
        ids: idList,
        isRead: isRead,
      );
      return;
    }

    const chunk = 450;
    for (var i = 0; i < idList.length; i += chunk) {
      final batch = _db.batch();
      final slice = idList.sublist(
        i,
        i + chunk > idList.length ? idList.length : i + chunk,
      );
      for (final id in slice) {
        batch.set(
          _col(recipientUid).doc(id),
          {
            'isRead': isRead,
            'read': isRead,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      debugPrint('[Inbox] markRead count=${slice.length} isRead=$isRead');
    }
  }

  Future<void> deleteMany({
    required String recipientUid,
    required Iterable<String> ids,
  }) async {
    final idList = ids.where((e) => e.isNotEmpty).toList();
    if (idList.isEmpty) return;

    if (_useMock) {
      _mock.deleteMany(userId: recipientUid, ids: idList);
      return;
    }

    const chunk = 450;
    for (var i = 0; i < idList.length; i += chunk) {
      final batch = _db.batch();
      final slice = idList.sublist(
        i,
        i + chunk > idList.length ? idList.length : i + chunk,
      );
      for (final id in slice) {
        batch.delete(_col(recipientUid).doc(id));
      }
      await batch.commit();
      debugPrint('[Inbox] deleteMany count=${slice.length}');
    }
  }
}
