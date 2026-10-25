import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ads/widgets/app_banner_ad.dart';
import '../../../core/navigation/room_navigation.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';
import '../../notifications/presentation/notification_bell_button.dart';
import '../widgets/room_role_badge.dart';
import 'tabs/owner_home_tab.dart';
import 'tabs/owner_invite_tab.dart';
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

  /// 사장 근무표 탭 — 달력 뷰 여부 (제목 옆 토글)
  bool _scheduleCalendarView = false;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex ?? 0;
    RoomNavigation.intent.addListener(_onRoomNavIntent);
    // push 직후 발행된 의도 소비 (리스너 등록 전 발행분)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onRoomNavIntent();
      // 출퇴근·급여 SSOT 보강: Firestore attendance_logs 병합 (1회/방)
      unawaited(
        MockStore.instance.syncAttendanceLogsForRoom(widget.roomId),
      );
    });
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
    final entry = MockStore.instance.roomEntry(widget.roomId);
    final isOwner = entry?.role.isAdminDashboard ?? false;
    setState(
      () => _tabIndex = _normalizeTab(next.tabIndex!, isOwner: isOwner),
    );
  }

  /// 사장 4탭 / 직원 3탭 범위로 클램프.
  /// 구 사장 탭 딥링크는 [RoomDetailScreen] 진입 전에
  /// [NotificationDeepLink.tabIndexFor] 가 현재 인덱스로 변환한다.
  int _normalizeTab(int raw, {required bool isOwner}) {
    final max = isOwner ? 3 : 2;
    return raw.clamp(0, max);
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
        final safeIndex = _normalizeTab(_tabIndex, isOwner: isOwnerMode);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(entry.room.name),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(child: RoomRoleBadge(role: entry.role)),
              ),
              const NotificationBellButton(),
            ],
          ),
          body: KeyedSubtree(
            // 방·역할이 바뀌면 셸을 새로 만들어 타 방 근무/배정 상태가 남지 않게 함
            key: ValueKey<String>('${entry.room.id}_$isOwnerMode'),
            child: isOwnerMode
                ? _OwnerShell(
                    room: entry.room,
                    membership: entry.membership,
                    index: safeIndex,
                    scheduleCalendarView: _scheduleCalendarView,
                    onScheduleCalendarViewChanged: (v) =>
                        setState(() => _scheduleCalendarView = v),
                  )
                : _StaffShell(
                    room: entry.room,
                    membership: entry.membership,
                    index: safeIndex,
                  ),
          ),
          bottomNavigationBar: BottomNavWithBanner(
            navigationBar: DecoratedBox(
              decoration: AppDecorations.topHairline,
              child: NavigationBar(
                key: ValueKey<String>(
                  isOwnerMode ? 'owner-nav-4' : 'staff-nav-3',
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
                          icon: Icon(Icons.person_add_alt_1_outlined),
                          selectedIcon: Icon(Icons.person_add_alt_1),
                          label: '초대하기',
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
    required this.onScheduleCalendarViewChanged,
  });

  final RoomModel room;
  final RoomMemberModel membership;
  final int index;
  final bool scheduleCalendarView;
  final ValueChanged<bool> onScheduleCalendarViewChanged;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: index,
      children: [
        OwnerHomeTab(room: room, membership: membership),
        OwnerScheduleTab(
          room: room,
          calendarView: scheduleCalendarView,
          onCalendarViewChanged: onScheduleCalendarViewChanged,
        ),
        OwnerInviteTab(room: room),
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
