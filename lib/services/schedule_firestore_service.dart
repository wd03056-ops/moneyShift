import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/firestore_paths.dart';
import '../core/firebase/firestore_query_limits.dart';
import '../models/enums/schedule_status.dart';
import '../models/schedule_model.dart';

/// `schedules` 컬렉션 기본 CRUD
class ScheduleFirestoreService {
  ScheduleFirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.schedules);

  Future<ScheduleModel> create({
    required String roomId,
    required String workerId,
    required String assignedBy,
    required String date,
    required DateTime startTime,
    required DateTime endTime,
    int breakMinutes = 0,
    int? hourlyWage,
    String? note,
  }) async {
    try {
      final ref = _col.doc();
      final model = ScheduleModel(
        id: ref.id,
        roomId: roomId,
        workerId: workerId,
        assignedBy: assignedBy,
        date: date,
        startTime: startTime,
        endTime: endTime,
        breakMinutes: breakMinutes,
        basePay: hourlyWage,
        note: note,
        status: ScheduleStatus.normal,
      );
      await ref.set(model.toFirestore(forCreate: true));
      debugPrint(
        '[ScheduleFirestore] create ok id=${ref.id} worker=$workerId '
        'date=$date',
      );
      final snap = await ref.get();
      return ScheduleModel.fromFirestore(snap);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[ScheduleFirestore] create FAIL code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<ScheduleModel?> getById(String scheduleId) async {
    try {
      final snap = await _col.doc(scheduleId).get();
      if (!snap.exists) return null;
      return ScheduleModel.fromFirestore(snap);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[ScheduleFirestore] getById FAIL id=$scheduleId code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<List<ScheduleModel>> listByWorker(
    String workerId, {
    String? roomId,
    int limit = FirestoreQueryLimits.timeline,
  }) async {
    try {
      Query<Map<String, dynamic>> q =
          _col.where('workerId', isEqualTo: workerId);
      if (roomId != null) {
        q = q.where('roomId', isEqualTo: roomId);
      }
      final snap = await q.limit(limit).get();
      debugPrint(
        '[ScheduleFirestore] listByWorker ok worker=$workerId '
        'count=${snap.docs.length}',
      );
      return snap.docs.map(ScheduleModel.fromFirestore).toList();
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[ScheduleFirestore] listByWorker FAIL worker=$workerId '
        'code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<List<ScheduleModel>> listByRoomAndDate({
    required String roomId,
    required String date,
    int limit = FirestoreQueryLimits.list,
  }) async {
    try {
      final snap = await _col
          .where('roomId', isEqualTo: roomId)
          .where('date', isEqualTo: date)
          .limit(limit)
          .get();
      debugPrint(
        '[ScheduleFirestore] listByRoomAndDate ok room=$roomId date=$date '
        'count=${snap.docs.length}',
      );
      return snap.docs.map(ScheduleModel.fromFirestore).toList();
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[ScheduleFirestore] listByRoomAndDate FAIL code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<ScheduleModel> update(ScheduleModel schedule) async {
    try {
      await _col.doc(schedule.id).update(schedule.toFirestore());
      debugPrint('[ScheduleFirestore] update ok id=${schedule.id}');
      final snap = await _col.doc(schedule.id).get();
      return ScheduleModel.fromFirestore(snap);
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[ScheduleFirestore] update FAIL id=${schedule.id} code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> delete(String scheduleId) async {
    try {
      await _col.doc(scheduleId).delete();
      debugPrint('[ScheduleFirestore] delete ok id=$scheduleId');
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[ScheduleFirestore] delete FAIL id=$scheduleId code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }
}
