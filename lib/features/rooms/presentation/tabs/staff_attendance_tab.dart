import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/ads/widgets/native_ad_card.dart';
import '../../../../core/async/action_guard.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/navigation/app_route_names.dart';
import '../../../../core/permissions/location_disclosure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/kst_date_time.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/scrollable_page_body.dart';
import '../../../../core/widgets/sticky_action_button.dart';
import '../../../../mock/mock_store.dart';
import '../../../../models/models.dart';
import '../../../../services/attendance_location_service.dart';
import '../../../../services/month_payroll_aggregator.dart';
import '../../../attendance/presentation/commute_correction_review_dialog.dart';
import '../../../notices/presentation/notice_board_screen.dart';
import '../../../schedules/presentation/staff_assigned_schedule_screen.dart';
import '../../../schedules/schedule_store.dart';
import '../../../schedules/widgets/pending_change_card.dart';
import '../widgets/staff_month_pay_summary_card.dart';

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
  /// 안내 문구 탭 시 버튼 라벨을 재출근하기/재퇴근하기로 전환
  bool _reclockLabels = false;
  bool _gpsChecking = false;
  final _clockGuard = ActionGuard(cooldown: Duration(milliseconds: 800));

  final _locationService = const AttendanceLocationService();

  Future<void> _showGeoCheckFailedDialog(AttendanceGeoCheckResult check) async {
    final isOutOfRange = check.isOutOfRange;
    final title = isOutOfRange ? '매장 위치 확인 필요' : '출퇴근 불가';
    final body = check.errorMessage ??
        AttendanceLocationService.outOfRangeMessage(
          distanceMeters: check.distanceMeters.clamp(0, double.infinity),
          radiusMeters: check.radiusMeters ??
              widget.room.geofenceRadiusMeters,
        );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 예정 퇴근 시각보다 이르면 확인 팝업. true면 퇴근 진행.
  Future<bool> _confirmEarlyClockOutIfNeeded(RoomModel liveRoom) async {
    final store = MockStore.instance;
    final uid = widget.membership.userId;
    final schedule = store.todayScheduleForWorker(liveRoom.id, uid);
    final end = schedule?.endTime;
    if (end == null || schedule?.isAbsent == true) return true;

    final now = KstDateTime.now();
    if (!now.isBefore(end)) return true;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('조기 퇴근 확인'),
        content: const Text(
          '아직 근무 종료 시간이 되지 않았습니다. 지금 퇴근 처리하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('퇴근하기'),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  Future<void> _handleClock({
    required bool isClockIn,
    required RoomModel liveRoom,
    required bool isRe,
  }) async {
    if (_gpsChecking || _clockGuard.isBusy) return;
    if (!_clockGuard.tryStart()) return;

    // 조기 퇴근: GPS 전에 확인 (취소 시 불필요한 위치 요청 생략)
    if (!isClockIn) {
      final ok = await _confirmEarlyClockOutIfNeeded(liveRoom);
      if (!ok || !mounted) {
        _clockGuard.end();
        return;
      }
    }

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
        await _showGeoCheckFailedDialog(check);
        return;
      }

      if (isClockIn) {
        store.clockIn(
          roomId: liveRoom.id,
          location: check.location,
          distanceFromStoreMeters: check.distanceMeters,
        );
      } else {
        // 확인 후 현재 시각으로 퇴근 기록 (MockStore.clockOut → KstDateTime.now)
        store.clockOut(
          roomId: liveRoom.id,
          location: check.location,
          distanceFromStoreMeters: check.distanceMeters,
        );
      }

      if (!mounted) return;
      final dayPay = !isClockIn
          ? store.actualPayOnDate(
              liveRoom.id,
              widget.membership.userId,
              KstDateTime.now(),
            )
          : 0;
      final currency = NumberFormat('#,###');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isClockIn
                ? (isRe ? '재출근이 완료되었습니다.' : '출근이 완료되었습니다.')
                : dayPay > 0
                    ? '${isRe ? '재퇴근' : '퇴근'} 완료 · 오늘 급여 ${currency.format(dayPay)}원'
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
      _clockGuard.end();
      if (mounted) setState(() => _gpsChecking = false);
    }
  }

  void _openAssignedSchedule(RoomModel liveRoom, String uid) {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.assignedSchedule(liveRoom.id),
      stopAtNames: [AppRouteNames.room(liveRoom.id)],
      builder: (_) => StaffAssignedScheduleScreen(
        roomId: liveRoom.id,
        workerId: uid,
      ),
    );
  }

  void _openNotices(RoomModel liveRoom) {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.noticeBoard(liveRoom.id),
      stopAtNames: [AppRouteNames.room(liveRoom.id)],
      builder: (_) => NoticeBoardScreen(
        room: liveRoom,
        canManage: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final membership = widget.membership;
    final timeFmt = DateFormat('HH:mm');
    final dayFmt = DateFormat('M월 d일', 'ko_KR');
    final logFmt = DateFormat('M/d HH:mm:ss');
    final currency = NumberFormat('#,###');

    return ListenableBuilder(
      listenable: MockStore.instance,
      builder: (context, _) {
        final store = MockStore.instance;
        final liveRoom = store.rooms[room.id] ?? room;
        final uid = membership.userId;
        final monthPaySummary = MonthPayrollAggregator.forWorker(
          store: store,
          roomId: liveRoom.id,
          userId: uid,
        );
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
        final pendingCorrections = store.pendingCorrectionsForWorker(
          roomId: liveRoom.id,
          workerId: uid,
        );

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

        final needsConfirm =
            !scheduleConfirmed && pendingAll.isNotEmpty;

        return AppScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '출퇴근',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                liveRoom.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textCaption,
                    ),
              ),
              const SizedBox(height: 16),
              _NoticeBar(
                unreadCount: unreadNotices,
                onTap: () => _openNotices(liveRoom),
              ),
              const SizedBox(height: 16),
              StaffMonthPaySummaryCard(
                summary: monthPaySummary,
                currency: currency,
                roomId: liveRoom.id,
              ),
              const SizedBox(height: 20),
              _TodayWorkCard(
                dayFmt: dayFmt,
                timeFmt: timeFmt,
                todaySchedule: todaySchedule,
                isAbsentToday: isAbsentToday,
                scheduledStart: scheduledStart,
                scheduledEnd: scheduledEnd,
                clockIn: clockIn,
                clockOut: clockOut,
                isWorking: isWorking,
                needsConfirm: needsConfirm,
                pendingCount: pendingAll.length,
                onConfirmTap: () => _openAssignedSchedule(liveRoom, uid),
                clockInLabel: clockInLabel,
                clockOutLabel: clockOutLabel,
                canClockIn: canClockIn,
                canClockOut: canClockOut,
                gpsChecking: _gpsChecking,
                onClockIn: () => _handleClock(
                  isClockIn: true,
                  liveRoom: liveRoom,
                  isRe: hasClockedOutToday || _reclockLabels,
                ),
                onClockOut: () => _handleClock(
                  isClockIn: false,
                  liveRoom: liveRoom,
                  isRe: hasClockedOutToday || _reclockLabels,
                ),
                scheduleConfirmed: scheduleConfirmed,
                reclockLabels: _reclockLabels,
                canToggleReclock: hasClockedOutToday || _reclockLabels,
                onToggleReclock: () =>
                    setState(() => _reclockLabels = !_reclockLabels),
              ),
              const NativeAdCard(
                margin: EdgeInsets.only(top: 16, bottom: 4),
              ),
              if (pendingCorrections.isNotEmpty ||
                  incomingSwaps.isNotEmpty ||
                  changeRequests.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  '확인이 필요해요',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSection,
                      ),
                ),
                const SizedBox(height: 10),
                for (final corr in pendingCorrections) ...[
                  _AlertTile(
                    icon: Icons.edit_calendar_outlined,
                    iconColor: AppColors.warning,
                    title: '근태 수정 요청',
                    subtitle: '사장님이 근태 수정을 요청했습니다.',
                    onTap: () => CommuteCorrectionReview.show(context, corr),
                  ),
                  const SizedBox(height: 10),
                ],
                for (final swap in incomingSwaps) ...[
                  _IncomingSwapCard(
                    swap: swap,
                    schedule: store.schedules[swap.scheduleId],
                    store: store,
                    dayFmt: dayFmt,
                    timeFmt: timeFmt,
                  ),
                  const SizedBox(height: 10),
                ],
                for (var i = 0; i < changeRequests.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  PendingChangeCard(schedule: changeRequests[i]),
                ],
              ],
              if (logs.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(
                  '최근 기록',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSection,
                      ),
                ),
                const SizedBox(height: 10),
                for (final log in logs.take(8))
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
                                    fontWeight: FontWeight.w700,
                                    color: log.type == AttendanceType.clockIn
                                        ? AppColors.success
                                        : AppColors.textPrimary,
                                  ),
                            ),
                          ),
                          Text(
                            logFmt.format(log.timestamp),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
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

/// 상단 얇은 공지 바
class _NoticeBar extends StatelessWidget {
  const _NoticeBar({
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.campaign_outlined,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  unreadCount > 0
                      ? '매장 공지 · 읽지 않은 공지 $unreadCount'
                      : '매장 공지사항',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSection,
                  ),
                ),
              ),
              if (unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
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
      ),
    );
  }
}

/// 오늘 근무 + 출퇴근 현황 + 버튼을 한 카드로 묶은 핵심 영역
class _TodayWorkCard extends StatelessWidget {
  const _TodayWorkCard({
    required this.dayFmt,
    required this.timeFmt,
    required this.todaySchedule,
    required this.isAbsentToday,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.clockIn,
    required this.clockOut,
    required this.isWorking,
    required this.needsConfirm,
    required this.pendingCount,
    required this.onConfirmTap,
    required this.clockInLabel,
    required this.clockOutLabel,
    required this.canClockIn,
    required this.canClockOut,
    required this.gpsChecking,
    required this.onClockIn,
    required this.onClockOut,
    required this.scheduleConfirmed,
    required this.reclockLabels,
    required this.canToggleReclock,
    required this.onToggleReclock,
  });

  final DateFormat dayFmt;
  final DateFormat timeFmt;
  final ScheduleModel? todaySchedule;
  final bool isAbsentToday;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final AttendanceLogModel? clockIn;
  final AttendanceLogModel? clockOut;
  final bool isWorking;
  final bool needsConfirm;
  final int pendingCount;
  final VoidCallback onConfirmTap;
  final String clockInLabel;
  final String clockOutLabel;
  final bool canClockIn;
  final bool canClockOut;
  final bool gpsChecking;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;
  final bool scheduleConfirmed;
  final bool reclockLabels;
  final bool canToggleReclock;
  final VoidCallback onToggleReclock;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nowLabel = dayFmt.format(KstDateTime.now());

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '오늘의 근무',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                nowLabel,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (todaySchedule == null)
            Text(
              '오늘 배정된 근무가 없습니다.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else if (isAbsentToday)
            Text(
              '오늘 근무는 결근 처리되었습니다.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.holiday,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            Text(
              '${timeFmt.format(scheduledStart!)} ~ ${timeFmt.format(scheduledEnd!)}',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatusChip(
                    label: clockIn != null
                        ? '출근 ${timeFmt.format(clockIn!.timestamp)}'
                        : '출근 대기',
                    done: clockIn != null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusChip(
                    label: isWorking
                        ? '퇴근 대기'
                        : clockOut != null
                            ? '퇴근 ${timeFmt.format(clockOut!.timestamp)}'
                            : '퇴근 대기',
                    done: !isWorking && clockOut != null,
                  ),
                ),
              ],
            ),
          ],
          if (needsConfirm) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            Text(
              pendingCount > 1
                  ? '확인 대기 배정 $pendingCount건'
                  : '배정된 근무를 확인한 뒤 출퇴근할 수 있어요.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textCaption,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            StickyActionButton(
              label: '배정 확인하기',
              variant: StickyActionVariant.filled,
              onPressed: onConfirmTap,
            ),
          ] else if (todaySchedule != null && !isAbsentToday) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StickyActionButton(
                    label: clockInLabel,
                    variant: StickyActionVariant.success,
                    enabled: canClockIn && !gpsChecking,
                    isLoading: gpsChecking && canClockIn,
                    onPressed: canClockIn && !gpsChecking ? onClockIn : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StickyActionButton(
                    label: clockOutLabel,
                    variant: StickyActionVariant.navy,
                    enabled: canClockOut && !gpsChecking,
                    isLoading: gpsChecking && canClockOut,
                    onPressed: canClockOut && !gpsChecking ? onClockOut : null,
                  ),
                ),
              ],
            ),
            if (scheduleConfirmed) ...[
              const SizedBox(height: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: canToggleReclock ? onToggleReclock : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    reclockLabels
                        ? '돌아가기'
                        : '재출근·재퇴근 시 여기를 눌러주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: canToggleReclock
                          ? AppColors.textCaption
                          : AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ] else if (!scheduleConfirmed && todaySchedule == null) ...[
            const SizedBox(height: 12),
            Text(
              '배정된 근무를 확인한 뒤 출퇴근할 수 있어요.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textCaption,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.done,
  });

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFECFDF5) : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: done ? AppColors.success.withValues(alpha: 0.35) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 16,
            color: done ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: done ? AppColors.textPrimary : AppColors.textCaption,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
