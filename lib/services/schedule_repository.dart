import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../core/constants/firestore_paths.dart';
import '../core/exceptions/room_exceptions.dart';
import '../core/exceptions/schedule_exceptions.dart';
import '../core/firebase/firestore_query_limits.dart';
import '../models/models.dart';
import 'payroll_calculator.dart';

/// 근무표 CRUD + 상호 승인 변경 요청 + schedule_logs 이력
class ScheduleRepository {
  ScheduleRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _db.collection(FirestorePaths.schedules);

  CollectionReference<Map<String, dynamic>> get _logs =>
      _db.collection(FirestorePaths.scheduleLogs);

  CollectionReference<Map<String, dynamic>> get _members =>
      _db.collection(FirestorePaths.roomMembers);

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw const NotAuthenticatedException();
    return user.uid;
  }

  // ---------------------------------------------------------------------------
  // 생성 / 조회
  // ---------------------------------------------------------------------------

  Future<ScheduleModel> createSchedule({
    required String roomId,
    required String workerId,
    required DateTime startTime,
    required DateTime endTime,
    String? note,
    int? hourlyWage,
  }) async {
    final uid = _uid;
    _validateTimes(startTime, endTime);
    await _ensureManager(roomId, uid);

    final ref = _schedules.doc();
    final date = DateFormat('yyyy-MM-dd').format(startTime);
    final estimated = hourlyWage != null
        ? PayrollCalculator.estimatePay(
            startTime: startTime,
            endTime: endTime,
            hourlyWage: hourlyWage,
          )
        : null;

    final schedule = ScheduleModel(
      id: ref.id,
      roomId: roomId,
      workerId: workerId,
      assignedBy: uid,
      date: date,
      startTime: startTime,
      endTime: endTime,
      status: ScheduleStatus.normal,
      estimatedPay: estimated,
      note: note,
    );

    await ref.set(schedule.toFirestore(forCreate: true));
    return schedule;
  }

  Future<ScheduleModel?> getSchedule(String scheduleId) async {
    final snap = await _schedules.doc(scheduleId).get();
    if (!snap.exists) return null;
    return ScheduleModel.fromFirestore(snap);
  }

  Stream<List<ScheduleModel>> watchRoomSchedules(String roomId) {
    return _schedules
        .where('roomId', isEqualTo: roomId)
        .orderBy('date', descending: true)
        .limit(FirestoreQueryLimits.timeline)
        .snapshots()
        .map((s) => s.docs.map(ScheduleModel.fromFirestore).toList());
  }

  Stream<List<ScheduleModel>> watchWorkerSchedules(String workerId) {
    return _schedules
        .where('workerId', isEqualTo: workerId)
        .orderBy('date', descending: true)
        .limit(FirestoreQueryLimits.timeline)
        .snapshots()
        .map((s) => s.docs.map(ScheduleModel.fromFirestore).toList());
  }

  /// 내가 승인해야 하는 변경 요청 목록
  Stream<List<ScheduleModel>> watchPendingApprovalsForMe({
    required String roomId,
    required bool isManager,
  }) {
    final uid = _uid;
    if (isManager) {
      // 알바생이 요청한 건 → 사장/매니저가 승인
      return _schedules
          .where('roomId', isEqualTo: roomId)
          .where(
            'status',
            isEqualTo: ScheduleStatus.changeRequestedByStaff.firestoreValue,
          )
          .limit(FirestoreQueryLimits.list)
          .snapshots()
          .map((s) => s.docs.map(ScheduleModel.fromFirestore).toList());
    }

    // 사장이 요청한 건 → 해당 알바생이 승인
    return _schedules
        .where('roomId', isEqualTo: roomId)
        .where('workerId', isEqualTo: uid)
        .where(
          'status',
          isEqualTo: ScheduleStatus.changeRequestedByOwner.firestoreValue,
        )
        .limit(FirestoreQueryLimits.list)
        .snapshots()
        .map((s) => s.docs.map(ScheduleModel.fromFirestore).toList());
  }

  Future<void> confirmSchedule(String scheduleId) async {
    final uid = _uid;
    final snap = await _schedules.doc(scheduleId).get();
    if (!snap.exists) throw const ScheduleNotFoundException();
    final schedule = ScheduleModel.fromFirestore(snap);
    if (schedule.workerId != uid) {
      throw const SchedulePermissionDeniedException('본인 일정만 확인할 수 있습니다.');
    }
    await snap.reference.update(schedule.toConfirmUpdate());
  }

  // ---------------------------------------------------------------------------
  // 변경 요청 (즉시 반영 금지)
  // ---------------------------------------------------------------------------

  /// 확정된 근무시간 변경 요청.
  /// 사장이면 `change_requested_by_owner`, 알바생이면 `change_requested_by_staff`.
  Future<ScheduleModel> requestTimeChange({
    required String scheduleId,
    required DateTime newStartTime,
    required DateTime newEndTime,
    required String reason,
  }) async {
    final uid = _uid;
    _validateTimes(newStartTime, newEndTime);
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError('수정 사유를 입력해주세요.');
    }

    final scheduleRef = _schedules.doc(scheduleId);
    final logRef = _logs.doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(scheduleRef);
      if (!snap.exists) throw const ScheduleNotFoundException();
      final schedule = ScheduleModel.fromFirestore(snap);

      if (schedule.hasPendingChange) {
        throw const ScheduleChangeConflictException();
      }

      final membership = await _getMembershipTx(tx, schedule.roomId, uid);
      final isManager = membership?.role.canManageSchedules ?? false;
      final isWorker = schedule.workerId == uid;

      if (!isManager && !isWorker) {
        throw const SchedulePermissionDeniedException();
      }

      // 알바생 요청 → 사장 승인 / 사장 요청 → 알바생 승인
      // (본인이 worker이기도 한 매니저는 staff 요청으로 처리해 다른 매니저가 승인)
      final resolvedStatus = isWorker
          ? ScheduleStatus.changeRequestedByStaff
          : ScheduleStatus.changeRequestedByOwner;

      final pending = PendingChange(
        startTime: newStartTime,
        endTime: newEndTime,
        reason: trimmedReason,
        requestedBy: uid,
      );

      tx.update(scheduleRef, {
        'status': resolvedStatus.firestoreValue,
        'pending_change': pending.toMap(forCreate: true),
        'reason': trimmedReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final log = ScheduleLogModel(
        id: logRef.id,
        scheduleId: scheduleId,
        roomId: schedule.roomId,
        workerId: schedule.workerId,
        action: ScheduleLogAction.changeRequested,
        requestedBy: uid,
        reason: trimmedReason,
        previousStartTime: schedule.startTime,
        previousEndTime: schedule.endTime,
        newStartTime: newStartTime,
        newEndTime: newEndTime,
      );
      tx.set(logRef, log.toFirestore(forCreate: true));
    });

    return (await getSchedule(scheduleId))!;
  }

  // ---------------------------------------------------------------------------
  // 승인 / 거절
  // ---------------------------------------------------------------------------

  /// [승인] — 최종 근무시간 반영 + 급여 재계산 + schedule_logs 기록
  Future<ScheduleModel> approveChange({
    required String scheduleId,
    int? hourlyWage,
  }) async {
    final uid = _uid;
    final scheduleRef = _schedules.doc(scheduleId);
    final logRef = _logs.doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(scheduleRef);
      if (!snap.exists) throw const ScheduleNotFoundException();
      final schedule = ScheduleModel.fromFirestore(snap);
      final pending = schedule.pendingChange;

      if (!schedule.hasPendingChange || pending == null) {
        throw const NoPendingChangeException();
      }

      await _ensureCanResolve(tx, schedule, uid);

      var wage = hourlyWage;
      if (wage == null) {
        final workerMember = await _getMembershipTx(
          tx,
          schedule.roomId,
          schedule.workerId,
        );
        wage = workerMember?.hourlyWage;
      }

      final estimated = wage != null
          ? PayrollCalculator.estimatePay(
              startTime: pending.startTime,
              endTime: pending.endTime,
              hourlyWage: wage,
            )
          : null;

      final date = DateFormat('yyyy-MM-dd').format(pending.startTime);

      tx.update(scheduleRef, {
        'startTime': Timestamp.fromDate(pending.startTime),
        'endTime': Timestamp.fromDate(pending.endTime),
        'date': date,
        'status': ScheduleStatus.normal.firestoreValue,
        'pending_change': FieldValue.delete(),
        'reason': pending.reason,
        'estimatedPay': ?estimated,
        'lastChangeResult': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final log = ScheduleLogModel(
        id: logRef.id,
        scheduleId: scheduleId,
        roomId: schedule.roomId,
        workerId: schedule.workerId,
        action: ScheduleLogAction.changeApproved,
        requestedBy: pending.requestedBy,
        resolvedBy: uid,
        reason: pending.reason,
        previousStartTime: schedule.startTime,
        previousEndTime: schedule.endTime,
        newStartTime: pending.startTime,
        newEndTime: pending.endTime,
      );
      tx.set(logRef, log.toFirestore(forCreate: true));
    });

    return (await getSchedule(scheduleId))!;
  }

  /// [거절] — 기존 시간 유지, pending 제거, 이력 기록
  Future<ScheduleModel> rejectChange({
    required String scheduleId,
    String? rejectReason,
  }) async {
    final uid = _uid;
    final scheduleRef = _schedules.doc(scheduleId);
    final logRef = _logs.doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(scheduleRef);
      if (!snap.exists) throw const ScheduleNotFoundException();
      final schedule = ScheduleModel.fromFirestore(snap);
      final pending = schedule.pendingChange;

      if (!schedule.hasPendingChange || pending == null) {
        throw const NoPendingChangeException();
      }

      await _ensureCanResolve(tx, schedule, uid);

      final reason = (rejectReason?.trim().isNotEmpty == true)
          ? rejectReason!.trim()
          : pending.reason;

      tx.update(scheduleRef, {
        'status': ScheduleStatus.normal.firestoreValue,
        'pending_change': FieldValue.delete(),
        'lastChangeResult': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final log = ScheduleLogModel(
        id: logRef.id,
        scheduleId: scheduleId,
        roomId: schedule.roomId,
        workerId: schedule.workerId,
        action: ScheduleLogAction.changeRejected,
        requestedBy: pending.requestedBy,
        resolvedBy: uid,
        reason: reason,
        previousStartTime: schedule.startTime,
        previousEndTime: schedule.endTime,
        newStartTime: pending.startTime,
        newEndTime: pending.endTime,
      );
      tx.set(logRef, log.toFirestore(forCreate: true));
    });

    return (await getSchedule(scheduleId))!;
  }

  Future<List<ScheduleLogModel>> listLogsForSchedule(String scheduleId) async {
    final snap = await _logs
        .where('scheduleId', isEqualTo: scheduleId)
        .orderBy('createdAt', descending: true)
        .limit(FirestoreQueryLimits.list)
        .get();
    return snap.docs.map(ScheduleLogModel.fromFirestore).toList();
  }

  Stream<List<ScheduleLogModel>> watchLogsForRoom(String roomId) {
    return _logs
        .where('roomId', isEqualTo: roomId)
        .orderBy('createdAt', descending: true)
        .limit(FirestoreQueryLimits.timeline)
        .snapshots()
        .map((s) => s.docs.map(ScheduleLogModel.fromFirestore).toList());
  }

  // ---------------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------------

  void _validateTimes(DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      throw const InvalidScheduleTimeException();
    }
  }

  Future<RoomMemberModel?> _getMembershipTx(
    Transaction tx,
    String roomId,
    String userId,
  ) async {
    final ref = _members.doc(FirestorePaths.roomMemberDocId(roomId, userId));
    final snap = await tx.get(ref);
    if (!snap.exists) return null;
    return RoomMemberModel.fromFirestore(snap);
  }

  Future<void> _ensureManager(String roomId, String uid) async {
    final snap = await _members
        .doc(FirestorePaths.roomMemberDocId(roomId, uid))
        .get();
    if (!snap.exists) throw const SchedulePermissionDeniedException();
    final member = RoomMemberModel.fromFirestore(snap);
    if (!member.role.canManageSchedules) {
      throw const SchedulePermissionDeniedException();
    }
  }

  /// 요청의 상대방만 승인/거절 가능
  Future<void> _ensureCanResolve(
    Transaction tx,
    ScheduleModel schedule,
    String uid,
  ) async {
    final membership = await _getMembershipTx(tx, schedule.roomId, uid);
    if (membership == null || !membership.isActive) {
      throw const SchedulePermissionDeniedException();
    }

    switch (schedule.status) {
      case ScheduleStatus.changeRequestedByOwner:
        // 알바생만 승인
        if (schedule.workerId != uid) {
          throw const SchedulePermissionDeniedException(
            '이 변경 요청은 알바생만 확인할 수 있습니다.',
          );
        }
      case ScheduleStatus.changeRequestedByStaff:
        // 사장/매니저만 승인
        if (!membership.role.canManageSchedules) {
          throw const SchedulePermissionDeniedException(
            '이 변경 요청은 사장/매니저만 확인할 수 있습니다.',
          );
        }
      case ScheduleStatus.normal:
        throw const NoPendingChangeException();
    }

    // 본인이 요청한 건을 스스로 승인하는 것 방지
    if (schedule.pendingChange?.requestedBy == uid) {
      throw const SchedulePermissionDeniedException(
        '본인이 요청한 변경은 스스로 확인할 수 없습니다.',
      );
    }
  }
}
