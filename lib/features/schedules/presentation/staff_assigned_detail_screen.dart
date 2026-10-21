import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/calendar/korean_holidays.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/kst_date_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../models/models.dart';
import '../schedule_store.dart';
import '../widgets/pay_breakdown_view.dart';
import '../widgets/pay_disclaimer_caption.dart';

/// 배정된 근무 단위(개별·기간) 전용 상세보기 — 내 근무표와 분리
class StaffAssignedDetailScreen extends StatefulWidget {
  const StaffAssignedDetailScreen({
    super.key,
    required this.schedules,
  });

  /// 한 배정 단위(기간 묶음 또는 단건)
  final List<ScheduleModel> schedules;

  @override
  State<StaffAssignedDetailScreen> createState() =>
      _StaffAssignedDetailScreenState();
}

class _StaffAssignedDetailScreenState extends State<StaffAssignedDetailScreen> {
  static const double _headerH = 44;
  static const double _dowH = 20;

  late DateTime _focusedDay;
  late final Set<String> _assignedKeys;
  late final List<ScheduleModel> _sorted;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _dateKey(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(_dateOnly(d));

  bool _isAssignedDay(DateTime day) =>
      _assignedKeys.contains(_dateKey(_dateOnly(day)));

  @override
  void initState() {
    super.initState();
    _sorted = [...widget.schedules]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    _assignedKeys = {
      for (final s in _sorted) s.date.isNotEmpty ? s.date : _dateKey(s.startTime),
    };
    _focusedDay = _dateOnly(_sorted.first.startTime);
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
  }) {
    final textTheme = Theme.of(context).textTheme;
    final isRed = KoreanHolidays.isRedDay(day);
    final isToday = isSameDay(day, KstDateTime.now());
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${day.day}',
          style: textTheme.labelSmall?.copyWith(
            fontSize: 14,
            height: 1.1,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
            color: isRed ? AppColors.holiday : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        // 오늘(현재 날짜)에는 근무 점 표시 안 함
        SizedBox(
          width: 5,
          height: 5,
          child: assigned && !isToday
              ? DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondary,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final timeFmt = DateFormat('HH:mm');
    final shortDayFmt = DateFormat('M/d');
    final currency = NumberFormat('#,###');

    return ListenableBuilder(
      listenable: ScheduleStore.listenable,
      builder: (context, _) {
        // 최신 상태 반영 (확인 후 등)
        final live = _sorted
            .map((s) {
              final found = ScheduleStore.forRoom(s.roomId)
                  .where((x) => x.id == s.id);
              return found.isEmpty ? s : found.first;
            })
            .toList();
        final sample = live.first;
        final isPeriod = live.length > 1 &&
            sample.isPeriodBatch &&
            sample.assignmentBatchId != null;
        final totalPay = live.fold<int>(
          0,
          (sum, s) => sum + (s.estimatedPay ?? 0),
        );
        final allConfirmed = live.every((s) => s.isConfirmed);
        final anyAbsent = live.any((s) => s.isAbsent);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Text('상세보기'),
          ),
          body: FixedBottomPage(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            bottom: allConfirmed || anyAbsent
                ? null
                : StickyActionBar(
                    safeAreaBottom: true,
                    elevated: true,
                    children: [
                      StickyActionButton(
                        label: '확인했습니다',
                        variant: StickyActionVariant.filled,
                        onPressed: () {
                          ScheduleStore.confirm(sample.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('근무표를 확인했습니다.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          Navigator.of(context).pop(true);
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
                const SizedBox(height: 6),
                Text(
                  isPeriod
                      ? '${shortDayFmt.format(live.first.startTime)} ~ '
                          '${shortDayFmt.format(live.last.startTime)}'
                      : DateFormat('M월 d일 (E)', 'ko_KR')
                          .format(sample.startTime),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${timeFmt.format(sample.startTime)} ~ '
                  '${timeFmt.format(sample.endTime)}'
                  ' · ${live.length}일',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Badge(
                      label: allConfirmed ? '확인 완료' : '확인 대기',
                      color: allConfirmed
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    if (sample.includeWeeklyHoliday)
                      const _Badge(
                        label: '주휴수당',
                        color: AppColors.secondary,
                      ),
                    if (sample.includeOvertimeNight)
                      const _Badge(
                        label: '연장수당',
                        color: AppColors.warning,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
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
                          child: TableCalendar<ScheduleModel>(
                            firstDay: DateTime.utc(2024, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (_) => false,
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
                            availableGestures:
                                AvailableGestures.horizontalSwipe,
                            onDaySelected: null,
                            onPageChanged: (focused) {
                              setState(() => _focusedDay = focused);
                            },
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
                              selectedDecoration: BoxDecoration(),
                              todayDecoration: BoxDecoration(),
                            ),
                            calendarBuilders: CalendarBuilders(
                              defaultBuilder: (context, day, focused) =>
                                  _dayCell(
                                    context,
                                    day,
                                    assigned: _isAssignedDay(day),
                                  ),
                              todayBuilder: (context, day, focused) =>
                                  _dayCell(
                                    context,
                                    day,
                                    assigned: _isAssignedDay(day),
                                  ),
                              holidayBuilder: (context, day, focused) =>
                                  _dayCell(
                                    context,
                                    day,
                                    assigned: _isAssignedDay(day),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPeriod
                            ? '${shortDayFmt.format(live.first.startTime)} ~ '
                                '${shortDayFmt.format(live.last.startTime)}'
                            : DateFormat('M월 d일 (E)', 'ko_KR')
                                .format(sample.startTime),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${timeFmt.format(sample.startTime)} ~ '
                        '${timeFmt.format(sample.endTime)}'
                        ' · ${live.length}일',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (sample.note != null &&
                          sample.note!.isNotEmpty &&
                          sample.note != '근무 배정') ...[
                        const SizedBox(height: 10),
                        Text(
                          sample.note!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textCaption,
                          ),
                        ),
                      ],
                      if (!anyAbsent && sample.estimatedPay != null) ...[
                        const SizedBox(height: 14),
                        PayBreakdownView(
                          schedule: sample,
                          titlePrefix: live.length > 1
                              ? '1일 예상 급여'
                              : '예상 급여',
                        ),
                        if (live.length > 1) ...[
                          const SizedBox(height: 10),
                          Text(
                            '기간 합계 ${currency.format(totalPay)}원 '
                            '(${live.length}일)',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                        const PayDisclaimerCaption(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

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
