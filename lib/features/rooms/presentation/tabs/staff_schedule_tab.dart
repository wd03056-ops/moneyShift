import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/calendar/korean_holidays.dart';
import '../../../../core/calendar/snappy_calendar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/kst_date_time.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../mock/app_listenables.dart';
import '../../../../mock/mock_session.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../schedules/presentation/shift_swap_request_sheet.dart';
import '../../../schedules/schedule_store.dart';
import '../../../schedules/widgets/pay_breakdown_view.dart';
import '../../../schedules/widgets/pay_disclaimer_caption.dart';
import '../../../schedules/widgets/pending_change_card.dart';

/// 알바 2탭 — 달력 기반 내 근무표
///
/// 배정표에서 확인([isConfirmed])한 근무만 표시합니다.
class StaffScheduleTab extends StatefulWidget {
  const StaffScheduleTab({
    super.key,
    required this.room,
  });

  final RoomModel room;

  @override
  State<StaffScheduleTab> createState() => _StaffScheduleTabState();
}

class _StaffScheduleTabState extends State<StaffScheduleTab> {
  late DateTime _focusedDay;
  late final ValueNotifier<DateTime> _selectedDay;

  static const double _headerH = 44;
  static const double _dowH = 20;

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

  List<ScheduleModel> _eventsForDay(
    List<ScheduleModel> all,
    DateTime day,
  ) {
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

  /// 달력 높이 (해당 월 주 수만 반영 — 빈 6주차 여백 제거)
  double _calendarHeight(double rowHeight, DateTime focused) =>
      _headerH + _dowH + (rowHeight * _weeksInMonth(focused)) + 8;

  /// 일요일 시작 기준 해당 월에 표시되는 주 수
  static int _weeksInMonth(DateTime focused) {
    final first = DateTime(focused.year, focused.month, 1);
    final last = DateTime(focused.year, focused.month + 1, 0);
    final startOffset = first.weekday % 7; // Sun=0 … Sat=6
    return ((startOffset + last.day + 6) ~/ 7).clamp(4, 6);
  }

  @override
  Widget build(BuildContext context) {
    final uid = MockSession.instance.requireUid;
    final timeFmt = DateFormat('HH:mm');

    return ListenableBuilder(
      listenable: AppListenables.sessionAndStore,
      builder: (context, _) {
        final textTheme = Theme.of(context).textTheme;
        // 확인 완료된 근무만 내 근무표에 표시 (배정표에서 확인 후 등록)
        final mine = ScheduleStore.forWorker(widget.room.id, uid)
            .where((s) => s.isConfirmed && !s.isAbsent)
            .toList();
        final changeRequests =
            ScheduleStore.pendingOwnerChanges(widget.room.id, uid);
        final byDate = _groupByDate(mine);
        final store = MockStore.instance;
        final totalPay = store.actualPayTotalForWorker(widget.room.id, uid);
        final currency = NumberFormat('#,###');

        return ScrollablePageBody(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '내 근무표',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '배정된 근무를 확인하면 여기에 등록됩니다.',
                style: textTheme.bodyMedium,
              ),
              if (changeRequests.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (var i = 0; i < changeRequests.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  PendingChangeCard(schedule: changeRequests[i]),
                ],
              ],
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
                                headerMargin: const EdgeInsets.only(bottom: 4),
                                titleTextStyle: textTheme.bodyLarge!.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                leftChevronMargin: EdgeInsets.zero,
                                rightChevronMargin: EdgeInsets.zero,
                                leftChevronPadding: const EdgeInsets.all(4),
                                rightChevronPadding: const EdgeInsets.all(4),
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
                                dowBuilder: (context, day) {
                                  final label =
                                      DateFormat.E('ko_KR').format(day);
                                  final isSunday =
                                      day.weekday == DateTime.sunday;
                                  return Center(
                                    child: Text(
                                      label,
                                      style: textTheme.labelSmall!.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isSunday
                                            ? AppColors.holiday
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  );
                                },
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
                                if (!isSameDay(_selectedDay.value, next)) {
                                  _selectedDay.value = next;
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
              Row(
                children: [
                  Text(
                    '현재 총 급여',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textCaption,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${currency.format(totalPay)}원',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<DateTime>(
                valueListenable: _selectedDay,
                builder: (context, selectedDay, _) {
                  final selected = _eventsForDay(mine, selectedDay);
                  if (selected.isEmpty) {
                    return AppCard(
                      child: Text(
                        '이 날짜에 확인된 근무가 없습니다.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final s in selected)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ScheduleDetailCard(
                            schedule: s,
                            timeFmt: timeFmt,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
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
            // 선택일만 차콜/네이비 원형 강조
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
        // 오늘(현재 날짜)에는 근무 점 표시 안 함 — 선택 원만 강조
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

class _ScheduleDetailCard extends StatelessWidget {
  const _ScheduleDetailCard({
    required this.schedule,
    required this.timeFmt,
  });

  final ScheduleModel schedule;
  final DateFormat timeFmt;

  /// 대타 승인 note에 요청자 이름이 없으면 승인된 swap에서 보강
  String _swapNoteLabel(ScheduleModel s) {
    final note = s.note ?? '';
    if (!note.startsWith('대타 승인')) return note;
    if (note.contains('요청자')) return note;

    final store = MockStore.instance;
    ShiftSwapRequest? approved;
    for (final swap in store.shiftSwaps.values) {
      if (swap.scheduleId == s.id &&
          swap.status == ShiftSwapStatus.approved) {
        approved = swap;
        break;
      }
    }
    if (approved == null) return note;
    final fromName =
        store.memberDisplayName(s.roomId, approved.fromWorkerId);
    final reason = approved.reason.trim().isEmpty
        ? null
        : approved.reason.trim();
    if (reason != null) {
      return '대타 승인 · 요청자 $fromName · 사유: $reason';
    }
    return '대타 승인 · 요청자 $fromName';
  }

  @override
  Widget build(BuildContext context) {
    final s = schedule;
    final uid = MockSession.instance.currentUser?.uid;
    final swap = MockStore.instance.openSwapForSchedule(s.id);
    final isMine = uid != null && s.workerId == uid;
    final today = DateTime(
      KstDateTime.now().year,
      KstDateTime.now().month,
      KstDateTime.now().day,
    );
    final scheduleDay = DateTime(
      s.startTime.year,
      s.startTime.month,
      s.startTime.day,
    );
    final canRequest =
        isMine && swap == null && !s.isAbsent && !scheduleDay.isBefore(today);

    final textTheme = Theme.of(context).textTheme;
    final muted = swap != null || s.isAbsent;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${timeFmt.format(s.startTime)} ~ ${timeFmt.format(s.endTime)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: muted ? AppColors.textCaption : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
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
              if (s.status != ScheduleStatus.normal && !s.isChangeRequested)
                _StatusBadge(
                  label: s.status.labelKo,
                  color: AppColors.secondary,
                ),
              if (swap != null)
                _StatusBadge(
                  label: '대타 요청 중',
                  color: AppColors.warning,
                ),
            ],
          ),
          if (s.isChangeRequested && s.pendingChange != null) ...[
            const SizedBox(height: 10),
            Text(
              '${timeFmt.format(s.startTime)} ➔ '
              '${timeFmt.format(s.pendingChange!.startTime)}'
              '  ·  '
              '${timeFmt.format(s.endTime)} ➔ '
              '${timeFmt.format(s.pendingChange!.endTime)}',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (s.isAbsent) ...[
            const SizedBox(height: 10),
            Text(
              '사장님이 결근 처리한 근무입니다.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.holiday,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (swap != null) ...[
            const SizedBox(height: 10),
            Text(
              '${swap.status.labelKo} · '
              '${MockStore.instance.memberDisplayName(s.roomId, swap.toWorkerId)}에게 요청',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (s.note != null &&
              s.note!.isNotEmpty &&
              s.note != '근무 배정') ...[
            const SizedBox(height: 10),
            Text(
              _swapNoteLabel(s),
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textCaption,
              ),
            ),
          ],
          if (!s.isAbsent) ...[
            Builder(
              builder: (context) {
                final actual = MockStore.instance.actualPayEstimateOnDate(
                  s.roomId,
                  s.workerId,
                  s.startTime,
                );
                if (actual != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 14),
                      PayBreakdownView(
                        schedule: s,
                        estimateOverride: actual,
                        titlePrefix: '실근무 급여',
                      ),
                      const PayDisclaimerCaption(),
                    ],
                  );
                }
                if (s.estimatedPay != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 14),
                      PayBreakdownView(schedule: s),
                      const PayDisclaimerCaption(),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
          if (canRequest) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () async {
                  final ok = await showShiftSwapRequestSheet(
                    context: context,
                    schedule: s,
                  );
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('대타 요청을 보냈습니다.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('대타 요청하기'),
              ),
            ),
          ],
        ],
      ),
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
