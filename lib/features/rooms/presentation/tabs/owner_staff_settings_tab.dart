import 'package:flutter/material.dart';

import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/navigation/app_route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_select_chip.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../mock/app_listenables.dart';
import '../../../../mock/mock_session.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../notifications/presentation/notification_inbox_screen.dart';
import '../../../notifications/presentation/push_notification_switch_tile.dart';
import '../../../profile/presentation/account_extras_section.dart';

/// 사장 전용 매장 설정 — 프로덕션 메뉴 구조
class OwnerStaffSettingsTab extends StatelessWidget {
  const OwnerStaffSettingsTab({
    super.key,
    required this.room,
  });

  final RoomModel room;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppListenables.sessionAndStore,
      builder: (context, _) {
        final live =
            MockStore.instance.rooms[room.id] ?? room;

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

              // 1. 매장 정보
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
