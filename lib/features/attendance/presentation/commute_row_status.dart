import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/attendance_log_model.dart';
import '../../../models/schedule_model.dart';

enum CommuteRowStatus {
  waiting,
  working,
  clockedOut,
  late,
  noShow,
  absent;

  String get labelKo {
    switch (this) {
      case CommuteRowStatus.waiting:
        return '대기';
      case CommuteRowStatus.working:
        return '출근완료';
      case CommuteRowStatus.clockedOut:
        return '퇴근완료';
      case CommuteRowStatus.late:
        return '지각';
      case CommuteRowStatus.noShow:
        return '미출근';
      case CommuteRowStatus.absent:
        return '결근';
    }
  }

  Color get bgColor {
    switch (this) {
      case CommuteRowStatus.working:
      case CommuteRowStatus.clockedOut:
        return AppColors.success.withValues(alpha: 0.12);
      case CommuteRowStatus.late:
      case CommuteRowStatus.waiting:
        return AppColors.warning.withValues(alpha: 0.14);
      case CommuteRowStatus.noShow:
      case CommuteRowStatus.absent:
        return AppColors.holiday.withValues(alpha: 0.12);
    }
  }

  Color get fgColor {
    switch (this) {
      case CommuteRowStatus.working:
      case CommuteRowStatus.clockedOut:
        return AppColors.success;
      case CommuteRowStatus.late:
      case CommuteRowStatus.waiting:
        return const Color(0xFFB45309);
      case CommuteRowStatus.noShow:
      case CommuteRowStatus.absent:
        return AppColors.holiday;
    }
  }

  static CommuteRowStatus resolve({
    required ScheduleModel schedule,
    required AttendanceLogModel? clockIn,
    required AttendanceLogModel? clockOut,
    required DateTime now,
  }) {
    if (schedule.isAbsent) return CommuteRowStatus.absent;
    if (clockOut != null) return CommuteRowStatus.clockedOut;
    if (clockIn != null) {
      final lateGrace = schedule.startTime.add(const Duration(minutes: 10));
      if (clockIn.timestamp.isAfter(lateGrace)) {
        return CommuteRowStatus.late;
      }
      return CommuteRowStatus.working;
    }
    if (now.isAfter(schedule.startTime.add(const Duration(minutes: 10)))) {
      return CommuteRowStatus.noShow;
    }
    return CommuteRowStatus.waiting;
  }
}
