import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/time/kst_date_time.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../models/models.dart';
import '../../../services/room_repository.dart';
import '../../../services/schedule_repository.dart';
import '../widgets/pending_change_card.dart';
import 'request_change_sheet.dart';
import 'schedule_logs_screen.dart';

class ScheduleListScreen extends StatefulWidget {
  const ScheduleListScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  final String roomId;
  final String roomName;

  @override
  State<ScheduleListScreen> createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends State<ScheduleListScreen> {
  final _scheduleRepo = ScheduleRepository();
  final _roomRepo = RoomRepository();

  RoomMemberModel? _myMembership;
  final _busyIds = <String>{};
  final _shownDialogIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final m = await _roomRepo.getMembership(widget.roomId, uid);
    if (!mounted) return;
    setState(() => _myMembership = m);
  }

  bool get _isManager =>
      _myMembership?.role.canManageSchedules ?? false;

  Future<void> _approve(ScheduleModel schedule) async {
    setState(() => _busyIds.add(schedule.id));
    try {
      // 시급은 저장소에서 worker의 hourlyWage로 조회·반영
      await _scheduleRepo.approveChange(scheduleId: schedule.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '확인되었습니다.'
            '${schedule.pendingChange != null ? ' 근무시간·급여가 반영됩니다.' : ''}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('확인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(schedule.id));
    }
  }

  Future<void> _reject(ScheduleModel schedule) async {
    setState(() => _busyIds.add(schedule.id));
    try {
      await _scheduleRepo.rejectChange(scheduleId: schedule.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('변경 요청을 거절했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('거절 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(schedule.id));
    }
  }

  Future<void> _maybeShowDialogs(List<ScheduleModel> pending) async {
    for (final schedule in pending) {
      if (_shownDialogIds.contains(schedule.id)) continue;
      _shownDialogIds.add(schedule.id);
      if (!mounted) return;
      final result = await showPendingChangeDialog(
        context,
        schedule: schedule,
      );
      if (!mounted) return;
      if (result == true) {
        await _approve(schedule);
      } else if (result == false) {
        await _reject(schedule);
      }
    }
  }

  Future<void> _createDemoSchedule() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 데모: 매니저면 본인 또는 선택 없이 본인을 worker로 (실제에선 멤버 선택 UI)
    final now = KstDateTime.now();
    final start = DateTime(now.year, now.month, now.day, 9);
    final end = DateTime(now.year, now.month, now.day, 18);

    try {
      await _scheduleRepo.createSchedule(
        roomId: widget.roomId,
        workerId: uid,
        startTime: start,
        endTime: end,
        hourlyWage: _myMembership?.hourlyWage ?? 10000,
        note: '샘플 근무',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 생성 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('M/d HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.roomName} 근무표'),
        actions: [
          IconButton(
            tooltip: '변경 이력',
            icon: const Icon(Icons.history),
            onPressed: () {
              AppNavigation.pushSingleTop(
                name: AppRouteNames.scheduleLogs(widget.roomId),
                stopAtNames: [AppRouteNames.room(widget.roomId)],
                builder: (_) => ScheduleLogsScreen(roomId: widget.roomId),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _isManager
          ? FloatingActionButton.extended(
              onPressed: _createDemoSchedule,
              icon: const Icon(Icons.add),
              label: const Text('일정 추가'),
            )
          : null,
      body: StreamBuilder<List<ScheduleModel>>(
        stream: _scheduleRepo.watchPendingApprovalsForMe(
          roomId: widget.roomId,
          isManager: _isManager,
        ),
        builder: (context, pendingSnap) {
          final pending = pendingSnap.data ?? const <ScheduleModel>[];
          if (pending.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _maybeShowDialogs(pending);
            });
          }

          return StreamBuilder<List<ScheduleModel>>(
            stream: _scheduleRepo.watchRoomSchedules(widget.roomId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ScrollablePageBody(
                  top: false,
                  child: Text(
                    '오류: ${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final schedules = snapshot.data!;

              return ScrollablePageBody(
                top: false,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final s in pending)
                      PendingChangeCard(
                        schedule: s,
                        busy: _busyIds.contains(s.id),
                        onApprove: () => _approve(s),
                        onReject: () => _reject(s),
                      ),
                    if (schedules.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          '등록된 근무 일정이 없습니다.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      for (var i = 0; i < schedules.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          title: Text(
                            '${timeFmt.format(schedules[i].startTime)} ~ '
                            '${timeFmt.format(schedules[i].endTime)}',
                          ),
                          subtitle: Text(
                            '상태: ${schedules[i].status.labelKo}'
                            '${schedules[i].reason != null ? '\n사유: ${schedules[i].reason}' : ''}'
                            '${schedules[i].estimatedPay != null ? '\n예상 급여: ${schedules[i].estimatedPay}원' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: schedules[i].hasPendingChange
                              ? const Icon(Icons.hourglass_top)
                              : IconButton(
                                  tooltip: '시간 변경 요청',
                                  icon: const Icon(Icons.edit_calendar),
                                  onPressed: () => RequestChangeSheet.show(
                                    context,
                                    schedule: schedules[i],
                                  ),
                                ),
                        ),
                      ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
