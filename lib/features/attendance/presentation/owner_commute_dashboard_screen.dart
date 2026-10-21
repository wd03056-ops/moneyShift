import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/time/kst_date_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_store.dart';
import '../../../models/models.dart';
import 'commute_correction_sheet.dart';
import 'commute_row_status.dart';

/// 사장님용 오늘 출·퇴근 현황 대시보드 (`/commute-history`)
class OwnerCommuteDashboardScreen extends StatelessWidget {
  const OwnerCommuteDashboardScreen({
    super.key,
    required this.roomId,
  });

  final String roomId;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');

    return ListenableBuilder(
      listenable: MockStore.instance,
      builder: (context, _) {
        final store = MockStore.instance;
        final room = store.rooms[roomId];
        if (room == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('출·퇴근 현황')),
            body: const Center(child: Text('매장을 찾을 수 없습니다.')),
          );
        }

        final rows = _buildRows(store, roomId);
        final summary = _Summary.fromRows(rows);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('출·퇴근 현황'),
            surfaceTintColor: Colors.transparent,
          ),
          body: ScrollablePageBody(
            top: false,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${room.name} · 오늘 ${DateFormat('M월 d일', 'ko_KR').format(KstDateTime.today())}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 12),
                _SummaryHeader(summary: summary),
                const SizedBox(height: 20),
                Text(
                  '오늘의 직원 현황',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  AppCard(
                    child: Text(
                      '오늘 배정된 근무가 없습니다.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  )
                else
                  for (final row in rows) ...[
                    _EmployeeCommuteCard(
                      row: row,
                      timeFmt: timeFmt,
                      onTap: () => CommuteCorrectionSheet.show(
                        context,
                        roomId: roomId,
                        row: row,
                      ),
                      onMarkAbsent: row.canMarkAbsent
                          ? () => _markAbsent(context, row)
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markAbsent(BuildContext context, CommuteEmployeeRow row) async {
    final sid = row.schedule?.id;
    if (sid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('결근 처리'),
        content: Text(
          '${row.displayName}님을 결근 처리할까요?\n'
          '처리 후 해당 직원에게 알림이 전송됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.holiday,
              foregroundColor: Colors.white,
            ),
            child: const Text('결근 처리'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      MockStore.instance.markScheduleAbsent(sid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${row.displayName}님을 결근 처리했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static List<CommuteEmployeeRow> _buildRows(MockStore store, String roomId) {
    final schedules = store.todayAssignedSchedules(roomId);
    final byWorker = <String, ScheduleModel>{};
    for (final s in schedules) {
      final prev = byWorker[s.workerId];
      if (prev == null || s.startTime.isBefore(prev.startTime)) {
        byWorker[s.workerId] = s;
      }
    }

    final now = KstDateTime.now();
    final rows = <CommuteEmployeeRow>[];
    for (final e in byWorker.entries) {
      final workerId = e.key;
      final schedule = e.value;
      final name = store.memberDisplayName(roomId, workerId);
      final clockIn = store.todayClockIn(roomId, workerId);
      final clockOut = store.todayClockOut(roomId, workerId);
      final pending = store.pendingCorrectionForWorkerToday(
        roomId: roomId,
        workerId: workerId,
      );
      final status = CommuteRowStatus.resolve(
        schedule: schedule,
        clockIn: clockIn,
        clockOut: clockOut,
        now: now,
      );
      rows.add(
        CommuteEmployeeRow(
          workerId: workerId,
          displayName: name,
          schedule: schedule,
          clockIn: clockIn,
          clockOut: clockOut,
          status: status,
          pendingCorrection: pending,
        ),
      );
    }
    rows.sort((a, b) {
      final as = a.schedule?.startTime;
      final bs = b.schedule?.startTime;
      if (as == null || bs == null) return 0;
      return as.compareTo(bs);
    });
    return rows;
  }
}

class CommuteEmployeeRow {
  const CommuteEmployeeRow({
    required this.workerId,
    required this.displayName,
    required this.schedule,
    required this.clockIn,
    required this.clockOut,
    required this.status,
    this.pendingCorrection,
  });

  final String workerId;
  final String displayName;
  final ScheduleModel? schedule;
  final AttendanceLogModel? clockIn;
  final AttendanceLogModel? clockOut;
  final CommuteRowStatus status;
  final CommuteCorrectionRequest? pendingCorrection;

  bool get canMarkAbsent =>
      status == CommuteRowStatus.noShow &&
      schedule != null &&
      !schedule!.isAbsent &&
      pendingCorrection == null;
}

class _Summary {
  const _Summary({
    required this.total,
    required this.present,
    required this.lateOrWaiting,
    required this.absentOrMissing,
  });

  final int total;
  final int present;
  final int lateOrWaiting;
  final int absentOrMissing;

  factory _Summary.fromRows(List<CommuteEmployeeRow> rows) {
    var present = 0;
    var lateOrWaiting = 0;
    var absentOrMissing = 0;
    for (final r in rows) {
      switch (r.status) {
        case CommuteRowStatus.working:
        case CommuteRowStatus.clockedOut:
          present++;
          break;
        case CommuteRowStatus.late:
        case CommuteRowStatus.waiting:
          lateOrWaiting++;
          break;
        case CommuteRowStatus.absent:
        case CommuteRowStatus.noShow:
          absentOrMissing++;
          break;
      }
    }
    return _Summary(
      total: rows.length,
      present: present,
      lateOrWaiting: lateOrWaiting,
      absentOrMissing: absentOrMissing,
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.summary});

  final _Summary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: '전체',
            value: '${summary.total}',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: '출근',
            value: '${summary.present}',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: '지각/대기',
            value: '${summary.lateOrWaiting}',
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: '미출근',
            value: '${summary.absentOrMissing}',
            color: AppColors.holiday,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCommuteCard extends StatefulWidget {
  const _EmployeeCommuteCard({
    required this.row,
    required this.timeFmt,
    required this.onTap,
    this.onMarkAbsent,
  });

  final CommuteEmployeeRow row;
  final DateFormat timeFmt;
  final VoidCallback onTap;
  final VoidCallback? onMarkAbsent;

  @override
  State<_EmployeeCommuteCard> createState() => _EmployeeCommuteCardState();
}

class _EmployeeCommuteCardState extends State<_EmployeeCommuteCard> {
  bool _absentBusy = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final schedule = row.schedule;
    final initial =
        row.displayName.isNotEmpty ? row.displayName.characters.first : '?';

    return AppCard(
      onTap: row.pendingCorrection != null ? null : widget.onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accentMuted,
                foregroundColor: Colors.white,
                child: Text(
                  initial,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      schedule == null
                          ? '근무 미배정'
                          : '${widget.timeFmt.format(schedule.startTime)} ~ '
                              '${widget.timeFmt.format(schedule.endTime)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: row.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimeCell(
                  label: '출근',
                  value: row.clockIn == null
                      ? '-'
                      : widget.timeFmt.format(row.clockIn!.timestamp),
                ),
              ),
              Expanded(
                child: _TimeCell(
                  label: '퇴근',
                  value: row.clockOut == null
                      ? '-'
                      : widget.timeFmt.format(row.clockOut!.timestamp),
                ),
              ),
            ],
          ),
          if (row.pendingCorrection != null) ...[
            const SizedBox(height: 8),
            Text(
              '근태 수정 승인 대기 중',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          if (widget.onMarkAbsent != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: _absentBusy
                    ? null
                    : () async {
                        setState(() => _absentBusy = true);
                        try {
                          widget.onMarkAbsent!();
                        } finally {
                          if (mounted) setState(() => _absentBusy = false);
                        }
                      },
                child: _absentBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('결근 처리'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textCaption,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CommuteRowStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.labelKo,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: status.fgColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
