import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/navigation/app_route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/widgets/app_select_chip.dart';
import '../../../../core/widgets/outlined_toggle.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../mock/app_listenables.dart';
import '../../../../mock/mock_session.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../notifications/presentation/notification_inbox_screen.dart';
import '../../../notifications/presentation/push_notification_switch_tile.dart';
import '../../../profile/presentation/edit_profile_screen.dart';
import '../employee_detail_setting_screen.dart';
import '../invite_member_screen.dart';

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
        final invites =
            MockStore.instance.activeInvitesForRoom(live.id);
        final wageFmt = NumberFormat('#,###');

        return ScrollablePageBody(
          top: false,
          bottom: false,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '설정',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '매장·직원·급여·계정',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 20),

              _SettingsSection(
                title: '매장 정보 관리',
                children: [
                  _SettingsTile(
                    title: '매장명 변경',
                    subtitle: live.name,
                    onTap: () => _renameStore(context, live),
                  ),
                  _SettingsTile(
                    title: '매장 위치 · 출퇴근 반경',
                    subtitle: _locationSubtitle(live),
                    onTap: () => _editLocationRadius(context, live),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _SettingsSection(
                title: '직원 초대 및 관리',
                children: [
                  _SettingsTile(
                    title: '알바생 초대',
                    subtitle: invites.isEmpty
                        ? '초대 코드 생성 · 공유'
                        : '활성 코드 ${invites.length}개',
                    onTap: () => _openInvite(context, live),
                  ),
                  if (invites.isNotEmpty)
                    _InviteQuickActions(
                      invite: invites.first,
                      roomName: live.name,
                    ),
                  _SettingsTile(
                    title: '직원 관리',
                    subtitle: '직원 목록으로 이동',
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
                  _SettingsTile(
                    title: '직원별 시급·휴게·수당',
                    subtitle: '근무 배정 시 자동으로 불러올 기본값',
                    onTap: () => _openStaffContractPicker(context, live),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _SettingsSection(
                title: '근무 및 급여 기본값',
                children: [
                  _SettingsTile(
                    title: '기본 시급',
                    subtitle: '${wageFmt.format(prefs.defaultHourlyWage)}원',
                    onTap: () => _editDefaultWage(context, live.id, prefs),
                  ),
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
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _SettingsSection(
                title: '앱 및 계정 설정',
                children: [
                  const PushNotificationSwitchTile(
                    dense: true,
                    inCard: false,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _SettingsSwitchTile(
                    title: '근무 변경 알림',
                    subtitle: '배정·교대·변경 요청 푸시 (매장)',
                    value: prefs.notifyScheduleChanges,
                    onChanged: (v) {
                      MockStore.instance.updateRoomOwnerPrefs(
                        live.id,
                        prefs.copyWith(notifyScheduleChanges: v),
                      );
                    },
                  ),
                  _SettingsSwitchTile(
                    title: '출퇴근 알림',
                    subtitle: '직원 출퇴근·근태 관련 알림 (매장)',
                    value: prefs.notifyAttendance,
                    onChanged: (v) {
                      MockStore.instance.updateRoomOwnerPrefs(
                        live.id,
                        prefs.copyWith(notifyAttendance: v),
                      );
                    },
                  ),
                  _SettingsTile(
                    title: '알림함',
                    subtitle: '받은 알림 확인',
                    onTap: () {
                      final uid = MockSession.instance.currentUser?.uid;
                      if (uid == null) return;
                      AppNavigation.pushSingleTop(
                        name: AppRouteNames.inbox,
                        builder: (_) => NotificationInboxScreen(uid: uid),
                      );
                    },
                  ),
                  _SettingsTile(
                    title: '실명 · 프로필 수정',
                    subtitle: MockSession
                            .instance.currentUser?.preferredDisplayName ??
                        '프로필',
                    onTap: () {
                      AppNavigation.pushSingleTop(
                        name: AppRouteNames.editProfile,
                        builder: (_) => const EditProfileScreen(),
                      );
                    },
                  ),
                  _SettingsTile(
                    title: '로그아웃',
                    titleColor: AppColors.textPrimary,
                    onTap: () => _confirmLogout(context),
                  ),
                  _SettingsTile(
                    title: '회원탈퇴',
                    titleColor: AppColors.holiday,
                    onTap: () => _confirmDeleteAccount(context),
                    showDivider: false,
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

  Future<void> _openInvite(BuildContext context, RoomModel room) async {
    await AppNavigation.pushSingleTop(
      name: AppRouteNames.invite(room.id),
      stopAtNames: [AppRouteNames.room(room.id)],
      builder: (_) => InviteMemberScreen(
        roomId: room.id,
        roomName: room.name,
      ),
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

  void _safeSignOut(BuildContext context, {required VoidCallback action}) {
    // 1) 네비 스택을 홈까지 비운 뒤 2) 다음 프레임에 세션 해제
    // (IME/다이얼로그 dispose 중 InheritedWidget dependents 깨짐 방지)
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      action();
    });
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('로그아웃'),
        content: const Text('이 계정에서 로그아웃할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    _safeSignOut(context, action: MockSession.instance.logout);
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('회원탈퇴'),
        content: const Text(
          '계정을 삭제하면 매장·근무·출퇴근 기록이 삭제되며 복구할 수 없습니다.\n\n'
          '계속하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '탈퇴',
              style: TextStyle(color: AppColors.holiday),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    _safeSignOut(context, action: MockSession.instance.deleteAccount);
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
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textCaption,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        DecoratedBox(
          decoration: AppDecorations.borderedSurface(radius: 14),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.onTap,
    this.titleColor,
    this.showDivider = true,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: titleColor ?? AppColors.textPrimary,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedToggle(value: value, onChanged: onChanged),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

class _InviteQuickActions extends StatelessWidget {
  const _InviteQuickActions({
    required this.invite,
    required this.roomName,
  });

  final RoomInviteModel invite;
  final String roomName;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                        '활성 초대 코드',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        invite.code,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  invite.role.labelKo,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentMuted,
                      ),
                ),
              ],
            ),
          ),
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
                        '[$roomName] 초대 코드: ${invite.code}\n${invite.inviteLink}';
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
          const Divider(height: 20),
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
