import 'package:flutter/foundation.dart';

import '../../core/time/kst_date_time.dart';
import '../../mock/mock_store.dart';
import '../../models/models.dart';

/// 근무표 도메인용 전역 상태 진입점.
///
/// [MockStore] 싱글톤을 사장·직원이 공유합니다.
/// 배정·확인 시 [notifyListeners]가 호출되므로
/// [ListenableBuilder]로 구독하면 계정 전환 후에도 동일 데이터가 즉시 렌더링됩니다.
class ScheduleStore {
  ScheduleStore._();

  static MockStore get _store => MockStore.instance;

  /// UI 구독용 (MockStore ChangeNotifier)
  static Listenable get listenable => _store;

  static List<ScheduleModel> forRoom(String roomId) =>
      _store.schedulesForRoom(roomId);

  static List<ScheduleModel> forWorker(String roomId, String workerId) =>
      _store.schedulesForWorker(roomId, workerId);

  static List<ScheduleModel> pendingForWorker(
    String roomId,
    String workerId,
  ) =>
      _store.pendingConfirmForWorker(roomId, workerId);

  /// 확인 대기 단위 (기간 배정은 묶음 1건)
  static List<List<ScheduleModel>> pendingUnits(
    String roomId,
    String workerId,
  ) =>
      _store.pendingConfirmUnits(roomId, workerId);

  static int pendingCount(String roomId, String workerId) =>
      _store.pendingConfirmUnitCount(roomId, workerId);

  /// 이 직원에게 방금 배정된 건이 있는지 (직원 화면 토스트용)
  static bool hasFreshAssignmentFor(String roomId, String workerId) {
    final at = _store.lastScheduleAssignedAt;
    if (at == null) return false;
    if (_store.lastAssignedRoomId != roomId) return false;
    if (_store.lastAssignedWorkerId != workerId) return false;
    return KstDateTime.now().difference(at) < const Duration(minutes: 30);
  }

  static int get lastAssignedCount => _store.lastAssignedCount;

  static ScheduleModel assign({
    required String roomId,
    required String workerId,
    required DateTime startTime,
    required DateTime endTime,
    int? estimatedPay,
    int? hourlyWage,
    String? note,
    bool includeWeeklyHoliday = false,
    bool includeOvertimeNight = false,
  }) {
    return _store.createSchedule(
      roomId: roomId,
      workerId: workerId,
      startTime: startTime,
      endTime: endTime,
      estimatedPay: estimatedPay,
      hourlyWage: hourlyWage,
      note: note,
      includeWeeklyHoliday: includeWeeklyHoliday,
      includeOvertimeNight: includeOvertimeNight,
    );
  }

  static ScheduleModel confirm(String scheduleId) =>
      _store.confirmSchedule(scheduleId);

  /// 확인 대기 근무 전체 확인
  static int confirmAllPending({
    required String roomId,
    required String workerId,
  }) =>
      _store.confirmAllPendingSchedules(
        roomId: roomId,
        workerId: workerId,
      );

  static ScheduleModel markAbsent(String scheduleId) =>
      _store.markScheduleAbsent(scheduleId);

  static ScheduleModel clearAbsent(String scheduleId) =>
      _store.clearScheduleAbsent(scheduleId);

  static bool canRequestChange(ScheduleModel schedule) =>
      _store.canRequestScheduleChange(schedule);

  static String? changeBlockReason(ScheduleModel schedule) =>
      _store.scheduleChangeBlockReason(schedule);

  static List<ScheduleModel> pendingOwnerChanges(
    String roomId,
    String workerId,
  ) =>
      _store.pendingOwnerChangeRequestsForWorker(roomId, workerId);

  static ScheduleModel requestChange({
    required String scheduleId,
    required ScheduleChangeType changeType,
    required DateTime newStartTime,
    required DateTime newEndTime,
    required String reason,
    String? substituteWorkerId,
  }) =>
      _store.requestScheduleChange(
        scheduleId: scheduleId,
        changeType: changeType,
        newStartTime: newStartTime,
        newEndTime: newEndTime,
        reason: reason,
        substituteWorkerId: substituteWorkerId,
      );

  /// 알바 → 사장 일정 변경 요청
  static ScheduleModel requestChangeByStaff({
    required String scheduleId,
    required DateTime newStartTime,
    required DateTime newEndTime,
    required String reason,
  }) =>
      _store.requestScheduleChangeByStaff(
        scheduleId: scheduleId,
        newStartTime: newStartTime,
        newEndTime: newEndTime,
        reason: reason,
      );

  /// 사장 — 알바 변경 요청 승인/거절
  static ScheduleModel resolveStaffChange({
    required String scheduleId,
    required bool approve,
    String? rejectReason,
  }) =>
      _store.resolveStaffScheduleChange(
        scheduleId: scheduleId,
        approve: approve,
        rejectReason: rejectReason,
      );

  static ScheduleModel acceptChange(String scheduleId) =>
      _store.acceptScheduleChange(scheduleId);

  static ScheduleModel rejectChange(String scheduleId, {String? rejectReason}) =>
      _store.rejectScheduleChange(scheduleId, rejectReason: rejectReason);
}
