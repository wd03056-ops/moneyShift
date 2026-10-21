import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../calendar/korean_holidays.dart';
import '../calendar/snappy_calendar.dart';
import '../theme/app_colors.dart';
import '../time/kst_date_time.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 앱 캘린더와 동일한 표기의 날짜 선택 다이얼로그
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  Set<DateTime>? markedDays,
}) {
  var first = _dateOnly(firstDate);
  var last = _dateOnly(lastDate);
  var initial = _dateOnly(initialDate);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  return showDialog<DateTime>(
    context: context,
    useRootNavigator: true,
    animationStyle: SnappyCalendar.sheetAnimationStyle,
    builder: (ctx) => _AppDatePickerDialog(
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      markedDays: markedDays ?? const {},
    ),
  );
}

class _AppDatePickerDialog extends StatefulWidget {
  const _AppDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.markedDays,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Set<DateTime> markedDays;

  @override
  State<_AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<_AppDatePickerDialog> {
  static const double _headerH = 48;
  static const double _dowH = 22;
  // 일자(28) + 간격(2) + 점(5) + 여유 — overflow 방지
  static const double _rowH = 52;

  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late final Set<String> _markedKeys;

  static String _dateKey(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(_dateOnly(d));

  bool _isMarked(DateTime day) => _markedKeys.contains(_dateKey(day));

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(widget.initialDate);
    _focusedDay = _selectedDay;
    _markedKeys = {
      for (final d in widget.markedDays) _dateKey(d),
    };
  }

  int _weeksInMonth(DateTime focused) {
    final first = DateTime(focused.year, focused.month, 1);
    final last = DateTime(focused.year, focused.month + 1, 0);
    final startOffset = first.weekday % 7;
    return ((startOffset + last.day + 6) ~/ 7).clamp(4, 6);
  }

  double _calendarHeight(DateTime focused) =>
      _headerH + _dowH + (_rowH * _weeksInMonth(focused)) + 8;

  Widget _dayCell(
    BuildContext context, {
    required DateTime day,
    required bool isSelected,
    required bool isToday,
  }) {
    final isRed = KoreanHolidays.isRedDay(day);
    final hasMark = _isMarked(day);

    final Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isRed) {
      textColor = AppColors.holiday;
    } else {
      textColor = AppColors.textPrimary;
    }

    return SizedBox(
      height: _rowH,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
          const SizedBox(height: 2),
          SizedBox(
            width: 5,
            height: 5,
            child: hasMark && !isToday
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dayTitle = DateFormat('M월 d일 (E)', 'ko_KR').format(_selectedDay);
    final calH = _calendarHeight(_focusedDay);

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '날짜 선택',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dayTitle,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: KoreanHolidays.isRedDay(_selectedDay)
                    ? AppColors.holiday
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: calH,
              child: TableCalendar(
                firstDay: widget.firstDate,
                lastDay: widget.lastDate,
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },
                startingDayOfWeek: StartingDayOfWeek.sunday,
                locale: 'ko_KR',
                rowHeight: _rowH,
                daysOfWeekHeight: _dowH,
                sixWeekMonthsEnforced: false,
                shouldFillViewport: false,
                pageAnimationEnabled: SnappyCalendar.pageAnimationEnabled,
                pageAnimationDuration: SnappyCalendar.pageAnimationDuration,
                formatAnimationDuration:
                    SnappyCalendar.formatAnimationDuration,
                availableGestures: AvailableGestures.horizontalSwipe,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  headerPadding: const EdgeInsets.only(bottom: 8),
                  titleTextStyle: textTheme.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
                  weekdayStyle: textTheme.labelSmall!.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  weekendStyle: textTheme.labelSmall!.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.holiday,
                  ),
                ),
                holidayPredicate: KoreanHolidays.isHoliday,
                calendarStyle: const CalendarStyle(
                  outsideDaysVisible: false,
                  holidayDecoration: BoxDecoration(),
                  todayDecoration: BoxDecoration(),
                  selectedDecoration: BoxDecoration(),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focused) => _dayCell(
                    context,
                    day: day,
                    isSelected: false,
                    isToday: false,
                  ),
                  todayBuilder: (context, day, focused) => _dayCell(
                    context,
                    day: day,
                    isSelected: false,
                    isToday: true,
                  ),
                  selectedBuilder: (context, day, focused) => _dayCell(
                    context,
                    day: day,
                    isSelected: true,
                    isToday: isSameDay(day, KstDateTime.now()),
                  ),
                  holidayBuilder: (context, day, focused) => _dayCell(
                    context,
                    day: day,
                    isSelected: isSameDay(_selectedDay, day),
                    isToday: isSameDay(day, KstDateTime.now()),
                  ),
                ),
                onDaySelected: (selected, focused) {
                  final next = _dateOnly(selected);
                  setState(() {
                    _selectedDay = next;
                    if (_focusedDay.year != focused.year ||
                        _focusedDay.month != focused.month) {
                      _focusedDay = focused;
                    }
                  });
                },
                onPageChanged: (focused) {
                  setState(() => _focusedDay = focused);
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_selectedDay),
                  child: const Text('확인'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
