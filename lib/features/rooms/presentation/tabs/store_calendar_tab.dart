import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/calendar/korean_holidays.dart';
import '../../../../core/calendar/snappy_calendar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/kst_date_time.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../mock/mock_session.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../schedules/schedule_store.dart';

/// 매장 전체 근무 일정 달력 뷰
///
/// [embedded]가 true이면 스크롤/타이틀 래퍼 없이 본문만 반환해
/// 상위 [FixedBottomPage] 등에 끼워 넣을 수 있다.
class StoreCalendarTab extends StatefulWidget {
  const StoreCalendarTab({
    super.key,
    required this.room,
    this.showHeader = true,
    this.embedded = false,
    this.onSelectedDayChanged,
  });

  final RoomModel room;

  /// false면 '근무 일정표' 제목·부제 생략
  final bool showHeader;

  /// true면 ColoredBox/ScrollablePageBody 없이 Column 본문만
  final bool embedded;

  /// 날짜 선택 시 상위(근무 배정 등)에 전달
  final ValueChanged<DateTime>? onSelectedDayChanged;

  @override
  State<StoreCalendarTab> createState() => _StoreCalendarTabState();
}

class _StoreCalendarTabState extends State<StoreCalendarTab> {
  late DateTime _focusedDay;
  late final ValueNotifier<DateTime> _selectedDay;

  static const double _headerH = 44;
  static const double _dowH = 20;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(KstDateTime.now());
    _focusedDay = today;
    _selectedDay = ValueNotifier(today);
    widget.onSelectedDayChanged?.call(today);
  }

  @override
  void dispose() {
    _selectedDay.dispose();
    super.dispose();
  }

  Map<DateTime, List<ScheduleModel>> _groupByDate(List<ScheduleModel> all) {
    final map = <DateTime, List<ScheduleModel>>{};
    for (final s in all) {
      final parts = s.date.split('-');
      if (parts.length != 3) continue;
      final day = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      map.putIfAbsent(day, () => []).add(s);
    }
    return map;
  }

  static int _weeksInMonth(DateTime focused) {
    final first = DateTime(focused.year, focused.month, 1);
    final last = DateTime(focused.year, focused.month + 1, 0);
    final startOffset = first.weekday % 7;
    return ((startOffset + last.day + 6) ~/ 7).clamp(4, 6);
  }

  double _calendarHeight(double rowHeight, DateTime focused) =>
      _headerH + _dowH + (rowHeight * _weeksInMonth(focused)) + 8;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final dayTitleFmt = DateFormat('M월 d일 (E)', 'ko_KR');

    return ListenableBuilder(
      listenable: ScheduleStore.listenable,
      builder: (context, _) {
        final textTheme = Theme.of(context).textTheme;
        final store = MockStore.instance;
        final all = store.schedulesForRoom(widget.room.id)
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        final byDate = _groupByDate(all);
        final uid = MockSession.instance.currentUser?.uid;
        final membership = uid == null
            ? null
            : store.getMembership(widget.room.id, uid);
        final canSeeAllSwaps =
            membership?.role.canManageSchedules ?? false;
        final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showHeader) ...[
                  Text(
                    '근무 일정표',
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '매장 전체 근무자를 한눈에 확인하세요',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final rowHeight =
                        (constraints.maxWidth / 7 * 0.85).clamp(52.0, 58.0);
                    final calH = _calendarHeight(rowHeight, _focusedDay);

                    return AppCard(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
                      child: SizedBox(
                        height: calH,
                        width: constraints.maxWidth,
                        child: ClipRect(
                          child: ValueListenableBuilder<DateTime>(
                            valueListenable: _selectedDay,
                            builder: (context, selectedDay, _) {
                              return TableCalendar<ScheduleModel>(
                                firstDay: DateTime.utc(2024, 1, 1),
                                lastDay: DateTime.utc(2030, 12, 31),
                                focusedDay: _focusedDay,
                                selectedDayPredicate: (day) =>
                                    isSameDay(selectedDay, day),
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
                                eventLoader: (day) =>
                                    byDate[_dateOnly(day)] ?? const [],
                                availableGestures:
                                    AvailableGestures.horizontalSwipe,
                                headerStyle: HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                  headerPadding:
                                      const EdgeInsets.only(bottom: 8),
                                  headerMargin:
                                      const EdgeInsets.only(bottom: 4),
                                  titleTextStyle:
                                      textTheme.bodyLarge!.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  leftChevronMargin: EdgeInsets.zero,
                                  rightChevronMargin: EdgeInsets.zero,
                                  leftChevronPadding:
                                      const EdgeInsets.all(4),
                                  rightChevronPadding:
                                      const EdgeInsets.all(4),
                                  leftChevronIcon: const Icon(
                                    Icons.chevron_left_rounded,
                                    color: AppColors.textPrimary,
                                    size: 20,
                                  ),
                                  rightChevronIcon: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textPrimary,
                                    size: 20,
                                  ),
                                ),
                                daysOfWeekStyle: DaysOfWeekStyle(
                                  weekdayStyle:
                                      textTheme.labelSmall!.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                  weekendStyle:
                                      textTheme.labelSmall!.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.holiday,
                                  ),
                                ),
                                calendarStyle: CalendarStyle(
                                  outsideDaysVisible: false,
                                  cellMargin: EdgeInsets.zero,
                                  cellPadding: EdgeInsets.zero,
                                  markersMaxCount: 0,
                                  holidayDecoration: const BoxDecoration(),
                                  todayDecoration: const BoxDecoration(),
                                  selectedDecoration: const BoxDecoration(),
                                  defaultTextStyle:
                                      textTheme.labelSmall!.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  weekendTextStyle:
                                      textTheme.labelSmall!.copyWith(
                                    color: AppColors.holiday,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  holidayTextStyle:
                                      textTheme.labelSmall!.copyWith(
                                    color: AppColors.holiday,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                holidayPredicate: KoreanHolidays.isHoliday,
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, day, events) =>
                                      const SizedBox.shrink(),
                                  defaultBuilder: (context, day, focused) {
                                    return _DayCell(
                                      day: day,
                                      events: byDate[_dateOnly(day)] ??
                                          const [],
                                      isSelected: false,
                                      isToday: false,
                                    );
                                  },
                                  todayBuilder: (context, day, focused) {
                                    return _DayCell(
                                      day: day,
                                      events: byDate[_dateOnly(day)] ??
                                          const [],
                                      isSelected: false,
                                      isToday: true,
                                    );
                                  },
                                  selectedBuilder: (context, day, focused) {
                                    return _DayCell(
                                      day: day,
                                      events: byDate[_dateOnly(day)] ??
                                          const [],
                                      isSelected: true,
                                      isToday: isSameDay(
                                        day,
                                        KstDateTime.now(),
                                      ),
                                    );
                                  },
                                  holidayBuilder: (context, day, focused) {
                                    return _DayCell(
                                      day: day,
                                      events: byDate[_dateOnly(day)] ??
                                          const [],
                                      isSelected:
                                          isSameDay(selectedDay, day),
                                      isToday: isSameDay(
                                        day,
                                        KstDateTime.now(),
                                      ),
                                    );
                                  },
                                ),
                                onDaySelected: (day, focusedDay) {
                                  final next = _dateOnly(day);
                                  // 선택 하이라이트만 즉시 갱신 (전체 탭 setState 회피)
                                  if (!isSameDay(_selectedDay.value, next)) {
                                    _selectedDay.value = next;
                                    widget.onSelectedDayChanged?.call(next);
                                  }
                                  if (_focusedDay.year != focusedDay.year ||
                                      _focusedDay.month != focusedDay.month) {
                                    setState(() => _focusedDay = focusedDay);
                                  }
                                },
                                onPageChanged: (focusedDay) {
                                  setState(() => _focusedDay = focusedDay);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                ValueListenableBuilder<DateTime>(
                  valueListenable: _selectedDay,
                  builder: (context, selectedDay, _) {
                    final selected = byDate[_dateOnly(selectedDay)] ??
                        const <ScheduleModel>[];
                    final workerCount =
                        selected.map((s) => s.workerId).toSet().length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                dayTitleFmt.format(selectedDay),
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: KoreanHolidays.isRedDay(selectedDay)
                                      ? AppColors.holiday
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (selected.isNotEmpty)
                              Text(
                                '근무 $workerCount명',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textCaption,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        if (KoreanHolidays.nameOf(selectedDay)
                            case final holidayName?)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              holidayName,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.holiday,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (selected.isEmpty)
                          AppCard(
                            child: Text(
                              '이 날짜에 배정된 근무가 없습니다.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        else
                          for (final group in _groupByShiftTime(selected))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ShiftGroupCard(
                                schedules: group,
                                roomId: widget.room.id,
                                store: store,
                                timeFmt: timeFmt,
                                currentUserId: uid,
                                canSeeAllSwaps: canSeeAllSwaps,
                              ),
                            ),
                      ],
                    );
                  },
                ),
              ],
        );

        if (widget.embedded) return content;

        return ColoredBox(
          color: Colors.white,
          child: ScrollablePageBody(
            top: false,
            bottom: false,
            child: content,
          ),
        );
      },
    );
  }

  /// 같은 출퇴근 시각 + 같은 확인/결근 상태끼리만 묶음
  static List<List<ScheduleModel>> _groupByShiftTime(
    List<ScheduleModel> schedules,
  ) {
    final map = <String, List<ScheduleModel>>{};
    for (final s in schedules) {
      final statusKey = s.isAbsent
          ? 'absent'
          : (s.isConfirmed ? 'confirmed' : 'pending');
      final key =
          '${s.startTime.hour}:${s.startTime.minute}-'
          '${s.endTime.hour}:${s.endTime.minute}|$statusKey';
      map.putIfAbsent(key, () => []).add(s);
    }
    final groups = map.values.toList();
    groups.sort((a, b) {
      final byTime = a.first.startTime.compareTo(b.first.startTime);
      if (byTime != 0) return byTime;
      int rank(ScheduleModel s) {
        if (s.isAbsent) return 2;
        if (s.isConfirmed) return 1;
        return 0;
      }
      return rank(a.first).compareTo(rank(b.first));
    });
    return groups;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.events,
    required this.isSelected,
    required this.isToday,
  });

  final DateTime day;
  final List<ScheduleModel> events;
  final bool isSelected;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final isRed = KoreanHolidays.isRedDay(day);
    final hasAssigned = events.any((e) => !e.isAbsent);

    final Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isRed) {
      textColor = AppColors.holiday;
    } else {
      textColor = AppColors.textPrimary;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppColors.primary : null,
          ),
          child: Text(
            '${day.day}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 14,
                  height: 1,
                  color: textColor,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 3),
        // 오늘(현재 날짜)에는 근무 점 표시 안 함
        SizedBox(
          width: 5,
          height: 5,
          child: hasAssigned && !isToday
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.45)
                        : AppColors.secondary,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

class _ShiftGroupCard extends StatelessWidget {
  const _ShiftGroupCard({
    required this.schedules,
    required this.roomId,
    required this.store,
    required this.timeFmt,
    this.currentUserId,
    this.canSeeAllSwaps = false,
  });

  final List<ScheduleModel> schedules;
  final String roomId;
  final MockStore store;
  final DateFormat timeFmt;
  final String? currentUserId;
  final bool canSeeAllSwaps;

  @override
  Widget build(BuildContext context) {
    final first = schedules.first;
    final names = schedules
        .map((s) => store.memberDisplayName(roomId, s.workerId))
        .toList()
      ..sort();
    final allAbsent = schedules.every((s) => s.isAbsent);
    final allConfirmed =
        !allAbsent && schedules.every((s) => s.isConfirmed);
    final badgeColor = allAbsent
        ? AppColors.holiday
        : allConfirmed
            ? AppColors.success
            : AppColors.warning;
    final badgeLabel = allAbsent
        ? '결근'
        : allConfirmed
            ? '확인 완료'
            : '확인 대기';

    ShiftSwapRequest? visibleSwap;
    for (final s in schedules) {
      final swap = store.openSwapForSchedule(s.id);
      if (swap == null) continue;
      final canSee = canSeeAllSwaps ||
          (currentUserId != null &&
              (swap.fromWorkerId == currentUserId ||
                  swap.toWorkerId == currentUserId));
      if (canSee) {
        visibleSwap = swap;
        break;
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  names.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              if (visibleSwap != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '대타 요청 중',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${timeFmt.format(first.startTime)} ~ '
            '${timeFmt.format(first.endTime)}'
            '${schedules.length > 1 ? ' · ${schedules.length}명' : ''}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textCaption,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (visibleSwap != null) ...[
            const SizedBox(height: 6),
            Text(
              '${visibleSwap.status.labelKo} · '
              '${store.memberDisplayName(roomId, visibleSwap.fromWorkerId)}'
              ' → ${store.memberDisplayName(roomId, visibleSwap.toWorkerId)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
