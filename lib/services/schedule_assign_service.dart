import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/constants/firestore_paths.dart';
import '../core/permissions/store_permission_guard.dart';
import '../models/enums/schedule_status.dart';
import '../models/schedule_model.dart';

/// 근무 배정(schedules) — createdBy / workerUid 중심 + 권한
///
/// 푸시는 Cloud Functions `onScheduleCreated` 가 담당합니다.
class ScheduleAssignService {
  ScheduleAssignService({
    FirebaseFirestore? firestore,
    StorePermissionGuard? permission,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _permission = permission ?? StorePermissionGuard(firestore: firestore);

  final FirebaseFirestore _db;
  final StorePermissionGuard _permission;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.schedules);

  /// 사장/매니저가 알바생에게 근무 배정
  Future<ScheduleModel> assign({
    required String storeId,
    required String createdBy,
    required String workerUid,
    required DateTime startTime,
    required DateTime endTime,
    required int hourlyWage,
    int breakMinutes = 0,
    String? note,
    String? storeName,
  }) async {
    await _permission.requireManager(storeId: storeId, uid: createdBy);

    final ref = _col.doc();
    final date = DateFormat('yyyy-MM-dd').format(startTime);
    final model = ScheduleModel(
      id: ref.id,
      roomId: storeId,
      workerId: workerUid,
      assignedBy: createdBy,
      date: date,
      startTime: startTime,
      endTime: endTime,
      breakMinutes: breakMinutes,
      basePay: hourlyWage,
      note: note,
      status: ScheduleStatus.normal,
    );

    final data = {
      ...model.toFirestore(forCreate: true),
      // 신규 스키마 별칭 필드
      'storeId': storeId,
      'createdBy': createdBy,
      'workerUid': workerUid,
      'hourlyWage': hourlyWage,
      'storeName': ?storeName,
    };
    await ref.set(data);
    debugPrint(
      '[ScheduleAssign] created ${ref.path} worker=$workerUid by=$createdBy '
      '(FCM → onScheduleCreated)',
    );

    return ScheduleModel.fromFirestore(await ref.get());
  }

  Future<ScheduleModel> update({
    required String scheduleId,
    required String actorUid,
    DateTime? startTime,
    DateTime? endTime,
    int? hourlyWage,
    int? breakMinutes,
    String? note,
  }) async {
    final ref = _col.doc(scheduleId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('일정을 찾을 수 없습니다.');
    }
    final current = ScheduleModel.fromFirestore(snap);
    final storeId =
        (snap.data()?['storeId'] as String?) ?? current.roomId;

    await _permission.requireSelfOrManager(
      storeId: storeId,
      uid: actorUid,
      resourceOwnerUid: current.assignedBy,
    );
    // 알바 본인은 배정 필드 수정 불가 — 매니저만
    if (actorUid != current.assignedBy) {
      final isMgr = await _permission.isManager(storeId, actorUid);
      if (!isMgr) {
        throw StateError('근무 일정 수정은 관리자만 가능합니다.');
      }
    }

    final patch = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      if (startTime != null) 'startTime': Timestamp.fromDate(startTime),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime),
      if (hourlyWage != null) ...{
        'hourlyWage': hourlyWage,
        'basePay': hourlyWage,
      },
      'breakMinutes': ?breakMinutes,
      'note': ?note,
      if (startTime != null)
        'date': DateFormat('yyyy-MM-dd').format(startTime),
    };
    await ref.update(patch);
    debugPrint('[ScheduleAssign] update ok id=$scheduleId by=$actorUid');
    return ScheduleModel.fromFirestore(await ref.get());
  }

  Future<void> delete({
    required String scheduleId,
    required String actorUid,
  }) async {
    final ref = _col.doc(scheduleId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final current = ScheduleModel.fromFirestore(snap);
    final storeId =
        (snap.data()?['storeId'] as String?) ?? current.roomId;

    await _permission.requireManager(storeId: storeId, uid: actorUid);
    await ref.delete();
    debugPrint('[ScheduleAssign] delete ok id=$scheduleId by=$actorUid');
  }
}
