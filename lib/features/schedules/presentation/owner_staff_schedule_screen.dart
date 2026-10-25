import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/calendar/korean_holidays.dart';
import '../../../core/calendar/snappy_calendar.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/kst_date_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';
import '../widgets/schedule_assigned_day_nav.dart';
import '../widgets/schedule_day_detail_card.dart';
import 'create_schedule_screen.dart';
import 'owner_change_request_sheet.dart';

/// 사장 — 특정 직원의 근무표 조회
class OwnerStaffScheduleScreen extends StatefulWidget {
  const OwnerStaffScheduleScreen({
    super.key,
    required this.room,
    required this.member,
  });

  final RoomModel room;
  final RoomMemberModel member;

  @override
  State<OwnerStaffScheduleScreen> createState() =>
      _OwnerStaffScheduleScreenState();
}

class _OwnerStaffScheduleScreenState extends State<OwnerStaffScheduleScreen> {
  late DateTime _focusedDay;
  late final ValueNotifier<DateTime> _selectedDay;

  static const double _headerH = 44;
  static const double _dowH = 20;
  static const double _minRowHeight = 52;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _dateKey(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(_dateOnly(d));

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(KstDateTime.now());
    _focusedDay = today;
    _selectedDay = ValueNotifier(today);
  }

  @override
  void dispose() {
    _selectedDay.dispose();
    super.dispose();
  }

  List<ScheduleModel> _eventsForDay(List<ScheduleModel> all, DateTime day) {
    final key = _dateKey(day);
    return all.where((s) {
      if (s.date.isNotEmpty) return s.date == key;
      return _dateKey(s.startTime) == key;
    }).toList();
  }

  Map<DateTime, List<ScheduleModel>> _groupByDate(List<ScheduleModel> all) {
    final map = <DateTime, List<ScheduleModel>>{};
    for (final s in all) {
      final day = s.date.isNotEmpty
          ? () {
              final parts = s.date.split('-');
              if (parts.length != 3) return _dateOnly(s.startTime);
              return DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
            }()
          : _dateOnly(s.startTime);
      map.putIfAbsent(day, () => []).add(s);
    }
    return map;
  }

  double _calendarHeight(double rowHeight, DateTime focused) {
    final first = DateTime(focused.year, focused.month, 1);
    final last = DateTime(focused.year, focused.month + 1, 0);
    final startOffset = first.weekday % 7;
    final weeks = ((startOffset + last.day + 6) ~/ 7).clamp(4, 6);
    return _headerH + _dowH + (rowHeight * weeks) + 8;
  }

  Widget _ownerActions(BuildContext context, ScheduleModel s) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        TextButton(
          onPressed: () {
            OwnerChangeRequestSheet.show(context, schedule: s);
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            '일정 변경 요청',
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            try {
              if (s.isAbsent) {
                MockStore.instance.clearScheduleAbsent(s.id);
                showAppSnackBar(
                  context,
                  message: '결근 처리를 해제했습니다.',
                );
              } else {
                MockStore.instance.markScheduleAbsent(s.id);
                showAppSnackBar(
                  context,
                  message: '결근 처리했습니다.',
                );
              }
            } catch (e) {
              showAppSnackBar(context, message: '$e');
            }
          },
          style: TextButton.styleFrom(
            foregroundColor:
                s.isAbsent ? AppColors.textSecondary : AppColors.holiday,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            s.isAbsent ? '결근 해제' : '결근 처리',
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color:
                  s.isAbsent ? AppColors.textSecondary : AppColors.holiday,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MockStore.instance,
      builder: (context, _) {
        final textTheme = Theme.of(context).textTheme;
        final schedules = MockStore.instance.schedulesForWorker(
          widget.room.id,
          widget.member.userId,
        );
        final byDate = _groupByDate(schedules);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text('${widget.member.displayName} 근무표'),
            actions: [
              TextButton(
                onPressed: () {
                  AppNavigation.pushSingleTop(
                    name: AppRouteNames.createSchedule(widget.room.id),
                    stopAtNames: [
                      AppRouteNames.ownerStaffSchedule(
                        widget.room.id,
                        widget.member.userId,
                      ),
                      AppRouteNames.room(widget.room.id),
                    ],
                    builder: (_) => CreateScheduleScreen(
                      room: widget.room,
                      initialStaff: widget.member,
                    ),
                  );
                },
                child: const Text('배정'),
              ),
            ],
          ),
          body: ScrollablePageBody(
            top: false,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.member.displayName} · ${widget.member.roleLabel}',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '날짜를 선택하면 배정된 근무를 확인할 수 있어요',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final rowHeight = (constraints.maxWidth / 7 * 0.9)
                        .clamp(_minRowHeight, 60.0);
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
                                  canMarkersOverflow: false,
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
                                    final events =
                                        byDate[_dateOnly(day)] ?? const [];
                                    return _DayCell(
                                      day: day,
                                      isSelected: false,
                                      isToday: false,
                                      hasAssigned: events.isNotEmpty,
                                    );
                                  },
                                  todayBuilder: (context, day, focused) {
                                    final events =
                                        byDate[_dateOnly(day)] ?? const [];
                                    return _DayCell(
                                      day: day,
                                      isSelected: false,
                                      isToday: true,
                                      hasAssigned: events.isNotEmpty,
                                    );
                                  },
                                  selectedBuilder: (context, day, focused) {
                                    final events =
                                        byDate[_dateOnly(day)] ?? const [];
                                    return _DayCell(
                                      day: day,
                                      isSelected: true,
                                      isToday:
                                          isSameDay(day, KstDateTime.now()),
                                      hasAssigned: events.isNotEmpty,
                                    );
                                  },
                                  holidayBuilder: (context, day, focused) {
                                    final events =
                                        byDate[_dateOnly(day)] ?? const [];
                                    return _DayCell(
                                      day: day,
                                      isSelected:
                                          isSameDay(selectedDay, day),
                                      isToday:
                                          isSameDay(day, KstDateTime.now()),
                                      hasAssigned: events.isNotEmpty,
                                    );
                                  },
                                ),
                                onDaySelected: (day, focusedDay) {
                                  final next = _dateOnly(day);
                                  if (!isSameDay(
                                      _selectedDay.value, next)) {
                                    _selectedDay.value = next;
                                  }
                                  if (_focusedDay.year != focusedDay.year ||
                                      _focusedDay.month !=
                                          focusedDay.month) {
                                    setState(
                                        () => _focusedDay = focusedDay);
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
                const SizedBox(height: 20),
                ValueListenableBuilder<DateTime>(
                  valueListenable: _selectedDay,
                  builder: (context, selectedDay, _) {
                    void goTo(DateTime day) {
                      final next = _dateOnly(day);
                      _selectedDay.value = next;
                      if (_focusedDay.year != next.year ||
                          _focusedDay.month != next.month) {
                        setState(() => _focusedDay = next);
                      }
                    }

                    final selected = _eventsForDay(schedules, selectedDay);
                    final detail = selected.isEmpty
                        ? AppCard(
                            child: Text(
                              '이 날짜에 배정된 근무가 없습니다.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              for (final s in selected)
                                Padding(
                                  key: ValueKey('day-card-${s.id}'),
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ScheduleDayDetailCard(
                                    key: ValueKey(s.id),
                                    schedule: s,
                                    enableSwapRequest: false,
                                    footer: _ownerActions(context, s),
                                  ),
                                ),
                            ],
                          );

                    return ScheduleAssignedDayNav(
                      selectedDay: selectedDay,
                      assignedDays: byDate.keys.toList(),
                      onGoTo: goTo,
                      child: detail,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    this.hasAssigned = false,
  });

  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final bool hasAssigned;

  @override
  Widget build(BuildContext context) {
    final isRed = KoreanHolidays.isRedDay(day);

    final Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isRed) {
      textColor = AppColors.holiday;
    } else {
      textColor = AppColors.textPrimary;
    }

    return SizedBox(
      height: 52,
      child: Column(
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
              border: !isSelected && isToday
                  ? Border.all(color: AppColors.primary, width: 1.2)
                  : null,
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
          const SizedBox(height: 2),
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
      ),
    );
  }
}
