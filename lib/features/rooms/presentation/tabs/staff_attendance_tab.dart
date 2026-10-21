import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/navigation/app_route_names.dart';
import '../../../../core/permissions/location_disclosure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../core/widgets/sticky_action_button.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../../services/attendance_location_service.dart';
import '../../../attendance/presentation/commute_correction_review_dialog.dart';
import '../../../notices/presentation/notice_board_screen.dart';
import '../../../schedules/presentation/staff_assigned_schedule_screen.dart';
import '../../../schedules/schedule_store.dart';
import '../../../schedules/widgets/pending_change_card.dart';

/// 알바 1탭 — 출퇴근 (매장 GPS 100m 반경 검증)
class StaffAttendanceTab extends StatefulWidget {
  const StaffAttendanceTab({
    super.key,
    required this.room,
    required this.membership,
  });

  final RoomModel room;
  final RoomMemberModel membership;

  @override
  State<StaffAttendanceTab> createState() => _StaffAttendanceTabState();
}

class _StaffAttendanceTabState extends State<StaffAttendanceTab> {
  static const Color _pending = Color(0xFF8B95A1);
  static const Color _hint = Color(0xFF4E5968);

  /// 안내 문구 탭 시 버튼 라벨을 재출근하기/재퇴근하기로 전환
  bool _reclockLabels = false;
  bool _gpsChecking = false;

  final _locationService = const AttendanceLocationService();

  Future<void> _handleClock({
    required bool isClockIn,
    required RoomModel liveRoom,
    required bool isRe,
  }) async {
    if (_gpsChecking) return;
    setState(() => _gpsChecking = true);

    final store = MockStore.instance;
    try {
      if (!store.gpsBypassEnabled) {
        final disclosed = await LocationDisclosure.ensureAccepted(context);
        if (!disclosed || !mounted) return;
      }
      final check = await _locationService.checkWithinGeofence(
        storeLocation: liveRoom.location,
        radiusMeters: liveRoom.geofenceRadiusMeters,
        bypass: store.gpsBypassEnabled,
      );

      if (!mounted) return;

      if (!check.allowed) {
        final msg = check.errorMessage ??
            AttendanceLocationService.outOfRangeMessage;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('출퇴근 불가'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        return;
      }

      if (isClockIn) {
        store.clockIn(
          roomId: liveRoom.id,
          location: check.location,
          distanceFromStoreMeters: check.distanceMeters,
        );
      } else {
        store.clockOut(
          roomId: liveRoom.id,
          location: check.location,
          distanceFromStoreMeters: check.distanceMeters,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isClockIn
                ? (isRe ? '재출근이 완료되었습니다.' : '출근이 완료되었습니다.')
                : (isRe ? '재퇴근이 완료되었습니다.' : '퇴근이 완료되었습니다.'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('위치 확인에 실패했습니다: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _gpsChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final membership = widget.membership;
    final timeFmt = DateFormat('HH:mm');
    final dayFmt = DateFormat('M월 d일', 'ko_KR');
    final logFmt = DateFormat('M/d HH:mm:ss');

    return ListenableBuilder(
      listenable: MockStore.instance,
      builder: (context, _) {
        final store = MockStore.instance;
        final liveRoom = store.rooms[room.id] ?? room;
        final uid = membership.userId;
        final todaySchedule =
            store.todayScheduleForWorker(liveRoom.id, uid);
        final clockIn = store.todayClockIn(liveRoom.id, uid);
        final clockOut = store.todayClockOut(liveRoom.id, uid);
        final logs = store.attendanceForUser(liveRoom.id, uid);
        final todayLogs = store.attendanceToday(liveRoom.id, uid);

        final isWorking = store.isWorkingToday(liveRoom.id, uid);
        final hasClockedOutToday =
            store.hasClockedOutToday(liveRoom.id, uid);
        final scheduleConfirmed =
            store.hasConfirmedTodaySchedule(liveRoom.id, uid);
        // 오늘 배정 확인 후에만 출퇴근. 근무 중 → 퇴근만.
        // 퇴근 완료 후 → 안내 문구로 재출근 모드일 때만 다시 출근
        final isAbsentToday = todaySchedule?.isAbsent == true;
        final canClockIn = scheduleConfirmed &&
            !isAbsentToday &&
            !isWorking &&
            (!hasClockedOutToday || _reclockLabels);
        final canClockOut =
            scheduleConfirmed && !isAbsentToday && isWorking;

        final scheduledStart = todaySchedule?.startTime;
        final scheduledEnd = todaySchedule?.endTime;
        final pendingAll =
            ScheduleStore.pendingForWorker(liveRoom.id, uid);
        final changeRequests =
            ScheduleStore.pendingOwnerChanges(liveRoom.id, uid);
        final incomingSwaps =
            store.incomingShiftSwapsForWorker(liveRoom.id, uid);
        final unreadNotices = store.unreadNoticeCount(liveRoom.id, uid);

        final clockInLabel = canClockIn
            ? (_reclockLabels ? '재출근하기' : '출근하기')
            : (isWorking || clockIn != null)
                ? '출근 완료'
                : (_reclockLabels ? '재출근하기' : '출근하기');
        final clockOutLabel = canClockOut
            ? (_reclockLabels ? '재퇴근하기' : '퇴근하기')
            : (!isWorking && clockOut != null)
                ? '퇴근 완료'
                : (_reclockLabels ? '재퇴근하기' : '퇴근하기');

        // 기록 라벨: 당일 n번째 출근/퇴근 → 재출근/재퇴근
        final clockInOrder = <String, int>{};
        final clockOutOrder = <String, int>{};
        var inCount = 0;
        var outCount = 0;
        final chronological = [...todayLogs]
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        for (final log in chronological) {
          if (log.type == AttendanceType.clockIn) {
            inCount++;
            clockInOrder[log.id] = inCount;
          } else {
            outCount++;
            clockOutOrder[log.id] = outCount;
          }
        }

        String recordLabel(AttendanceLogModel log) {
          if (log.type == AttendanceType.clockIn) {
            final n = clockInOrder[log.id] ?? 1;
            return n > 1 ? '재출근' : '출근';
          }
          final n = clockOutOrder[log.id] ?? 1;
          return n > 1 ? '재퇴근' : '퇴근';
        }

        return FixedBottomPage(
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: scheduleConfirmed
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          // 퇴근 이력이 있을 때만 재출근 모드 진입/해제
                          if (!hasClockedOutToday && !_reclockLabels) {
                            return;
                          }
                          setState(
                            () => _reclockLabels = !_reclockLabels,
                          );
                        },
                        child: Text(
                          _reclockLabels
                              ? '돌아가기'
                              : '재출근·재퇴근 시 여기를 눌러주세요.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _hint,
                            height: 1.3,
                          ),
                        ),
                      )
                    : const Text(
                        '배정된 근무를 확인한 뒤 출퇴근할 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: _hint,
                          height: 1.3,
                        ),
                      ),
              ),
              StickyActionBar(
                safeAreaBottom: false,
                showTopBorder: false,
                children: [
                  StickyActionButton(
                    label: clockInLabel,
                    variant: StickyActionVariant.success,
                    enabled: canClockIn && !_gpsChecking,
                    isLoading: _gpsChecking && canClockIn,
                    onPressed: canClockIn && !_gpsChecking
                        ? () => _handleClock(
                              isClockIn: true,
                              liveRoom: liveRoom,
                              isRe: hasClockedOutToday || _reclockLabels,
                            )
                        : null,
                  ),
                  StickyActionButton(
                    label: clockOutLabel,
                    variant: StickyActionVariant.navy,
                    enabled: canClockOut && !_gpsChecking,
                    isLoading: _gpsChecking && canClockOut,
                    onPressed: canClockOut && !_gpsChecking
                        ? () => _handleClock(
                              isClockIn: false,
                              liveRoom: liveRoom,
                              isRe: hasClockedOutToday || _reclockLabels,
                            )
                        : null,
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                onTap: () {
                  AppNavigation.pushSingleTop(
                    name: AppRouteNames.noticeBoard(liveRoom.id),
                    stopAtNames: [AppRouteNames.room(liveRoom.id)],
                    builder: (_) => NoticeBoardScreen(
                      room: liveRoom,
                      canManage: false,
                    ),
                  );
                },
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.campaign_outlined,
                      size: 22,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            '매장 공지사항',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (unreadNotices > 0) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '읽지 않은 공지 $unreadNotices',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              if (changeRequests.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '근무 일정 변경 요청',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < changeRequests.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  PendingChangeCard(schedule: changeRequests[i]),
                ],
              ],
              const SizedBox(height: 12),
              Text(
                '출퇴근',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                liveRoom.name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (store
                  .pendingCorrectionsForWorker(uid)
                  .where((r) => r.roomId == liveRoom.id)
                  .isNotEmpty) ...[
                for (final corr in store
                    .pendingCorrectionsForWorker(uid)
                    .where((r) => r.roomId == liveRoom.id)) ...[
                  AppCard(
                    onTap: () => CommuteCorrectionReview.show(context, corr),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_calendar_outlined,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '사장님이 근태 수정을 요청했습니다. 확인해 주세요.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              if (incomingSwaps.isNotEmpty) ...[
                for (final swap in incomingSwaps) ...[
                  _IncomingSwapCard(
                    swap: swap,
                    schedule: store.schedules[swap.scheduleId],
                    store: store,
                    dayFmt: dayFmt,
                    timeFmt: timeFmt,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              if (pendingAll.isNotEmpty) ...[
                AppCard(
                  onTap: () {
                    AppNavigation.pushSingleTop(
                      name: AppRouteNames.assignedSchedule(liveRoom.id),
                      stopAtNames: [AppRouteNames.room(liveRoom.id)],
                      builder: (_) => StaffAssignedScheduleScreen(
                        roomId: liveRoom.id,
                        workerId: uid,
                      ),
                    );
                  },
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '확인 대기',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '배정된 근무를 한눈에 확인하세요',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '출퇴근',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (todaySchedule == null)
                      Text(
                        '오늘 배정된 근무가 없습니다.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _pending,
                            ),
                      )
                    else if (isAbsentToday)
                      Text(
                        '오늘 근무는 결근 처리되었습니다.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.holiday,
                              fontWeight: FontWeight.w600,
                            ),
                      )
                    else ...[
                      _StatusRow(
                        scheduleLabel:
                            '${dayFmt.format(scheduledStart!)} ${timeFmt.format(scheduledStart)}',
                        statusLabel: clockIn != null
                            ? '출근 완료 (${timeFmt.format(clockIn.timestamp)})'
                            : '출근 대기',
                        isDone: clockIn != null,
                      ),
                      const SizedBox(height: 10),
                      _StatusRow(
                        scheduleLabel:
                            '${dayFmt.format(scheduledEnd!)} ${timeFmt.format(scheduledEnd)}',
                        statusLabel: isWorking
                            ? '퇴근 대기'
                            : clockOut != null
                                ? '퇴근 완료 (${timeFmt.format(clockOut.timestamp)})'
                                : '퇴근 대기',
                        isDone: !isWorking && clockOut != null,
                      ),
                    ],
                  ],
                ),
              ),
              if (logs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '기록',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final log in logs.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      radius: 12,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              recordLabel(log),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: log.type == AttendanceType.clockIn
                                        ? AppColors.success
                                        : AppColors.primary,
                                  ),
                            ),
                          ),
                          Text(
                            logFmt.format(log.timestamp),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _IncomingSwapCard extends StatefulWidget {
  const _IncomingSwapCard({
    required this.swap,
    required this.schedule,
    required this.store,
    required this.dayFmt,
    required this.timeFmt,
  });

  final ShiftSwapRequest swap;
  final ScheduleModel? schedule;
  final MockStore store;
  final DateFormat dayFmt;
  final DateFormat timeFmt;

  @override
  State<_IncomingSwapCard> createState() => _IncomingSwapCardState();
}

class _IncomingSwapCardState extends State<_IncomingSwapCard> {
  bool _busy = false;

  Future<void> _run(VoidCallback action, String okMsg) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(okMsg), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final swap = widget.swap;
    final schedule = widget.schedule;
    final store = widget.store;
    final dayFmt = widget.dayFmt;
    final timeFmt = widget.timeFmt;
    final from = store.memberDisplayName(swap.roomId, swap.fromWorkerId);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '대타 요청',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$from 님이 대타를 요청했어요',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          if (schedule != null) ...[
            const SizedBox(height: 8),
            Text(
              '${dayFmt.format(schedule.startTime)} '
              '${timeFmt.format(schedule.startTime)} ~ '
              '${timeFmt.format(schedule.endTime)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '사유: ${swap.reason}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textCaption,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => store.rejectShiftSwapAsColleague(swap.id),
                            '대타 요청을 거절했습니다.',
                          ),
                  child: const Text('거절하기'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => store.acceptShiftSwapAsColleague(swap.id),
                            '대타를 수락했습니다. 사장님 승인을 기다려 주세요.',
                          ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('수락하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.scheduleLabel,
    required this.statusLabel,
    required this.isDone,
  });

  final String scheduleLabel;
  final String statusLabel;
  final bool isDone;

  static const Color _pending = Color(0xFF8B95A1);
  static const Color _done = Color(0xFF191F28);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            scheduleLabel,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _done,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          statusLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 12,
                fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                color: isDone ? _done : _pending,
              ),
        ),
      ],
    );
  }
}
