import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_select_chip.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';

/// 직책 선택 시 초대 코드가 자동으로 바뀜 (직원ABC · 알바X7K1 …)
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _selectRole(_selectedRole);
    });
  }

  void _selectRole(MemberRole role) {
    try {
      final invite = MockStore.instance.ensureInviteForRole(
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
        SnackBar(content: Text('초대 불러오기 실패: $e')),
      );
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label을(를) 복사했습니다.')),
    );
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
                    onTap: () => _selectRole(role),
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
                    onPressed: () => _copy(invite.code, '초대 코드'),
                    child: const Text('코드 복사'),
                  ),
                  OutlinedButton(
                    onPressed: () => _copy(invite.inviteLink, '초대 링크'),
                    child: const Text('링크 복사'),
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
