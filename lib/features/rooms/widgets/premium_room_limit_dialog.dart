import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/room_exceptions.dart';

/// 무료 방 한도(2개) 초과 시 유료 결제 유도 분기용 다이얼로그
class PremiumRoomLimitDialog extends StatelessWidget {
  const PremiumRoomLimitDialog({
    super.key,
    required this.exception,
    this.onUpgradePressed,
  });

  final RoomLimitExceededException exception;
  final VoidCallback? onUpgradePressed;

  static Future<void> show(
    BuildContext context, {
    required RoomLimitExceededException exception,
    VoidCallback? onUpgradePressed,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => PremiumRoomLimitDialog(
        exception: exception,
        onUpgradePressed: onUpgradePressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('방 생성 한도 초과'),
      content: Text(
        '무료 플랜에서는 매장을 최대 ${AppConstants.freeMaxOwnedRooms}개까지 '
        '만들 수 있습니다.\n'
        '현재 ${exception.currentCount}개를 사용 중입니다.\n\n'
        '3개 이상 매장을 운영하려면 유료 플랜으로 업그레이드해주세요.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            // 결제/업그레이드 화면으로 분기하는 확장 포인트
            onUpgradePressed?.call();
          },
          child: const Text('유료 플랜 보기'),
        ),
      ],
    );
  }
}
