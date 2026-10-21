import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/firestore_paths.dart';
import '../core/exceptions/room_exceptions.dart';
import '../core/permissions/store_permission_guard.dart';
import '../models/enums/shift_request_status.dart';
import '../models/enums/shift_request_type.dart';
import '../models/shift_request_model.dart';

/// `shift_requests` CRUD + 승인/거절
///
/// 푸시는 Cloud Functions `onShiftRequestCreated` / `onShiftRequestUpdated`.
class ShiftRequestService {
  ShiftRequestService({
    FirebaseFirestore? firestore,
    StorePermissionGuard? permission,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _permission = permission ?? StorePermissionGuard(firestore: firestore);

  final FirebaseFirestore _db;
  final StorePermissionGuard _permission;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.shiftRequests);

  Future<ShiftRequestModel> create({
    required String storeId,
    required String applicantUid,
    required ShiftRequestType type,
    String? scheduleId,
    String? targetWorkerUid,
    String? reason,
    DateTime? proposedStart,
    DateTime? proposedEnd,
    String? notifyApproverUid,
  }) async {
    await _permission.requireMember(storeId: storeId, uid: applicantUid);

    final ref = _col.doc();
    final model = ShiftRequestModel(
      id: ref.id,
      storeId: storeId,
      applicantUid: applicantUid,
      type: type,
      status: ShiftRequestStatus.pending,
      scheduleId: scheduleId,
      targetWorkerUid: targetWorkerUid,
      reason: reason,
      proposedStart: proposedStart,
      proposedEnd: proposedEnd,
    );
    final payload = {
      ...model.toFirestore(forCreate: true),
      'approverUid': ?notifyApproverUid,
    };
    await ref.set(payload);
    debugPrint(
      '[ShiftRequest] create ok ${ref.path} type=${type.name} '
      '(FCM → onShiftRequestCreated)',
    );

    return ShiftRequestModel.fromFirestore(await ref.get());
  }

  Future<ShiftRequestModel> resolve({
    required String requestId,
    required String approverUid,
    required bool approve,
  }) async {
    final ref = _col.doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw const RoomNotFoundException('요청을 찾을 수 없습니다.');
    }
    final current = ShiftRequestModel.fromFirestore(snap);
    await _permission.requireManager(
      storeId: current.storeId,
      uid: approverUid,
    );

    if (current.status != ShiftRequestStatus.pending) {
      throw const RoomPermissionDeniedException('이미 처리된 요청입니다.');
    }

    final status =
        approve ? ShiftRequestStatus.approved : ShiftRequestStatus.rejected;
    await ref.update({
      'status': status.firestoreValue,
      'approverUid': approverUid,
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint(
      '[ShiftRequest] resolve ok id=$requestId status=${status.name} '
      'by=$approverUid (FCM → onShiftRequestUpdated)',
    );

    return ShiftRequestModel.fromFirestore(await ref.get());
  }

  Future<List<ShiftRequestModel>> listByStore(
    String storeId, {
    ShiftRequestStatus? status,
  }) async {
    Query<Map<String, dynamic>> q =
        _col.where('storeId', isEqualTo: storeId);
    if (status != null) {
      q = q.where('status', isEqualTo: status.firestoreValue);
    }
    final snap = await q.get();
    return snap.docs.map(ShiftRequestModel.fromFirestore).toList();
  }

  Future<void> delete({
    required String requestId,
    required String actorUid,
  }) async {
    final snap = await _col.doc(requestId).get();
    if (!snap.exists) return;
    final current = ShiftRequestModel.fromFirestore(snap);
    await _permission.requireSelfOrManager(
      storeId: current.storeId,
      uid: actorUid,
      resourceOwnerUid: current.applicantUid,
    );
    if (current.status != ShiftRequestStatus.pending &&
        actorUid == current.applicantUid) {
      throw const RoomPermissionDeniedException(
        '대기 중인 요청만 본인이 삭제할 수 있습니다.',
      );
    }
    await _col.doc(requestId).delete();
    debugPrint('[ShiftRequest] delete ok id=$requestId by=$actorUid');
  }
}
