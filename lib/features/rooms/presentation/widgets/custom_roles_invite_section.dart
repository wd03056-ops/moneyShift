import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/dev_auth_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_action_guard.dart';
import '../../../../core/utils/clipboard_share.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_select_chip.dart';
import '../../../../core/widgets/sticky_action_button.dart';
import '../../../../mock/app_listenables.dart';
import '../../../../models/models.dart';
import '../../../../services/room_invite_service.dart';

/// 사장 설정 — 커스텀 직책 추가 + 전역 유일 초대 코드 발급 (Firestore 연동)
class CustomRolesInviteSection extends StatefulWidget {
  const CustomRolesInviteSection({
    super.key,
    required this.roomId,
    this.roomName,
  });

  final String roomId;
  final String? roomName;

  @override
  State<CustomRolesInviteSection> createState() =>
      _CustomRolesInviteSectionState();
}

class _CustomRolesInviteSectionState extends State<CustomRolesInviteSection> {
  final _nameCtrl = TextEditingController();
  final _createGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 600),
  );
  final _deleteGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 600),
  );
  final _inviteService = RoomInviteService();
  MemberRole _baseRole = MemberRole.staff;
  bool _creating = false;
  bool _deleting = false;
  bool _loading = true;
  List<RoomCustomRoleModel> _roles = const [];

  bool get _useMock => DevAuthConfig.isMockAuthEnabled;

  @override
  void initState() {
    super.initState();
    if (_useMock) {
      AppListenables.sessionAndStore.addListener(_onStoreChanged);
    }
    _reloadRoles();
  }

  @override
  void didUpdateWidget(covariant CustomRolesInviteSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _reloadRoles();
    }
  }

  @override
  void dispose() {
    if (_useMock) {
      AppListenables.sessionAndStore.removeListener(_onStoreChanged);
    }
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    _reloadRoles();
  }

  Future<void> _reloadRoles() async {
    if (mounted) setState(() => _loading = true);
    try {
      final list = await _inviteService.listCustomRoles(widget.roomId);
      if (!mounted) return;
      setState(() {
        _roles = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _roles = const [];
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    if (_creating) return;
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('직책명을 2자 이상 입력해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _createGuard.run(() async {
      if (!mounted) return;
      setState(() => _creating = true);
      try {
        final role = await _inviteService.createCustomRoleWithInvite(
          roomId: widget.roomId,
          roleName: name,
          baseRole: _baseRole,
        );
        if (!mounted) return;
        _nameCtrl.clear();
        if (!_useMock) await _reloadRoles();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${role.name} 직책이 생성되었습니다. 코드 ${role.inviteCode}',
            ),
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
        if (mounted) setState(() => _creating = false);
      }
    });
  }

  Future<void> _copyCode(String code) async {
    await ClipboardShare.copy(
      context,
      text: code,
      message: '초대 코드가 복사되었습니다',
    );
  }

  Future<void> _share(RoomCustomRoleModel role) {
    return ClipboardShare.shareInvite(
      roomName: widget.roomName?.trim().isNotEmpty == true
          ? widget.roomName!.trim()
          : '매장',
      roleLabel: role.name,
      code: role.inviteCode,
      inviteLink: RoomInviteModel(
        id: role.inviteId,
        roomId: role.roomId,
        code: role.inviteCode,
        role: role.baseRole,
        createdBy: role.createdBy,
        customRoleName: role.name,
        customRoleId: role.id,
      ).inviteLink,
    );
  }

  Future<void> _delete(RoomCustomRoleModel role) async {
    if (_deleting) return;
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
      if (!mounted) return;
      setState(() => _deleting = true);
      try {
        await _inviteService.deleteCustomRole(
          roomId: widget.roomId,
          roleId: role.id,
        );
        if (!mounted) return;
        if (!_useMock) await _reloadRoles();
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
        if (mounted) setState(() => _deleting = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final roles = _roles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '직책 추가 및 초대 코드 생성',
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '직책명을 만들면 전역 유일 초대 코드가 발급됩니다. '
          '직원이 이 코드로 가입하면 해당 직책으로 등록됩니다.',
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        AppBorderedField(
          height: 48,
          child: AppPlainTextField(
            controller: _nameCtrl,
            enabled: !_creating,
            hintText: '예: 부점장, 야간 매니저',
            style: textTheme.bodyLarge,
            hintStyle: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            inputFormatters: [
              LengthLimitingTextInputFormatter(20),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '권한 기준',
          style: textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in MemberRole.invitableRoles)
              AppSelectChip(
                label: role.labelKo,
                selected: _baseRole == role,
                onTap: _creating
                    ? null
                    : () => setState(() => _baseRole = role),
              ),
          ],
        ),
        const SizedBox(height: 12),
        StickyActionButton(
          label: '직책 생성 · 코드 발급',
          variant: StickyActionVariant.filled,
          onPressed: _creating ? null : _create,
          isLoading: _creating,
        ),
        if (_loading) ...[
          const SizedBox(height: 16),
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ] else if (roles.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final role in roles) ...[
            _CustomRoleTile(
              role: role,
              onCopy: _deleting ? null : () => _copyCode(role.inviteCode),
              onShare: _deleting ? null : () => _share(role),
              onDelete: _deleting ? null : () => _delete(role),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _CustomRoleTile extends StatelessWidget {
  const _CustomRoleTile({
    required this.role,
    required this.onCopy,
    required this.onShare,
    required this.onDelete,
  });

  final RoomCustomRoleModel role;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '권한 ${role.baseRole.labelKo} · 코드 ${role.inviteCode}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '코드 복사',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 20),
            color: AppColors.primary,
          ),
          IconButton(
            tooltip: '공유',
            onPressed: onShare,
            icon: const Icon(Icons.share_rounded, size: 20),
            color: AppColors.primary,
          ),
          IconButton(
            tooltip: '삭제',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppColors.holiday,
          ),
        ],
      ),
    );
  }
}
