import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/config/dev_auth_config.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../mock/app_listenables.dart';
import '../../../mock/mock_session.dart';
import '../../../models/notification_item.dart';
import '../data/mock_notification_repository.dart';
import 'notification_inbox_screen.dart';

/// AppBar / 홈용 알림 벨 + 미읽음 빨간 배지
///
/// Mock: [MockSession] + [MockNotificationRepository] (계정 전환 즉시 반영)
/// 실서비스: `users/{uid}/notifications` Firestore 스트림
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    super.key,
    this.iconColor = AppColors.primary,
  });

  final Color iconColor;

  void _openInbox(BuildContext context, String uid) {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.inbox,
      builder: (_) => NotificationInboxScreen(uid: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (DevAuthConfig.isMockAuthEnabled) {
      // Mock: 세션·인메모리 알림 저장소 구독 (계정 전환 즉시 반영)
      return ListenableBuilder(
        listenable: AppListenables.sessionAndNotifications,
        builder: (context, _) {
          final uid = MockSession.instance.currentUser?.uid;
          if (uid == null) {
            return IconButton(
              tooltip: '알림함',
              onPressed: null,
              icon: Icon(Icons.notifications_outlined, color: iconColor),
            );
          }
          final unread =
              MockNotificationRepository.instance.unreadCount(uid);
          return _BellIcon(
            iconColor: iconColor,
            unread: unread,
            onPressed: () => _openInbox(context, uid),
          );
        },
      );
    }

    final uid = MockSession.instance.currentUser?.uid;
    if (uid == null) {
      return IconButton(
        tooltip: '알림함',
        onPressed: null,
        icon: Icon(Icons.notifications_outlined, color: iconColor),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestorePaths.userNotifications(uid))
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        var unread = 0;
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final item = NotificationItem.fromFirestore(
              doc,
              fallbackUserId: uid,
            );
            if (!item.isRead) unread++;
          }
        }
        return _BellIcon(
          iconColor: iconColor,
          unread: unread,
          onPressed: () => _openInbox(context, uid),
        );
      },
    );
  }
}

class _BellIcon extends StatelessWidget {
  const _BellIcon({
    required this.iconColor,
    required this.unread,
    required this.onPressed,
  });

  final Color iconColor;
  final int unread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '알림함',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.holiday,
        textColor: Colors.white,
        label: Text(
          unread > 9 ? '9+' : '$unread',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        child: Icon(
          Icons.notifications_outlined,
          color: iconColor,
        ),
      ),
    );
  }
}
