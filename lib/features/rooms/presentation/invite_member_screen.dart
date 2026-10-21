import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_select_chip.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';

/// 목업: 직책 선택 후 초대 코드/링크 생성
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
  RoomInviteModel? _createdInvite;
  bool _submitting = false;

  Future<void> _createInvite() async {
    setState(() {
      _submitting = true;
      _createdInvite = null;
    });

    try {
      final invite = MockStore.instance.createInvite(
        roomId: widget.roomId,
        role: _selectedRole,
        validFor: const Duration(days: 7),
      );
      if (!mounted) return;
      setState(() => _createdInvite = invite);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초대 생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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
    return Scaffold(
      appBar: AppBar(title: Text('${widget.roomName} 초대')),
      body: ScrollablePageBody(
        top: false,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '초대할 직책을 먼저 선택하세요',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '초대 대상이 이 코드로 가입하면, 선택한 직책으로 자동 등록됩니다.',
              style: Theme.of(context).textTheme.bodyMedium,
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
                    onTap: _submitting
                        ? null
                        : () => setState(() {
                              _selectedRole = role;
                              _createdInvite = null;
                            }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _createInvite,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('초대 코드 생성'),
            ),
            if (_createdInvite != null) ...[
              const SizedBox(height: 32),
              const Divider(height: 1),
              const SizedBox(height: 24),
              Text(
                '직책: ${_createdInvite!.role.labelKo}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text('초대 코드', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(
                _createdInvite!.code,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                '초대 링크 (카카오톡·문자 공유용)',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              SelectableText(
                _createdInvite!.inviteLink,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '앱이 있으면 바로 참여 화면으로, 없으면 스토어로 이동합니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        _copy(_createdInvite!.code, '초대 코드'),
                    child: const Text('코드 복사'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        _copy(_createdInvite!.inviteLink, '초대 링크'),
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
