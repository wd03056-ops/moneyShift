import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/async_action_guard.dart';
import '../../../../core/widgets/app_select_chip.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../mock/app_listenables.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../../services/kakao_local_api.dart';
import '../../../notifications/presentation/push_notification_switch_tile.dart';
import '../../../profile/presentation/account_extras_section.dart';
import '../widgets/daum_postcode_sheet.dart';

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

              // 계정 · 알림
              _SettingsSection(
                title: '계정 및 알림',
                children: [
                  const PushNotificationSwitchTile(
                    dense: true,
                    inCard: false,
                  ),
                  const AccountExtrasSection(
                    showLegal: false,
                    showLogoutDelete: false,
                    showSupportEmail: false,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 5. 약관 · 버전 · 로그아웃/회원탈퇴
              const _SettingsSection(
                title: '약관 및 정책',
                children: [
                  AccountExtrasSection(
                    showProfileEdit: false,
                    showLogoutDelete: true,
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
              Icon(leading, color: AppColors.textPrimary, size: 24),
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
        autocorrect: false,
        enableSuggestions: false,
        spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        style: const TextStyle(decoration: TextDecoration.none),
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
  late final KakaoLocalApi _kakaoApi;
  final _saveGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 600),
  );
  final _postcodeGuard = AsyncActionGuard(
    cooldown: const Duration(milliseconds: 500),
  );

  late String _displayAddress;
  late double _latitude;
  late double _longitude;
  late double _radius;
  bool _resolving = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _kakaoApi = KakaoLocalApi();
    _displayAddress = widget.room.location.address?.trim() ?? '';
    _addressController = TextEditingController(text: _displayAddress);
    _latitude = widget.room.location.latitude;
    _longitude = widget.room.location.longitude;
    _radius = widget.room.geofenceRadiusMeters;
    if (!_radii.contains(_radius)) {
      _radius = 100;
    }
  }

  @override
  void dispose() {
    _kakaoApi.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _openPostcodeSearch() async {
    await _postcodeGuard.run(() async {
      final result = await showDaumPostcodeSheet(context);
      if (!mounted || result == null) return;
      setState(() {
        _resolving = true;
        _displayAddress = result.displayLabel;
        _addressController.text = result.displayLabel;
      });
      try {
        final lat = result.latitude;
        final lng = result.longitude;
        if (lat != null && lng != null) {
          if (!mounted) return;
          setState(() {
            _latitude = lat;
            _longitude = lng;
          });
        } else {
          final place = await _geocode(result.geocodeQuery);
          if (!mounted) return;
          if (place != null) {
            setState(() {
              _latitude = place.latitude;
              _longitude = place.longitude;
            });
          }
        }
      } catch (_) {
        // 좌표 실패해도 주소 문자열은 유지
      } finally {
        if (mounted) setState(() => _resolving = false);
      }
    });
  }

  Future<KakaoPlaceResult?> _geocode(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    var results = await _kakaoApi.searchAddress(trimmed);
    if (results.isEmpty) {
      results = await _kakaoApi.searchKeyword(trimmed);
    }
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<void> _save() async {
    if (_saving) return;
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('주소 검색으로 매장 주소를 선택해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _saveGuard.run(() async {
      if (!mounted) return;
      setState(() => _saving = true);
      try {
        MockStore.instance.updateRoomLocationSettings(
          roomId: widget.room.id,
          address: address,
          latitude: _latitude,
          longitude: _longitude,
          geofenceRadiusMeters: _radius,
        );
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('위치·반경을 저장했습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final textTheme = Theme.of(context).textTheme;
    final busy = _resolving || _saving;

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
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '직원이 이 반경 안에서만 출퇴근할 수 있어요.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '매장 주소',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: busy ? null : _openPostcodeSearch,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('주소 검색'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _addressController,
            readOnly: true,
            showCursor: false,
            enableInteractiveSelection: false,
            style: const TextStyle(
              decoration: TextDecoration.none,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: _displayAddress.isEmpty
                  ? '주소 검색으로 선택하세요'
                  : null,
            ),
            maxLines: 2,
            onTap: busy ? null : _openPostcodeSearch,
          ),
          if (_resolving) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 16),
          Text(
            '출퇴근 허용 반경',
            style: textTheme.labelLarge?.copyWith(
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
                    onTap: busy ? null : () => setState(() => _radius = r),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: busy ? null : _save,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}
