import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'async_action_guard.dart';

/// 클립보드 복사 + 하단 토스트, 시스템 공유 시트
abstract final class ClipboardShare {
  ClipboardShare._();

  static final _copyGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 400),
  );
  static final _shareGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 600),
  );

  /// 클립보드에 복사 후 floating SnackBar
  static Future<void> copy(
    BuildContext context, {
    required String text,
    String message = '초대 코드가 복사되었습니다',
  }) async {
    await _copyGuard.run(() async {
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  /// OS 공유 시트 (카카오톡·메시지 등)
  static Future<void> shareInvite({
    required String roomName,
    required String roleLabel,
    required String code,
    required String inviteLink,
  }) async {
    await _shareGuard.run(() async {
      final body = '$roomName · $roleLabel 초대\n'
          '초대 코드: $code\n'
          '링크: $inviteLink';
      await SharePlus.instance.share(
        ShareParams(
          text: body,
          subject: '$roomName 초대 ($roleLabel)',
        ),
      );
    });
  }
}
