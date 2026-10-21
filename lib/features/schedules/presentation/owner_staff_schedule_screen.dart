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
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';
import '../widgets/pay_breakdown_view.dart';
import '../widgets/pending_change_card.dart';
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

  static const double _headerH = 52;
  static const double _dowH = 22;

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
    return all.where((s) => s.date == key).toList();
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

  double _calendarHeight(double rowHeight) =>
      _headerH + _dowH + (rowHeight * 6);

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final dayTitleFmt = DateFormat('M월 d일 (E)', 'ko_KR');

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
                  '${widget.member.displayName} · ${widget.member.role.labelKo}',
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
                    final rowHeight =
                        (constraints.maxWidth / 7 * 0.68).clamp(28.0, 38.0);
                    final calH = _calendarHeight(rowHeight);

                    return AppCard(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
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
                                sixWeekMonthsEnforced: true,
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
                                  markersMaxCount: 1,
                                  markerSizeScale: 0.12,
                                  markersAnchor: 0.98,
                                  markerDecoration: const BoxDecoration(
                                    color: AppColors.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                  holidayDecoration: const BoxDecoration(),
                                  defaultTextStyle:
                                      textTheme.labelSmall!.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  weekendTextStyle:
                                      textTheme.labelSmall!.copyWith(
                                    color: AppColors.holiday,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  holidayTextStyle:
                                      textTheme.labelSmall!.copyWith(
                                    color: AppColors.holiday,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  todayDecoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  todayTextStyle:
                                      textTheme.labelSmall!.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  selectedDecoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  selectedTextStyle:
                                      textTheme.labelSmall!.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                holidayPredicate: KoreanHolidays.isHoliday,
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
                const SizedBox(height: 16),
                ValueListenableBuilder<DateTime>(
                  valueListenable: _selectedDay,
                  builder: (context, selectedDay, _) {
                    final selected =
                        _eventsForDay(schedules, selectedDay);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          dayTitleFmt.format(selectedDay),
                          style: textTheme.bodyLarge!.copyWith(
                            color: KoreanHolidays.isRedDay(selectedDay)
                                ? AppColors.holiday
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (selected.isEmpty)
                          AppCard(
                            child: Text(
                              '이 날짜에 배정된 근무가 없습니다.',
                              style: textTheme.bodyMedium,
                            ),
                          )
                        else
                          for (final s in selected)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                            Row(
                              children: [
                                if (s.isChangeRequested)
                                  const ChangeRequestedBadge()
                                else
                                  _StatusBadge(
                                    label: s.attendanceStatusLabel,
                                    color: s.isAbsent
                                        ? AppColors.holiday
                                        : s.isConfirmed
                                            ? AppColors.success
                                            : AppColors.warning,
                                  ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    OwnerChangeRequestSheet.show(
                                      context,
                                      schedule: s,
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                                        MockStore.instance
                                            .clearScheduleAbsent(s.id);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('결근 처리를 해제했습니다.'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      } else {
                                        MockStore.instance
                                            .markScheduleAbsent(s.id);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('결근 처리했습니다.'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('$e'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: s.isAbsent
                                        ? AppColors.textSecondary
                                        : AppColors.holiday,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    s.isAbsent ? '결근 해제' : '결근 처리',
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: s.isAbsent
                                          ? AppColors.textSecondary
                                          : AppColors.holiday,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${timeFmt.format(s.startTime)} ~ '
                              '${timeFmt.format(s.endTime)}',
                              style: textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                              ),
                            ),
                            if (s.isChangeRequested &&
                                s.pendingChange != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${timeFmt.format(s.startTime)} ➔ '
                                '${timeFmt.format(s.pendingChange!.startTime)}'
                                '  ·  '
                                '${timeFmt.format(s.endTime)} ➔ '
                                '${timeFmt.format(s.pendingChange!.endTime)}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (s.estimatedPay != null && !s.isAbsent) ...[
                              const SizedBox(height: 10),
                              PayBreakdownView(schedule: s),
                            ],
                            if (s.isAbsent) ...[
                              const SizedBox(height: 8),
                              Text(
                                '결근으로 처리되어 급여에 포함되지 않습니다.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.holiday,
                                ),
                              ),
                            ],
                                  ],
                                ),
                              ),
                            ),
                      ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

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
