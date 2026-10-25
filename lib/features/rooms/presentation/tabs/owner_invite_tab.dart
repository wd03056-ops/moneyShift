import 'package:flutter/material.dart';

import '../../../../core/config/dev_auth_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_action_guard.dart';
import '../../../../core/utils/clipboard_share.dart';
import '../../../../core/widgets/app_select_chip.dart';
import '../../../../core/widgets/app_text_input_defaults.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../mock/app_listenables.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../../services/room_invite_service.dart';

/// 사장 탭 — 초대하기 (직책 칩 + 커스텀 직책 추가)
class OwnerInviteTab extends StatefulWidget {
  const OwnerInviteTab({
    super.key,
    required this.room,
  });

  final RoomModel room;

  @override
  State<OwnerInviteTab> createState() => _OwnerInviteTabState();
}

class _OwnerInviteTabState extends State<OwnerInviteTab> {
  MemberRole _selectedRole = MemberRole.parttime;
  String? _selectedCustomRoleId;
  RoomInviteModel? _invite;
  List<RoomCustomRoleModel> _customRoles = const [];
  bool _busy = false;

  final _roleGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 250),
  );
  final _createGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 600),
  );
  final _deleteGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 600),
  );
  final _bootstrapGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 800),
  );
  final _inviteService = RoomInviteService();

  bool get _useMock => DevAuthConfig.isMockAuthEnabled;

  @override
  void initState() {
    super.initState();
    if (_useMock) {
      AppListenables.sessionAndStore.addListener(_onStoreChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  @override
  void didUpdateWidget(covariant OwnerInviteTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _bootstrap();
      });
    }
  }

  @override
  void dispose() {
    if (_useMock) {
      AppListenables.sessionAndStore.removeListener(_onStoreChanged);
    }
    super.dispose();
  }

  void _onStoreChanged() {
    _refreshCustomRoles();
  }

  Future<void> _bootstrap() async {
    await _bootstrapGuard.run(() async {
      try {
        await _inviteService.ensureDefaultRoleInvites(roomId: widget.room.id);
      } catch (_) {}
      if (!mounted) return;
      await _refreshCustomRoles();
      if (!mounted) return;
      await _selectDefaultRole(_selectedRole);
    });
  }

  Future<void> _refreshCustomRoles() async {
    try {
      final list = await _inviteService.listCustomRoles(widget.room.id);
      if (!mounted) return;
      setState(() => _customRoles = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _customRoles = const []);
    }
  }

  Future<void> _selectDefaultRole(MemberRole role) async {
    if (!_roleGuard.tryLock()) return;
    setState(() => _busy = true);
    try {
      final invite = await _inviteService.ensureInviteForRole(
        roomId: widget.room.id,
        role: role,
      );
      if (!mounted) return;
      setState(() {
        _selectedRole = role;
        _selectedCustomRoleId = null;
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

  Future<void> _selectCustomRole(RoomCustomRoleModel role) async {
    if (!_roleGuard.tryLock()) return;
    setState(() => _busy = true);
    try {
      final invite = await _inviteService.getInvite(role.inviteId);
      if (invite == null || !invite.canBeUsed) {
        throw StateError('이 직책의 초대 코드를 찾을 수 없습니다.');
      }
      if (!mounted) return;
      setState(() {
        _selectedCustomRoleId = role.id;
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

  Future<void> _showCreateCustomRoleDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _CreateRoleNameDialog(),
    );
    if (name == null || !mounted) return;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _createCustomRole(name);
  }

  Future<void> _createCustomRole(String name) async {
    await _createGuard.run(() async {
      setState(() => _busy = true);
      try {
        final role = await _inviteService.createCustomRoleWithInvite(
          roomId: widget.room.id,
          roleName: name,
          baseRole: MemberRole.staff,
        );
        if (!mounted) return;
        final invite = await _inviteService.getInvite(role.inviteId);
        if (!mounted) return;
        if (!_useMock) await _refreshCustomRoles();
        if (!mounted) return;
        setState(() {
          _selectedCustomRoleId = role.id;
          _invite = invite;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${role.name} 직책이 생성되었습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.holiday,
          ),
        );
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    });
  }

  Future<void> _copyCode(String code) => ClipboardShare.copy(
        context,
        text: code,
        message: '초대 코드가 복사되었습니다',
      );

  Future<void> _copyLink(String link) => ClipboardShare.copy(
        context,
        text: link,
        message: '초대 링크가 복사되었습니다',
      );

  Future<void> _share(RoomInviteModel invite) {
    final live = _useMock
        ? (MockStore.instance.rooms[widget.room.id] ?? widget.room)
        : widget.room;
    return ClipboardShare.shareInvite(
      roomName: live.name,
      roleLabel: invite.roleLabel,
      code: invite.code,
      inviteLink: invite.inviteLink,
    );
  }

  Future<void> _confirmDeleteCustomRole(RoomCustomRoleModel role) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('직책 삭제'),
        content: Text(
          '"${role.name}" 직책을 삭제할까요?\n\n'
          '· 초대 코드(${role.inviteCode})는 즉시 무효화됩니다.\n'
          '· 이미 이 직책으로 가입한 직원은 '
          '권한(${role.baseRole.labelKo})은 유지되고 '
          '표시 직책만 기본 명칭으로 바뀝니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '삭제',
              style: TextStyle(color: AppColors.holiday),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await _deleteGuard.run(() async {
      setState(() => _busy = true);
      try {
        await _inviteService.deleteCustomRole(
          roomId: widget.room.id,
          roleId: role.id,
        );
        if (!mounted) return;
        if (!_useMock) await _refreshCustomRoles();
        if (!mounted) return;
        await _selectDefaultRole(MemberRole.parttime);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${role.name} 직책을 삭제했습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.holiday,
          ),
        );
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    final textTheme = Theme.of(context).textTheme;
    final live = _useMock
        ? (MockStore.instance.rooms[widget.room.id] ?? widget.room)
        : widget.room;
    final customRoles = _useMock
        ? MockStore.instance.customRolesForRoom(live.id)
        : _customRoles;
    RoomCustomRoleModel? selectedCustom;
    if (_selectedCustomRoleId != null) {
      for (final r in customRoles) {
        if (r.id == _selectedCustomRoleId) {
          selectedCustom = r;
          break;
        }
      }
    }

    return ScrollablePageBody(
      top: false,
      bottom: false,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('초대하기', style: textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            live.name,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '기본 직책 초대',
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '직책을 누르면 초대 코드가 바뀝니다. '
            '+ 로 새 직책을 만들 수 있습니다.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final role in MemberRole.invitableRoles)
                AppSelectChip(
                  label: role.labelKo,
                  selected: _selectedCustomRoleId == null &&
                      _selectedRole == role,
                  onTap: _busy ? null : () => _selectDefaultRole(role),
                ),
              for (final role in customRoles)
                AppSelectChip(
                  label: role.name,
                  selected: _selectedCustomRoleId == role.id,
                  onTap: _busy ? null : () => _selectCustomRole(role),
                ),
              _AddRoleChip(
                onTap: _busy ? () {} : _showCreateCustomRoleDialog,
              ),
            ],
          ),
          if (invite != null) ...[
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '직책: ${invite.roleLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                ),
                if (selectedCustom != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _confirmDeleteCustomRole(selectedCustom!),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.holiday,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('직책 삭제'),
                  ),
              ],
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _copyCode(invite.code),
                  child: const Text('코드 복사'),
                ),
                OutlinedButton(
                  onPressed: () => _copyLink(invite.inviteLink),
                  child: const Text('링크 복사'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _share(invite),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('공유'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 다이얼로그가 컨트롤러를 소유·해제 (닫힌 뒤 dispose 사용 방지)
class _CreateRoleNameDialog extends StatefulWidget {
  const _CreateRoleNameDialog();

  @override
  State<_CreateRoleNameDialog> createState() => _CreateRoleNameDialogState();
}

class _CreateRoleNameDialogState extends State<_CreateRoleNameDialog> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _nameCtrl.text.trim();
    if (t.length < 2) return;
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('직책 추가'),
      content: AppElevatedInputShell(
        child: TextField(
          controller: _nameCtrl,
          autofocus: true,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.text,
          autocorrect: AppTextInputDefaults.autocorrect,
          enableSuggestions: AppTextInputDefaults.enableSuggestions,
          spellCheckConfiguration:
              AppTextInputDefaults.spellCheckConfiguration,
          smartDashesType: AppTextInputDefaults.smartDashesType,
          smartQuotesType: AppTextInputDefaults.smartQuotesType,
          style: const TextStyle(decoration: TextDecoration.none),
          decoration: AppTextInputDefaults.decoration(
            labelText: '직책 이름',
            hintText: '예: 부점장, 야간 매니저',
          ).copyWith(counterText: ''),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('만들기'),
        ),
      ],
    );
  }
}

class _AddRoleChip extends StatelessWidget {
  const _AddRoleChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 22,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
