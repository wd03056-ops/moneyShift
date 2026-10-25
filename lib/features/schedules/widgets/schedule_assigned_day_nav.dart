import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_colors.dart';

/// 달력 상세 카드 좌우 — 배정일 사이를 넘기는 화살표 래퍼
///
/// [assignedDays]가 2일 이상일 때만 화살표를 표시하고,
/// 카드 세로 중앙에 맞춘다.
class ScheduleAssignedDayNav extends StatelessWidget {
  const ScheduleAssignedDayNav({
    super.key,
    required this.selectedDay,
    required this.assignedDays,
    required this.onGoTo,
    required this.child,
  });

  final DateTime selectedDay;

  /// 근무가 있는 날짜 목록 (정렬되어 있지 않아도 됨)
  final List<DateTime> assignedDays;

  final ValueChanged<DateTime> onGoTo;
  final Widget child;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final days = assignedDays.map(_dateOnly).toSet().toList()
      ..sort((a, b) => a.compareTo(b));
    final selected = _dateOnly(selectedDay);
    final dayIndex = days.indexWhere((d) => isSameDay(d, selected));

    DateTime? prevDay;
    DateTime? nextDay;
    if (dayIndex >= 0) {
      if (dayIndex > 0) prevDay = days[dayIndex - 1];
      if (dayIndex < days.length - 1) nextDay = days[dayIndex + 1];
    } else if (days.isNotEmpty) {
      for (final d in days.reversed) {
        if (d.isBefore(selected)) {
          prevDay = d;
          break;
        }
      }
      for (final d in days) {
        if (d.isAfter(selected)) {
          nextDay = d;
          break;
        }
      }
    }

    if (days.length <= 1) return child;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '이전 배정일',
          onPressed: prevDay != null ? () => onGoTo(prevDay!) : null,
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 32,
            color:
                prevDay != null ? AppColors.textPrimary : AppColors.border,
          ),
        ),
        Expanded(child: child),
        IconButton(
          tooltip: '다음 배정일',
          onPressed: nextDay != null ? () => onGoTo(nextDay!) : null,
          icon: Icon(
            Icons.chevron_right_rounded,
            size: 32,
            color:
                nextDay != null ? AppColors.textPrimary : AppColors.border,
          ),
        ),
      ],
    );
  }
}
