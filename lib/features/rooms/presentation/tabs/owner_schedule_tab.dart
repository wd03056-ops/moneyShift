import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/calendar/snappy_calendar.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/navigation/app_route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/kst_date_time.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../core/widgets/sticky_action_button.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../schedules/presentation/create_schedule_screen.dart';
import '../../../schedules/presentation/owner_change_request_sheet.dart';
import '../../../schedules/presentation/owner_staff_schedule_screen.dart';
import '../../../schedules/schedule_store.dart';
import '../../../schedules/utils/schedule_summary_formatter.dart';
import '../../../schedules/widgets/pending_change_card.dart';
import 'store_calendar_tab.dart';

/// 사장 근무표 — 리스트 / 달력 뷰 통합 + 근무 배정
class OwnerScheduleTab extends StatefulWidget {
  const OwnerScheduleTab({
    super.key,
    required this.room,
    this.calendarView = false,
    this.onCalendarViewChanged,
  });

  final RoomModel room;

  /// true면 달력 뷰, false면 배정·승인 리스트 뷰
  final bool calendarView;

  /// 제목 옆 리스트/달력 토글
  final ValueChanged<bool>? onCalendarViewChanged;

  @override
  State<OwnerScheduleTab> createState() => _OwnerScheduleTabState();
}

class _OwnerScheduleTabState extends State<OwnerScheduleTab> {
  late DateTime _calendarSelectedDay;

  @override
  void initState() {
    super.initState();
    final now = KstDateTime.now();
    _calendarSelectedDay = DateTime(now.year, now.month, now.day);
  }

  static List<_StaffAssignmentGroup> _groupByStaff(
    List<ScheduleModel> schedules,
    MockStore store,
    String roomId,
  ) {
    final map = <String, List<ScheduleModel>>{};
    for (final s in schedules) {
      // 방어: 타 방 스케줄이 섞여 들어오면 버림
      if (s.roomId != roomId) continue;
      map.putIfAbsent(s.workerId, () => []).add(s);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    final groups = map.entries
        .map(
          (e) => _StaffAssignmentGroup(
            workerId: e.key,
            displayName: store.memberDisplayName(roomId, e.key),
            schedules: e.value,
          ),
        )
        .toList();
    groups.sort((a, b) => a.displayName.compareTo(b.displayName));
    return groups;
  }

  void _openAssign(BuildContext context) {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.createSchedule(widget.room.id),
      stopAtNames: [AppRouteNames.room(widget.room.id)],
      builder: (_) => CreateScheduleScreen(
        room: widget.room,
        initialDate: widget.calendarView ? _calendarSelectedDay : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('M/d HH:mm');
    final rangeFmt = DateFormat('HH:mm');
    final dayFmt = DateFormat('M/d');
    final payFmt = NumberFormat('#,###');
    final room = widget.room;
    final calendarView = widget.calendarView;

    return FixedBottomPage(
      // 달력 뷰: 상단 달력 고정 + 하단 목록만 스크롤
      bodyScrollable: !calendarView,
      bottom: StickyActionBar(
        safeAreaBottom: false,
        children: [
          StickyActionButton(
            label: '+ 근무 배정',
            variant: StickyActionVariant.filled,
            onPressed: () => _openAssign(context),
          ),
        ],
      ),
      body: calendarView
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ScheduleTitleRow(
                  calendarView: calendarView,
                  onCalendarViewChanged: widget.onCalendarViewChanged,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StoreCalendarTab(
                    room: room,
                    showHeader: false,
                    embedded: true,
                    onSelectedDayChanged: (day) {
                      _calendarSelectedDay = day;
                    },
                  ),
                ),
              ],
            )
          : ListenableBuilder(
              listenable: ScheduleStore.listenable,
              builder: (context, _) {
                final store = MockStore.instance;
                final schedules = store.schedulesForRoom(room.id);
                final staffCount = store.activeStaffMembers(room.id).length;
                final pendingCount =
                    schedules.where((s) => !s.isConfirmed).length;
                final openSwaps = store.openShiftSwapsForRoom(room.id);
                final staffChangeReqs =
                    store.pendingStaffChangeRequestsForRoom(room.id);
                final groups = _groupByStaff(schedules, store, room.id);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ScheduleTitleRow(
                      calendarView: calendarView,
                      onCalendarViewChanged: widget.onCalendarViewChanged,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      staffCount == 0
                          ? '직원이 없으면 배정할 수 없어요. 직원목록에서 초대해 주세요.'
                          : '배정 $staffCount명 · 확인 대기 $pendingCount건'
                              '${openSwaps.isNotEmpty ? ' · 대타 ${openSwaps.length}건' : ''}'
                              '${staffChangeReqs.isNotEmpty ? ' · 변경 ${staffChangeReqs.length}건' : ''}'
                              '\n아래 버튼으로 근무를 배정하고, 시급·휴게·수당은 직원목록에서 설정해요.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (staffChangeReqs.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '일정 변경 승인 대기',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final s in staffChangeReqs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _StaffChangeApprovalCard(
                            schedule: s,
                            store: store,
                            timeFmt: timeFmt,
                          ),
                        ),
                    ],
                    if (openSwaps.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '대타 승인 대기',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      for (final swap in openSwaps)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SwapApprovalCard(
                            swap: swap,
                            schedule: store.schedules[swap.scheduleId],
                            store: store,
                            timeFmt: timeFmt,
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      '배정 목록',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (groups.isEmpty)
                      AppCard(
                        child: Text(
                          '배정된 일정이 없습니다.\n'
                          '아래 \'+ 근무 배정\'으로 일정을 등록하세요.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.4,
                                  ),
                        ),
                      )
                    else
                      for (final group in groups)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _StaffGroupCard(
                            group: group,
                            store: store,
                            room: room,
                            dayFmt: dayFmt,
                            rangeFmt: rangeFmt,
                            payFmt: payFmt,
                          ),
                        ),
                  ],
                );
              },
            ),
    );
  }
}

/// 근무표 제목 + 리스트/달력 뷰 토글
class _ScheduleTitleRow extends StatelessWidget {
  const _ScheduleTitleRow({
    required this.calendarView,
    this.onCalendarViewChanged,
  });

  final bool calendarView;
  final ValueChanged<bool>? onCalendarViewChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            '근무표',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          tooltip: '리스트 뷰',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: onCalendarViewChanged == null
              ? null
              : () => onCalendarViewChanged!(false),
          icon: Icon(
            Icons.view_list_rounded,
            color: !calendarView
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
        IconButton(
          tooltip: '달력 뷰',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: onCalendarViewChanged == null
              ? null
              : () => onCalendarViewChanged!(true),
          icon: Icon(
            Icons.calendar_month_rounded,
            color: calendarView
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StaffAssignmentGroup {
  const _StaffAssignmentGroup({
    required this.workerId,
    required this.displayName,
    required this.schedules,
  });

  final String workerId;
  final String displayName;
  final List<ScheduleModel> schedules;

  int get pendingCount => schedules.where((s) => !s.isConfirmed).length;

  bool get allConfirmed =>
      schedules.isNotEmpty && schedules.every((s) => s.isConfirmed);

  bool get hasOpenSwap => schedules.any(
        (s) => MockStore.instance.openSwapForSchedule(s.id) != null,
      );

  bool get hasChangeRequest =>
      schedules.any((s) => s.isChangeRequested);

  int get totalEstimatedPay => schedules.fold<int>(
        0,
        (sum, s) => s.isAbsent ? sum : sum + (s.estimatedPay ?? 0),
      );

  /// 상세 시트용 — 기간 배정은 한 덩어리로 묶음
  /// (결근·취소된 날·변경요청 중인 날은 묶음에서 빼 개별 표시)
  List<_AssignmentChunk> get detailChunks {
    final chunks = <_AssignmentChunk>[];
    final seenPeriodBatches = <String>{};

    for (final s in schedules) {
      final batchId = s.assignmentBatchId;
      if (s.isPeriodBatch &&
          batchId != null &&
          !s.isAbsent &&
          !s.isChangeRequested) {
        if (seenPeriodBatches.contains(batchId)) continue;
        seenPeriodBatches.add(batchId);
        final batch = schedules
            .where(
              (x) =>
                  x.assignmentBatchId == batchId &&
                  !x.isAbsent &&
                  !x.isChangeRequested,
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        if (batch.isEmpty) continue;
        chunks.add(_AssignmentChunk(schedules: batch, isPeriod: true));
        continue;
      }
      chunks.add(_AssignmentChunk(schedules: [s], isPeriod: false));
    }
    return chunks;
  }
}

class _AssignmentChunk {
  const _AssignmentChunk({
    required this.schedules,
    required this.isPeriod,
  });

  final List<ScheduleModel> schedules;
  final bool isPeriod;

  bool get allConfirmed => schedules.every((s) => s.isConfirmed);

  int get pendingCount => schedules.where((s) => !s.isConfirmed).length;

  int get totalPay => schedules.fold<int>(
        0,
        (sum, s) => sum + (s.estimatedPay ?? 0),
      );

  bool get hasOpenSwap => schedules.any(
        (s) => MockStore.instance.openSwapForSchedule(s.id) != null,
      );

  bool get hasChangeRequest =>
      schedules.any((s) => s.isChangeRequested);
}

class _StaffGroupCard extends StatefulWidget {
  const _StaffGroupCard({
    required this.group,
    required this.store,
    required this.room,
    required this.dayFmt,
    required this.rangeFmt,
    required this.payFmt,
  });

  final _StaffAssignmentGroup group;
  final MockStore store;
  final RoomModel room;
  final DateFormat dayFmt;
  final DateFormat rangeFmt;
  final NumberFormat payFmt;

  @override
  State<_StaffGroupCard> createState() => _StaffGroupCardState();
}

class _StaffGroupCardState extends State<_StaffGroupCard> {
  /// 개별 요약 블록별 펼침 여부
  final Set<int> _expandedBlocks = {};

  Future<void> _openDetail() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      sheetAnimationStyle: SnappyCalendar.sheetAnimationStyle,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _StaffAssignmentDetailSheet(
        room: widget.room,
        group: widget.group,
        store: widget.store,
        dayFmt: widget.dayFmt,
        rangeFmt: widget.rangeFmt,
        payFmt: widget.payFmt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final payFmt = widget.payFmt;
    final textTheme = Theme.of(context).textTheme;
    final blocks = formatScheduleSummary(
      group.schedules,
      dayFmt: widget.dayFmt,
      rangeFmt: widget.rangeFmt,
    );

    return AppCard(
      onTap: _openDetail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (group.hasChangeRequest) ...[
                const ChangeRequestedBadge(),
                const SizedBox(width: 6),
              ],
              if (group.hasOpenSwap) ...[
                const _ToneBadge(
                  label: '대타 요청 중',
                  color: AppColors.warning,
                ),
                const SizedBox(width: 6),
              ],
              _ConfirmBadge(confirmed: group.allConfirmed),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            ..._buildBlock(context, blocks[i], i),
          ],
          if (group.totalEstimatedPay > 0) ...[
            const SizedBox(height: 10),
            Text(
              '예상 급여 ${payFmt.format(group.totalEstimatedPay)}원',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildBlock(
    BuildContext context,
    ScheduleSummaryBlock block,
    int index,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final expanded = _expandedBlocks.contains(index);
    final lines = block.visibleLines(expanded: expanded);
    final style = textTheme.bodyMedium?.copyWith(
      color: AppColors.textCaption,
      height: 1.35,
    );

    return [
      for (final line in lines)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(line, style: style),
        ),
      if (block.isExpandable)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedBlocks.remove(index);
                } else {
                  _expandedBlocks.add(index);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                expanded
                    ? '접기'
                    : '+${block.hiddenCount}개 일정 더보기',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

class _StaffAssignmentDetailSheet extends StatelessWidget {
  const _StaffAssignmentDetailSheet({
    required this.room,
    required this.group,
    required this.store,
    required this.dayFmt,
    required this.rangeFmt,
    required this.payFmt,
  });

  final RoomModel room;
  final _StaffAssignmentGroup group;
  final MockStore store;
  final DateFormat dayFmt;
  final DateFormat rangeFmt;
  final NumberFormat payFmt;

  RoomMemberModel? get _member => store.getMembership(room.id, group.workerId);

  String _singleDayTitle(ScheduleModel s) {
    final sameDay = s.startTime.year == s.endTime.year &&
        s.startTime.month == s.endTime.month &&
        s.startTime.day == s.endTime.day;
    if (sameDay) {
      return '${dayFmt.format(s.startTime)} '
          '${rangeFmt.format(s.startTime)} ~ ${rangeFmt.format(s.endTime)}';
    }
    return '${dayFmt.format(s.startTime)} ${rangeFmt.format(s.startTime)}'
        ' ~ ${dayFmt.format(s.endTime)} ${rangeFmt.format(s.endTime)}';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final chunks = group.detailChunks;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
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
              group.displayName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '배정 ${group.schedules.length}건 · '
              '예상 급여 ${payFmt.format(group.totalEstimatedPay)}원',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: chunks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final chunk = chunks[index];
                  if (chunk.isPeriod) {
                    final first = chunk.schedules.first;
                    final last = chunk.schedules.last;
                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${dayFmt.format(first.startTime)} ~ '
                                  '${dayFmt.format(last.startTime)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              _ConfirmBadge(
                                confirmed: chunk.allConfirmed,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${rangeFmt.format(first.startTime)} ~ '
                            '${rangeFmt.format(first.endTime)} · '
                            '${chunk.schedules.length}일',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.textCaption,
                                ),
                          ),
                          if (chunk.hasOpenSwap) ...[
                            const SizedBox(height: 6),
                            Text(
                              '대타 요청 포함',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                          if (chunk.totalPay > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              '예상 급여 ${payFmt.format(chunk.totalPay)}원',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  final s = chunk.schedules.first;
                  final swap = store.openSwapForSchedule(s.id);
                  final live = store.schedules[s.id] ?? s;
                  final pending = live.pendingChange;
                  return AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _singleDayTitle(live),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (live.isChangeRequested)
                              const ChangeRequestedBadge()
                            else if (live.isAbsent)
                              const _ToneBadge(
                                label: '결근',
                                color: AppColors.holiday,
                              )
                            else
                              _ConfirmBadge(confirmed: live.isConfirmed),
                          ],
                        ),
                        if (live.isChangeRequested && pending != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${DateFormat('HH:mm').format(live.startTime)} ➔ '
                            '${DateFormat('HH:mm').format(pending.startTime)}'
                            '  ·  '
                            '${DateFormat('HH:mm').format(live.endTime)} ➔ '
                            '${DateFormat('HH:mm').format(pending.endTime)}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                          Text(
                            pending.changeType.labelKo,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ],
                        if (swap != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '대타 · ${swap.status.labelKo}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                        if (live.estimatedPay != null && !live.isAbsent) ...[
                          const SizedBox(height: 6),
                          Text(
                            '예상 급여 ${payFmt.format(live.estimatedPay)}원',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                OwnerChangeRequestSheet.show(
                                  context,
                                  schedule: live,
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                '일정 변경 요청',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: () {
                                try {
                                  if (live.isAbsent) {
                                    store.clearScheduleAbsent(live.id);
                                    showAppSnackBar(
                                      context,
                                      message: '결근 처리를 해제했습니다.',
                                    );
                                  } else {
                                    store.markScheduleAbsent(live.id);
                                    showAppSnackBar(
                                      context,
                                      message: '결근 처리했습니다.',
                                    );
                                  }
                                } catch (e) {
                                  showAppSnackBar(
                                    context,
                                    message: '$e',
                                  );
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: live.isAbsent
                                    ? AppColors.textSecondary
                                    : AppColors.holiday,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                live.isAbsent ? '결근 해제' : '결근 처리',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: live.isAbsent
                                          ? AppColors.textSecondary
                                          : AppColors.holiday,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StickyActionButton(
                    label: '근무 추가',
                    variant: StickyActionVariant.primary,
                    onPressed: () {
                      final member = _member;
                      if (member == null) return;
                      Navigator.of(context).pop();
                      AppNavigation.pushSingleTop(
                        name: AppRouteNames.createSchedule(room.id),
                        stopAtNames: [AppRouteNames.room(room.id)],
                        builder: (_) => CreateScheduleScreen(
                          room: room,
                          initialStaff: member,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StickyActionButton(
                    label: '상세 관리',
                    variant: StickyActionVariant.filled,
                    onPressed: () {
                      final member = _member;
                      if (member == null) return;
                      Navigator.of(context).pop();
                      AppNavigation.pushSingleTop(
                        name: AppRouteNames.ownerStaffSchedule(
                          room.id,
                          member.userId,
                        ),
                        stopAtNames: [AppRouteNames.room(room.id)],
                        builder: (_) => OwnerStaffScheduleScreen(
                          room: room,
                          member: member,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffChangeApprovalCard extends StatefulWidget {
  const _StaffChangeApprovalCard({
    required this.schedule,
    required this.store,
    required this.timeFmt,
  });

  final ScheduleModel schedule;
  final MockStore store;
  final DateFormat timeFmt;

  @override
  State<_StaffChangeApprovalCard> createState() =>
      _StaffChangeApprovalCardState();
}

class _StaffChangeApprovalCardState extends State<_StaffChangeApprovalCard> {
  bool _busy = false;

  Future<void> _resolve(bool approve) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      ScheduleStore.resolveStaffChange(
        scheduleId: widget.schedule.id,
        approve: approve,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: approve ? '일정 변경을 승인했습니다.' : '일정 변경을 거절했습니다.',
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, message: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.schedule;
    final pending = s.pendingChange;
    final store = widget.store;
    final timeFmt = widget.timeFmt;
    final name = store.memberDisplayName(s.roomId, s.workerId);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const ChangeRequestedBadge(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${timeFmt.format(s.startTime)} ~ ${timeFmt.format(s.endTime)}'
            '${pending != null ? '  →  ${timeFmt.format(pending.startTime)} ~ ${timeFmt.format(pending.endTime)}' : ''}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (pending != null) ...[
            const SizedBox(height: 6),
            Text(
              '사유: ${pending.reason}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textCaption,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StickyActionButton(
                  label: '거절',
                  variant: StickyActionVariant.primary,
                  onPressed: _busy ? null : () => _resolve(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StickyActionButton(
                  label: '승인',
                  variant: StickyActionVariant.filled,
                  onPressed: _busy ? null : () => _resolve(true),
                  isLoading: _busy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwapApprovalCard extends StatefulWidget {
  const _SwapApprovalCard({
    required this.swap,
    required this.schedule,
    required this.store,
    required this.timeFmt,
  });

  final ShiftSwapRequest swap;
  final ScheduleModel? schedule;
  final MockStore store;
  final DateFormat timeFmt;

  @override
  State<_SwapApprovalCard> createState() => _SwapApprovalCardState();
}

class _SwapApprovalCardState extends State<_SwapApprovalCard> {
  bool _busy = false;

  Future<void> _run(FutureOr<void> Function() action, String okMsg) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Future<void>.sync(action);
      if (!mounted) return;
      showAppSnackBar(context, message: okMsg);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, message: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final swap = widget.swap;
    final schedule = widget.schedule;
    final store = widget.store;
    final timeFmt = widget.timeFmt;
    final from = store.memberDisplayName(swap.roomId, swap.fromWorkerId);
    final to = store.memberDisplayName(swap.roomId, swap.toWorkerId);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$from → $to',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              _ToneBadge(
                label: swap.status.labelKo,
                color: AppColors.warning,
              ),
            ],
          ),
          if (schedule != null) ...[
            const SizedBox(height: 6),
            Text(
              '${timeFmt.format(schedule.startTime)} ~ '
              '${timeFmt.format(schedule.endTime)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '사유: ${swap.reason}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textCaption,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StickyActionButton(
                  label: '거절',
                  variant: StickyActionVariant.primary,
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => store.rejectShiftSwap(swap.id),
                            '대타 요청을 거절했습니다.',
                          ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StickyActionButton(
                  label: '승인',
                  variant: StickyActionVariant.filled,
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => store.approveShiftSwap(swap.id),
                            '대타 승인 · 근무자가 $to(으)로 변경되었습니다.',
                          ),
                  isLoading: _busy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmBadge extends StatelessWidget {
  const _ConfirmBadge({required this.confirmed});

  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    if (confirmed) {
      return const _ToneBadge(
        label: '확인 완료',
        color: AppColors.success,
      );
    }
    return const _ToneBadge(
      label: '확인 대기',
      color: AppColors.warning,
    );
  }
}

class _ToneBadge extends StatelessWidget {
  const _ToneBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
