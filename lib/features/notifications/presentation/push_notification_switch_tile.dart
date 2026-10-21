import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/outlined_toggle.dart';
import '../../../mock/mock_session.dart';
import '../data/notification_preference_store.dart';

IconData _categoryIcon(NotificationCategory category) {
  switch (category) {
    case NotificationCategory.schedule:
      return Icons.event_note_outlined;
    case NotificationCategory.commute:
      return Icons.directions_walk_outlined;
    case NotificationCategory.notice:
      return Icons.campaign_outlined;
  }
}

/// 근무 / 출퇴근 / 공지 알림을 각각 켜고 끄는 설정 블록
///
/// 사장 설정·직원 급여·정보·내정보에서 동일 UI로 사용합니다.
class PushNotificationSwitchTile extends StatefulWidget {
  const PushNotificationSwitchTile({
    super.key,
    this.dense = false,
    this.inCard = true,
    this.showLeading = true,
  });

  final bool dense;
  final bool inCard;

  /// 카테고리별 leading 아이콘 표시
  final bool showLeading;

  @override
  State<PushNotificationSwitchTile> createState() =>
      _PushNotificationSwitchTileState();
}

class _PushNotificationSwitchTileState
    extends State<PushNotificationSwitchTile> {
  NotificationCategory? _busyCat;

  @override
  void initState() {
    super.initState();
    NotificationPreferenceStore.instance.ensureLoaded();
  }

  Future<void> _onChanged(
    String uid,
    NotificationCategory category,
    bool wantEnabled,
  ) async {
    if (_busyCat != null) return;
    setState(() => _busyCat = category);
    final ok = await NotificationPreferenceStore.instance.setCategoryEnabled(
      userId: uid,
      category: category,
      enabled: wantEnabled,
    );
    if (!mounted) return;
    setState(() => _busyCat = null);
    if (wantEnabled && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('시스템 알림 권한이 없어 푸시를 켤 수 없습니다. 설정에서 허용해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MockSession.instance,
        NotificationPreferenceStore.instance,
      ]),
      builder: (context, _) {
        final uid = MockSession.instance.currentUser?.uid;

        final tiles = <Widget>[];
        for (var i = 0; i < NotificationCategory.values.length; i++) {
          final cat = NotificationCategory.values[i];
          final enabled = uid == null
              ? true
              : NotificationPreferenceStore.instance
                  .isCategoryEnabled(uid, cat);
          final busy = _busyCat == cat;

          tiles.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showLeading) ...[
                    Icon(
                      _categoryIcon(cat),
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.titleKo,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cat.subtitleKo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedToggle(
                    value: enabled,
                    onChanged: (uid == null || busy)
                        ? null
                        : (v) => _onChanged(uid, cat, v),
                  ),
                ],
              ),
            ),
          );
          if (i < NotificationCategory.values.length - 1) {
            tiles.add(const Divider(height: 1));
          }
        }

        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: tiles,
        );

        if (!widget.inCard) return column;
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: column,
        );
      },
    );
  }
}
