import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/navigation/app_route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_select_chip.dart';
import '../../../../core/widgets/outlined_toggle.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../mock/app_listenables.dart';
import '../../../../mock/mock_session.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../notifications/presentation/notification_inbox_screen.dart';
import '../../../notifications/presentation/push_notification_switch_tile.dart';
import '../../../profile/presentation/account_extras_section.dart';
import '../employee_detail_setting_screen.dart';

/// 사장 전용 매장 설정 — 프로덕션 메뉴 구조
class OwnerStaffSettingsTab extends StatelessWidget {
  const OwnerStaffSettingsTab({
    super.key,
    required this.room,
    this.onOpenStaffList,
  });

  final RoomModel room;

  /// 하단 탭 '직원목록'으로 이동
  final VoidCallback? onOpenStaffList;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppListenables.sessionAndStore,
      builder: (context, _) {
        final live =
            MockStore.instance.rooms[room.id] ?? room;
        final prefs = MockStore.instance.prefsForRoom(live.id);
        final wageFmt = NumberFormat('#,###');

        return ScrollablePageBody(
          top: false,
          bottom: false,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '설정',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                live.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 20),

              // 1. 급여 · 근무 기본값
              _SettingsSection(
                title: '급여 및 근무 기본값',
                children: [
                  _SettingsTile(
                    title: '기본 시급',
                    subtitle: '${wageFmt.format(prefs.defaultHourlyWage)}원',
                    leading: Icons.attach_money_rounded,
                    onTap: () => _editDefaultWage(context, live.id, prefs),
                  ),
                  const Divider(height: 1),
                  _SettingsSwitchTile(
                    title: '주휴수당 계산',
                    subtitle: '법정 주휴수당을 급여 추정에 포함',
                    value: prefs.includeWeeklyHoliday,
                    onChanged: (v) {
                      MockStore.instance.updateRoomOwnerPrefs(
                        live.id,
                        prefs.copyWith(includeWeeklyHoliday: v),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsSwitchTile(
                    title: '야간·연장수당 계산',
                    subtitle: '야간·연장 가산을 급여 추정에 포함',
                    value: prefs.includeOvertimeNight,
                    onChanged: (v) {
                      MockStore.instance.updateRoomOwnerPrefs(
                        live.id,
                        prefs.copyWith(includeOvertimeNight: v),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. 직원 관리 · 초대
              _SettingsSection(
                title: '직원 관리 및 초대',
                children: [
                  _SettingsTile(
                    title: '직원 관리',
                    subtitle: '직원 목록으로 이동',
                    leading: Icons.groups_outlined,
                    onTap: () {
                      if (onOpenStaffList != null) {
                        onOpenStaffList!();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('하단의 직원목록 탭에서 관리할 수 있어요.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  _InviteCodePanel(
                    roomId: live.id,
                    roomName: live.name,
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    title: '직원별 시급·휴게·수당',
                    subtitle: '근무 배정 시 자동으로 불러올 기본값',
                    leading: Icons.payments_outlined,
                    onTap: () => _openStaffContractPicker(context, live),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. 매장 정보
              _SettingsSection(
                title: '매장 정보 관리',
                children: [
                  _SettingsTile(
                    title: '매장명 변경',
                    subtitle: live.name,
                    leading: Icons.storefront_outlined,
                    onTap: () => _renameStore(context, live),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    title: '매장 위치 · 출퇴근 반경',
                    subtitle: _locationSubtitle(live),
                    leading: Icons.location_on_outlined,
                    onTap: () => _editLocationRadius(context, live),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 4. 계정 · 알림
              _SettingsSection(
                title: '계정 및 알림',
                children: [
                  const PushNotificationSwitchTile(
                    dense: true,
                    inCard: false,
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    title: '알림함',
                    subtitle: '받은 알림 확인',
                    leading: Icons.notifications_none_rounded,
                    onTap: () {
                      final uid = MockSession.instance.currentUser?.uid;
                      if (uid == null) return;
                      AppNavigation.pushSingleTop(
                        name: AppRouteNames.inbox,
                        builder: (_) => NotificationInboxScreen(uid: uid),
                      );
                    },
                  ),
                  const AccountExtrasSection(
                    showLegal: false,
                    showSupportEmail: false,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 5. 약관 · 버전
              const _SettingsSection(
                title: '약관 및 정책',
                children: [
                  AccountExtrasSection(
                    showProfileEdit: false,
                    showLogoutDelete: false,
                    showTestAccounts: false,
                    showLegal: true,
                    showLegalSectionLabel: false,
                    showSupportEmail: true,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _locationSubtitle(RoomModel room) {
    final addr = room.location.address?.trim();
    final radius = '${room.geofenceRadiusMeters.toStringAsFixed(0)}m';
    if (addr != null && addr.isNotEmpty) {
      return '$addr · 반경 $radius';
    }
    return '출퇴근 반경 $radius';
  }

  Future<void> _renameStore(BuildContext context, RoomModel room) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _TextInputDialog(
        title: '매장명 변경',
        label: '매장명',
        hint: '매장 이름을 입력하세요',
        initialValue: room.name,
      ),
    );
    if (result == null || result.isEmpty || !context.mounted) return;
    try {
      MockStore.instance.renameRoom(roomId: room.id, name: result);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('매장명이 변경되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editLocationRadius(
    BuildContext context,
    RoomModel room,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _LocationRadiusSheet(room: room),
    );
  }

  Future<void> _openStaffContractPicker(
    BuildContext context,
    RoomModel room,
  ) async {
    final staff = MockStore.instance.activeStaffMembers(room.id);
    if (staff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설정할 직원이 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final selected = await showModalBottomSheet<RoomMemberModel>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '직원 선택',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            for (final m in staff)
              ListTile(
                title: Text(m.displayName),
                subtitle: Text(
                  '시급 ${NumberFormat('#,###').format(m.contract.hourlyWage)}원',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(ctx, m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    await AppNavigation.pushSingleTop(
      name: AppRouteNames.employeeContract(room.id, selected.userId),
      stopAtNames: [AppRouteNames.room(room.id)],
      builder: (_) => EmployeeDetailSettingScreen(
        roomId: room.id,
        member: selected,
      ),
    );
  }

  Future<void> _editDefaultWage(
    BuildContext context,
    String roomId,
    RoomOwnerPrefs prefs,
  ) async {
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _WageInputDialog(
        initialWage: prefs.defaultHourlyWage,
      ),
    );
    if (result == null || !context.mounted) return;
    if (result < AppConstants.minimumHourlyWage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '최저시급(${AppConstants.minimumHourlyWage}원) 이상으로 설정해 주세요.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    MockStore.instance.updateRoomOwnerPrefs(
      roomId,
      prefs.copyWith(defaultHourlyWage: result),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('기본 시급을 저장했습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

}

// -----------------------------------------------------------------------------
// UI building blocks
// -----------------------------------------------------------------------------

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              Icon(leading, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 직책 칩을 누르면 해당 직책 초대 코드로 자동 전환 (직원ABC · 알바X7K1 …)
class _InviteCodePanel extends StatefulWidget {
  const _InviteCodePanel({
    required this.roomId,
    required this.roomName,
  });

  final String roomId;
  final String roomName;

  @override
  State<_InviteCodePanel> createState() => _InviteCodePanelState();
}

class _InviteCodePanelState extends State<_InviteCodePanel> {
  MemberRole _selectedRole = MemberRole.parttime;
  RoomInviteModel? _invite;
  String? _error;

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
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedRole = role;
        _error = '$e';
      });
    }
  }

  Future<void> _copy(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label을(를) 복사했습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final invite = _invite;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '초대 직책',
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '초대 코드',
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        invite?.code ?? (_error ?? '불러오는 중…'),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _selectedRole.labelKo,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentMuted,
                  ),
                ),
              ],
            ),
          ),
          if (invite != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(context, invite.code, '초대 코드'),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('코드 복사'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final msg =
                          '[${widget.roomName}] 초대 코드: ${invite.code}\n${invite.inviteLink}';
                      _copy(context, msg, '카카오톡 공유 문구');
                    },
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('카카오톡 공유'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 컨트롤러를 State 가 소유 — 다이얼로그 닫힌 뒤 IME 가 접근해도 dispose 안전
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.initialValue,
  });

  final String title;
  final String label;
  final String hint;
  final String initialValue;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _WageInputDialog extends StatefulWidget {
  const _WageInputDialog({required this.initialWage});

  final int initialWage;

  @override
  State<_WageInputDialog> createState() => _WageInputDialogState();
}

class _WageInputDialogState extends State<_WageInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialWage.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('기본 시급'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: '시급 (원)',
          hintText: '${AppConstants.minimumHourlyWage}',
          suffixText: '원',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            final v = int.tryParse(_controller.text.trim());
            Navigator.pop(context, v);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _LocationRadiusSheet extends StatefulWidget {
  const _LocationRadiusSheet({required this.room});

  final RoomModel room;

  @override
  State<_LocationRadiusSheet> createState() => _LocationRadiusSheetState();
}

class _LocationRadiusSheetState extends State<_LocationRadiusSheet> {
  static const _radii = [50.0, 100.0, 150.0, 200.0];

  late final TextEditingController _addressController;
  late double _radius;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(
      text: widget.room.location.address ?? '',
    );
    _radius = widget.room.geofenceRadiusMeters;
    if (!_radii.contains(_radius)) {
      _radius = 100;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    try {
      MockStore.instance.updateRoomLocationSettings(
        roomId: widget.room.id,
        address: _addressController.text.trim(),
        geofenceRadiusMeters: _radius,
      );
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('위치·반경을 저장했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '매장 위치 · 출퇴근 반경',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '직원이 이 반경 안에서만 출퇴근할 수 있어요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: '매장 주소',
              hintText: '도로명 또는 건물명',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Text(
            '출퇴근 허용 반경',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final r in _radii) ...[
                if (r != _radii.first) const SizedBox(width: 8),
                Expanded(
                  child: AppSelectChip(
                    label: '${r.toStringAsFixed(0)}m',
                    selected: _radius == r,
                    expand: true,
                    onTap: () => setState(() => _radius = r),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _save,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}
