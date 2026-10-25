import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/async_action_guard.dart';
import '../../../core/utils/clipboard_share.dart';
import '../../../core/widgets/app_select_chip.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../models/models.dart';
import '../../../services/room_invite_service.dart';

/// 직책 선택 시 초대 코드가 자동으로 바뀜
class InviteMemberScreen extends StatefulWidget {
  const InviteMemberScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  final String roomId;
  final String roomName;

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  MemberRole _selectedRole = MemberRole.parttime;
  RoomInviteModel? _invite;
  bool _busy = false;
  final _roleGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 250),
  );
  final _bootstrapGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 800),
  );
  final _inviteService = RoomInviteService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    await _bootstrapGuard.run(() async {
      try {
        await _inviteService.ensureDefaultRoleInvites(roomId: widget.roomId);
      } catch (_) {}
      if (!mounted) return;
      await _selectRole(_selectedRole);
    });
  }

  Future<void> _selectRole(MemberRole role) async {
    if (!_roleGuard.tryLock()) return;
    setState(() => _busy = true);
    try {
      final invite = await _inviteService.ensureInviteForRole(
        roomId: widget.roomId,
        role: role,
      );
      if (!mounted) return;
      setState(() {
        _selectedRole = role;
        _invite = invite;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('초대 불러오기 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _roleGuard.unlock();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.roomName} 초대')),
      body: ScrollablePageBody(
        top: false,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '초대할 직책을 선택하세요',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '직책을 누르면 초대 코드가 자동으로 바뀝니다. '
              '이 코드로 가입하면 해당 직책으로 등록됩니다.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final role in MemberRole.invitableRoles)
                  AppSelectChip(
                    label: role.labelKo,
                    selected: _selectedRole == role,
                    onTap: _busy ? null : () => _selectRole(role),
                  ),
              ],
            ),
            if (invite != null) ...[
              const SizedBox(height: 28),
              const Divider(height: 1),
              const SizedBox(height: 20),
              Text(
                '직책: ${invite.role.labelKo}',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text('초대 코드', style: textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(
                invite.code,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '초대 링크 (카카오톡·문자 공유용)',
                style: textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              SelectableText(
                invite.inviteLink,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '앱이 있으면 바로 참여 화면으로, 없으면 스토어로 이동합니다.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => ClipboardShare.copy(
                      context,
                      text: invite.code,
                      message: '초대 코드가 복사되었습니다',
                    ),
                    child: const Text('코드 복사'),
                  ),
                  OutlinedButton(
                    onPressed: () => ClipboardShare.copy(
                      context,
                      text: invite.inviteLink,
                      message: '초대 링크가 복사되었습니다',
                    ),
                    child: const Text('링크 복사'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ClipboardShare.shareInvite(
                      roomName: widget.roomName,
                      roleLabel: invite.role.labelKo,
                      code: invite.code,
                      inviteLink: invite.inviteLink,
                    ),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('공유'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
