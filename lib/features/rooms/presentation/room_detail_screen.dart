import 'package:flutter/material.dart';

import '../../../core/navigation/room_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';
import '../../notifications/presentation/notification_bell_button.dart';
import '../widgets/room_role_badge.dart';
import 'tabs/owner_home_tab.dart';
import 'tabs/owner_schedule_tab.dart';
import 'tabs/owner_staff_settings_tab.dart';
import 'tabs/staff_attendance_tab.dart';
import 'tabs/staff_payroll_tab.dart';
import 'tabs/staff_schedule_tab.dart';

/// 방 상세 — 역할에 따라 완전히 다른 하단 NavigationBar 장착
class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({
    super.key,
    required this.roomId,
    this.initialEntry,
    this.initialTabIndex,
    this.focusRequestId,
    this.focusScheduleId,
    this.focusSwapId,
  });

  final String roomId;
  final RoomMembershipEntry? initialEntry;

  /// 알림 딥링크에서 지정한 초기 탭 (owner/staff 각자의 인덱스)
  final int? initialTabIndex;

  /// 일정 변경·대타 요청 포커스용 (탭 진입 힌트)
  final String? focusRequestId;
  final String? focusScheduleId;
  final String? focusSwapId;

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late int _tabIndex;

  /// 사장 근무표 탭 — 달력 뷰 여부 (AppBar 토글)
  bool _scheduleCalendarView = false;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex ?? 0;
    RoomNavigation.intent.addListener(_onRoomNavIntent);
    // push 직후 발행된 의도 소비 (리스너 등록 전 발행분)
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRoomNavIntent());
  }

  @override
  void dispose() {
    RoomNavigation.intent.removeListener(_onRoomNavIntent);
    super.dispose();
  }

  void _onRoomNavIntent() {
    final next = RoomNavigation.takeIntentFor(widget.roomId);
    if (next == null || !mounted) return;
    if (next.tabIndex == null) return;
    setState(() => _tabIndex = _normalizeTab(next.tabIndex!));
  }

  /// 3탭 범위로 클램프. 구 4탭 딥링크(설정=3 등)만 보정.
  static int _normalizeTab(int raw) {
    // 구: 0·1·2(일정표)·3(설정/급여) → 신: 0·1·2
    if (raw >= 3) return 2;
    return raw.clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MockStore.instance,
      builder: (context, _) {
        final entry =
            MockStore.instance.roomEntry(widget.roomId) ?? widget.initialEntry;

        if (entry == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const ScrollablePageBody(
              top: false,
              child: Text('이 방에 대한 멤버십을 찾을 수 없습니다.'),
            ),
          );
        }

        final isOwnerMode = entry.role.isAdminDashboard;
        final safeIndex = _normalizeTab(_tabIndex);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(entry.room.name),
            actions: [
              if (isOwnerMode && safeIndex == 1) ...[
                IconButton(
                  tooltip: '리스트 뷰',
                  onPressed: () =>
                      setState(() => _scheduleCalendarView = false),
                  icon: Icon(
                    Icons.view_list_rounded,
                    color: !_scheduleCalendarView
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                IconButton(
                  tooltip: '달력 뷰',
                  onPressed: () =>
                      setState(() => _scheduleCalendarView = true),
                  icon: Icon(
                    Icons.calendar_month_rounded,
                    color: _scheduleCalendarView
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(child: RoomRoleBadge(role: entry.role)),
              ),
              const NotificationBellButton(),
            ],
          ),
          body: KeyedSubtree(
            key: ValueKey<bool>(isOwnerMode),
            child: isOwnerMode
                ? _OwnerShell(
                    room: entry.room,
                    membership: entry.membership,
                    index: safeIndex,
                    scheduleCalendarView: _scheduleCalendarView,
                  )
                : _StaffShell(
                    room: entry.room,
                    membership: entry.membership,
                    index: safeIndex,
                  ),
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: AppDecorations.topHairline,
            child: NavigationBar(
              key: ValueKey<String>(
                isOwnerMode ? 'owner-nav-3' : 'staff-nav-3',
              ),
              selectedIndex: safeIndex,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              destinations: isOwnerMode
                  ? const [
                      NavigationDestination(
                        icon: Icon(Icons.groups_outlined),
                        selectedIcon: Icon(Icons.groups),
                        label: '직원목록',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month),
                        label: '근무표',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: '설정',
                      ),
                    ]
                  : const [
                      NavigationDestination(
                        icon: Icon(Icons.directions_walk_outlined),
                        selectedIcon: Icon(Icons.directions_walk),
                        label: '출퇴근',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.event_note_outlined),
                        selectedIcon: Icon(Icons.event_note),
                        label: '내 근무표',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: '내 정보',
                      ),
                    ],
            ),
          ),
        );
      },
    );
  }
}

class _OwnerShell extends StatelessWidget {
  const _OwnerShell({
    required this.room,
    required this.membership,
    required this.index,
    required this.scheduleCalendarView,
  });

  final RoomModel room;
  final RoomMemberModel membership;
  final int index;
  final bool scheduleCalendarView;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: index,
      children: [
        OwnerHomeTab(room: room, membership: membership),
        OwnerScheduleTab(
          room: room,
          calendarView: scheduleCalendarView,
        ),
        OwnerStaffSettingsTab(room: room),
      ],
    );
  }
}

class _StaffShell extends StatelessWidget {
  const _StaffShell({
    required this.room,
    required this.membership,
    required this.index,
  });

  final RoomModel room;
  final RoomMemberModel membership;
  final int index;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: index,
      children: [
        StaffAttendanceTab(room: room, membership: membership),
        StaffScheduleTab(room: room),
        StaffPayrollTab(room: room, membership: membership),
      ],
    );
  }
}
