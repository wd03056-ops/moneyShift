import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/calendar/korean_holidays.dart';
import '../../../core/calendar/snappy_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/kst_date_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../models/models.dart';
import '../schedule_store.dart';
import '../widgets/schedule_day_detail_card.dart';

/// 배정된 근무 단위(개별·기간) 전용 상세보기 — 내 근무표와 분리
class StaffAssignedDetailScreen extends StatefulWidget {
  const StaffAssignedDetailScreen({
    super.key,
    required this.schedules,
  });

  /// 진입 시 연 배정 단위(기간 묶음 또는 단건)
  final List<ScheduleModel> schedules;

  @override
  State<StaffAssignedDetailScreen> createState() =>
      _StaffAssignedDetailScreenState();
}

class _StaffAssignedDetailScreenState extends State<StaffAssignedDetailScreen> {
  static const double _headerH = 44;
  static const double _dowH = 20;
  /// 일자 원 28 + gap 2 + 점 5 + 여유 ≥ 52
  static const double _minRowHeight = 52;

  late DateTime _focusedDay;
  /// initState에서 _resolve 전에 비어 있어도 안전 (late 미초기화 방지)
  List<ScheduleModel> _sorted = [];
  int _selectedIndex = 0;
  late String _roomId;
  late String _workerId;
  bool _busy = false;
  bool _allConfirmCompleted = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _dateKey(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(_dateOnly(d));

  String _scheduleDateKey(ScheduleModel s) =>
      s.date.isNotEmpty ? s.date : _dateKey(s.startTime);

  @override
  void initState() {
    super.initState();
    final seed = widget.schedules.first;
    _roomId = seed.roomId;
    _workerId = seed.workerId;
    _sorted = _resolveScheduleList(preferId: seed.id);
    _selectedIndex = _sorted.indexWhere((s) => s.id == seed.id);
    if (_selectedIndex < 0) _selectedIndex = 0;
    _focusedDay = _dateOnly(_sorted[_selectedIndex].startTime);
  }

  /// 진입 단위 + 확인 대기 + 이번 세션에 보던 항목을 유지 (확인 후에도 화면이 비지 않음)
  List<ScheduleModel> _resolveScheduleList({String? preferId}) {
    final pending = ScheduleStore.pendingForWorker(_roomId, _workerId);
    final byId = <String, ScheduleModel>{
      for (final s in widget.schedules) s.id: s,
      for (final s in _sorted) s.id: s,
      for (final s in pending) s.id: s,
    };
    // 스토어 최신본으로 덮어쓰기
    for (final id in byId.keys.toList()) {
      final found =
          ScheduleStore.forRoom(_roomId).where((x) => x.id == id);
      if (found.isNotEmpty) byId[id] = found.first;
    }
    final list = byId.values.where((s) => !s.isAbsent).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (list.isEmpty && preferId != null) {
      return [...widget.schedules]
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return list;
  }

  List<ScheduleModel> _liveSchedules() => _resolveScheduleList(
        preferId: _sorted.isEmpty
            ? null
            : _sorted[_selectedIndex.clamp(0, _sorted.length - 1)].id,
      );

  /// 선택 id·날짜를 최대한 유지한 채 리스트만 갱신
  void _applyLiveList(
    List<ScheduleModel> live, {
    String? preferId,
    DateTime? preferDay,
  }) {
    if (live.isEmpty) return;
    final keepId = preferId ??
        (_sorted.isEmpty
            ? null
            : _sorted[_selectedIndex.clamp(0, _sorted.length - 1)].id);
    final keepDay = preferDay ??
        (_sorted.isEmpty
            ? null
            : _dateOnly(
                _sorted[_selectedIndex.clamp(0, _sorted.length - 1)].startTime,
              ));
    _sorted = live;
    var idx = keepId == null
        ? -1
        : _sorted.indexWhere((s) => s.id == keepId);
    if (idx < 0 && keepDay != null) {
      idx = _sorted.indexWhere((s) => isSameDay(s.startTime, keepDay));
    }
    if (idx < 0) idx = 0;
    _selectedIndex = idx;
    _focusedDay = _dateOnly(_sorted[idx].startTime);
  }

  void _selectLive(List<ScheduleModel> live, int index) {
    if (index < 0 || index >= live.length) return;
    setState(() {
      _sorted = live;
      _selectedIndex = index;
      _focusedDay = _dateOnly(live[index].startTime);
    });
  }

  /// 확인 후: 화면 유지 + (가능하면) 다음 대기일로 이동
  void _onConfirmedStay({
    required DateTime confirmedDay,
    required String message,
    required bool goNextPending,
    required bool markAllDone,
  }) {
    if (!mounted) return;
    // UI 갱신보다 먼저 스낵바 — 체감 지연 방지
    showAppSnackBar(
      context,
      message: message,
      aboveStickyActions: true,
    );

    final stillPending = ScheduleStore.pendingForWorker(_roomId, _workerId)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final live = _liveSchedules();

    String? preferId;
    DateTime? preferDay = confirmedDay;
    if (goNextPending && stillPending.isNotEmpty) {
      final next = stillPending.firstWhere(
        (s) => _dateOnly(s.startTime).isAfter(confirmedDay),
        orElse: () => stillPending.first,
      );
      preferId = next.id;
      preferDay = _dateOnly(next.startTime);
    }

    setState(() {
      _busy = false;
      if (markAllDone || stillPending.isEmpty) {
        _allConfirmCompleted = true;
      }
      if (live.isNotEmpty) {
        _applyLiveList(live, preferId: preferId, preferDay: preferDay);
      }
    });
  }

  double _calendarHeight(double rowHeight, DateTime focused) {
    final first = DateTime(focused.year, focused.month, 1);
    final last = DateTime(focused.year, focused.month + 1, 0);
    final startOffset = first.weekday % 7;
    final weeks = ((startOffset + last.day + 6) ~/ 7).clamp(4, 6);
    return _headerH + _dowH + (rowHeight * weeks) + 8;
  }

  Widget _dayCell(
    BuildContext context,
    DateTime day, {
    required bool assigned,
    required bool selected,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final isRed = KoreanHolidays.isRedDay(day);
    final isToday = isSameDay(day, KstDateTime.now());
    final numberColor = selected
        ? Colors.white
        : (isRed ? AppColors.holiday : AppColors.textPrimary);

    return SizedBox(
      height: _minRowHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: selected
                ? const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  )
                : (isToday
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 1.2),
                      )
                    : null),
            child: Text(
              '${day.day}',
              style: textTheme.labelSmall?.copyWith(
                fontSize: 14,
                height: 1.1,
                fontWeight: (isToday || selected || assigned)
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: numberColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 5,
            height: 5,
            child: assigned && !selected
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _navChevron({
    required bool enabled,
    required bool isLeft,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: isLeft ? '이전 배정일' : '다음 배정일',
      onPressed: enabled ? onPressed : null,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        isLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        size: 32,
        color: enabled ? AppColors.textPrimary : AppColors.border,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat('#,###');

    return ListenableBuilder(
      listenable: ScheduleStore.listenable,
      builder: (context, _) {
        final live = _liveSchedules();
        if (live.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: const Text('상세보기'),
            ),
            body: const Center(child: Text('표시할 배정 근무가 없습니다.')),
          );
        }

        // 리스트 갱신은 다음 프레임에만 반영 (build 중 setState 금지)
        final preferId = _sorted.isEmpty
            ? null
            : _sorted[_selectedIndex.clamp(0, _sorted.length - 1)].id;
        final needsSync = live.length != _sorted.length ||
            !_sorted.every((s) => live.any((l) => l.id == s.id));
        if (needsSync) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(
              () => _applyLiveList(
                live,
                preferId: preferId,
                preferDay: _focusedDay,
              ),
            );
          });
        }

        var viewIndex =
            preferId == null ? -1 : live.indexWhere((s) => s.id == preferId);
        if (viewIndex < 0) {
          viewIndex =
              live.indexWhere((s) => isSameDay(s.startTime, _focusedDay));
        }
        if (viewIndex < 0) viewIndex = 0;
        final sample = live[viewIndex];
        final canPrev = viewIndex > 0;
        final canNext = viewIndex < live.length - 1;
        final showNav = live.length > 1;
        final batchId = sample.assignmentBatchId;
        final batchMates = batchId == null
            ? <ScheduleModel>[sample]
            : live
                .where((s) => s.assignmentBatchId == batchId)
                .toList(growable: false);
        final totalPay = batchMates.fold<int>(
          0,
          (sum, s) => sum + (s.estimatedPay ?? 0),
        );
        final canConfirmCurrent = !sample.isConfirmed;
        final hasAnyPending = live.any((s) => !s.isConfirmed);

        final detailCard = ScheduleDayDetailCard(
          key: ValueKey(sample.id),
          schedule: sample,
          enableSwapRequest: sample.isConfirmed,
          extraBadges: [
            if (sample.includeWeeklyHoliday)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '주휴수당',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ),
            if (sample.includeOvertimeNight)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '연장수당',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
          ],
          footer: batchMates.length > 1
              ? Text(
                  '기간 합계 ${currency.format(totalPay)}원 '
                  '(${batchMates.length}일)',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                )
              : null,
        );

        return Scaffold(
          backgroundColor: AppColors.primarySoft,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Text('상세보기'),
          ),
          body: FixedBottomPage(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            bottom: (!hasAnyPending && !_allConfirmCompleted)
                ? null
                : StickyActionBar(
                    safeAreaBottom: true,
                    elevated: true,
                    children: [
                      StickyActionButton(
                        label: '확인',
                        variant: StickyActionVariant.primary,
                        enabled: !_busy &&
                            !_allConfirmCompleted &&
                            canConfirmCurrent,
                        isLoading: _busy,
                        isCompleted: _allConfirmCompleted ||
                            (!canConfirmCurrent && !_busy),
                        completedLabel: '완료됨',
                        onPressed: (_busy ||
                                _allConfirmCompleted ||
                                !canConfirmCurrent)
                            ? null
                            : () {
                                setState(() => _busy = true);
                                final confirmedDay =
                                    _dateOnly(sample.startTime);
                                ScheduleStore.confirm(sample.id);
                                if (!mounted) return;
                                _onConfirmedStay(
                                  confirmedDay: confirmedDay,
                                  message: '확인되었습니다',
                                  goNextPending: true,
                                  markAllDone: false,
                                );
                              },
                      ),
                      StickyActionButton(
                        label: '전체확인',
                        variant: StickyActionVariant.filled,
                        enabled:
                            !_busy && !_allConfirmCompleted && hasAnyPending,
                        isLoading: _busy,
                        isCompleted: _allConfirmCompleted || !hasAnyPending,
                        completedLabel: '처리 완료',
                        onPressed: (_busy ||
                                _allConfirmCompleted ||
                                !hasAnyPending)
                            ? null
                            : () {
                                setState(() => _busy = true);
                                final confirmedDay =
                                    _dateOnly(sample.startTime);
                                ScheduleStore.confirmAllPending(
                                  roomId: _roomId,
                                  workerId: _workerId,
                                );
                                if (!mounted) return;
                                _onConfirmedStay(
                                  confirmedDay: confirmedDay,
                                  message: '완료되었습니다',
                                  goNextPending: false,
                                  markAllDone: true,
                                );
                              },
                      ),
                    ],
                  ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '배정된 근무',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final rowHeight =
                        (constraints.maxWidth / 7 * 0.9).clamp(_minRowHeight, 60.0);
                    final calH = _calendarHeight(rowHeight, _focusedDay);
                    final assignedKeys = {
                      for (final s in live) _scheduleDateKey(s),
                    };
                    bool isAssigned(DateTime day) =>
                        assignedKeys.contains(_dateKey(_dateOnly(day)));
                    return AppCard(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                      child: SizedBox(
                        height: calH,
                        width: constraints.maxWidth,
                        child: TableCalendar<ScheduleModel>(
                          firstDay: DateTime.utc(2024, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(day, sample.startTime),
                          calendarFormat: CalendarFormat.month,
                          availableCalendarFormats: const {
                            CalendarFormat.month: 'Month',
                          },
                          startingDayOfWeek: StartingDayOfWeek.sunday,
                          locale: 'ko_KR',
                          rowHeight: rowHeight,
                          daysOfWeekHeight: _dowH,
                          sixWeekMonthsEnforced: false,
                          shouldFillViewport: true,
                          pageAnimationEnabled:
                              SnappyCalendar.pageAnimationEnabled,
                          pageAnimationDuration:
                              SnappyCalendar.pageAnimationDuration,
                          formatAnimationDuration:
                              SnappyCalendar.formatAnimationDuration,
                          availableGestures:
                              AvailableGestures.horizontalSwipe,
                          // 비배정일을 비활성화하지 않음 — 달력이 하얗게 보이지 않도록
                          onDaySelected: (day, focused) {
                            if (!isAssigned(day)) return;
                            final key = _dateKey(day);
                            final index = live.indexWhere(
                              (s) => _scheduleDateKey(s) == key,
                            );
                            if (index < 0) return;
                            setState(() {
                              _sorted = live;
                              _selectedIndex = index;
                              _focusedDay = focused;
                            });
                          },
                          onPageChanged: (focused) {
                            setState(() => _focusedDay = focused);
                          },
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            headerPadding: const EdgeInsets.only(bottom: 8),
                            titleTextStyle: textTheme.bodyLarge!.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            leftChevronIcon: const Icon(
                              Icons.chevron_left_rounded,
                              color: AppColors.textPrimary,
                              size: 22,
                            ),
                            rightChevronIcon: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textPrimary,
                              size: 22,
                            ),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: textTheme.labelSmall!.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                            weekendStyle: textTheme.labelSmall!.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.holiday,
                            ),
                          ),
                          holidayPredicate: KoreanHolidays.isHoliday,
                          calendarStyle: const CalendarStyle(
                            outsideDaysVisible: false,
                            holidayDecoration: BoxDecoration(),
                            selectedDecoration: BoxDecoration(),
                            todayDecoration: BoxDecoration(),
                            disabledDecoration: BoxDecoration(),
                            defaultTextStyle: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, focused) =>
                                _dayCell(
                                  context,
                                  day,
                                  assigned: isAssigned(day),
                                  selected:
                                      isSameDay(day, sample.startTime),
                                ),
                            todayBuilder: (context, day, focused) =>
                                _dayCell(
                                  context,
                                  day,
                                  assigned: isAssigned(day),
                                  selected:
                                      isSameDay(day, sample.startTime),
                                ),
                            holidayBuilder: (context, day, focused) =>
                                _dayCell(
                                  context,
                                  day,
                                  assigned: isAssigned(day),
                                  selected:
                                      isSameDay(day, sample.startTime),
                                ),
                            selectedBuilder: (context, day, focused) =>
                                _dayCell(
                                  context,
                                  day,
                                  assigned: true,
                                  selected: true,
                                ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (!showNav)
                  detailCard
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _navChevron(
                        enabled: canPrev,
                        isLeft: true,
                        onPressed: () =>
                            _selectLive(live, viewIndex - 1),
                      ),
                      Expanded(child: detailCard),
                      _navChevron(
                        enabled: canNext,
                        isLeft: false,
                        onPressed: () =>
                            _selectLive(live, viewIndex + 1),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
