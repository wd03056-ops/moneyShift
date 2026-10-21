import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/outlined_toggle.dart';
import '../../../mock/mock_session.dart';
import '../data/notification_preference_store.dart';

/// [푸시 알림 허용] 토글 — 내정보 / 매장 설정 공통
class PushNotificationSwitchTile extends StatefulWidget {
  const PushNotificationSwitchTile({
    super.key,
    this.dense = false,
    this.inCard = true,
  });

  final bool dense;
  final bool inCard;

  @override
  State<PushNotificationSwitchTile> createState() =>
      _PushNotificationSwitchTileState();
}

class _PushNotificationSwitchTileState
    extends State<PushNotificationSwitchTile> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    NotificationPreferenceStore.instance.ensureLoaded();
  }

  Future<void> _onChanged(String uid, bool wantEnabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await NotificationPreferenceStore.instance.setEnabled(
      uid,
      wantEnabled,
    );
    if (!mounted) return;
    setState(() => _busy = false);
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
        final enabled = uid == null
            ? true
            : NotificationPreferenceStore.instance.isEnabled(uid);
        final textTheme = Theme.of(context).textTheme;

        final tile = Padding(
          padding: widget.dense
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '푸시 알림 허용',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      enabled
                          ? '근무·출퇴근·공지 알림을 받습니다'
                          : '알림이 꺼져 있습니다 (근무 배정·결근은 예외)',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedToggle(
                value: enabled,
                onChanged: (uid == null || _busy)
                    ? null
                    : (v) => _onChanged(uid, v),
              ),
            ],
          ),
        );

        if (!widget.inCard) return tile;
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: tile,
        );
      },
    );
  }
}
