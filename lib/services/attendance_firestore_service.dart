import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/firestore_paths.dart';
import '../core/permissions/store_permission_guard.dart';
import '../models/attendance_session_model.dart';
import '../models/geo_location.dart';
/// `attendances` 컬렉션 CRUD (출근·퇴근 세션) + 승인
///
/// 출·퇴근 푸시는 Cloud Functions `onAttendanceCreated` /
/// `onAttendanceUpdated` 가 처리합니다.
class AttendanceFirestoreService {
  AttendanceFirestoreService({
    FirebaseFirestore? firestore,
    StorePermissionGuard? permission,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _permission = permission ?? StorePermissionGuard(firestore: firestore);

  final FirebaseFirestore _db;
  final StorePermissionGuard _permission;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.attendances);

  Future<AttendanceSessionModel> clockIn({
    required String storeId,
    required String userId,
    required GeoLocation location,
    String? scheduleId,
    int? hourlyWage,
    DateTime? at,
  }) async {
    await _permission.requireMember(storeId: storeId, uid: userId);
    try {
      final ref = _col.doc();
      final session = AttendanceSessionModel(
        id: ref.id,
        storeId: storeId,
        userId: userId,
        clockInAt: at ?? DateTime.now(),
        clockInLocation: location,
        status: AttendanceSessionStatus.clockedIn,
        scheduleId: scheduleId,
        hourlyWage: hourlyWage,
        isApproved: false,
      );
      await ref.set(session.toFirestore(forCreate: true));
      debugPrint(
        '[AttendanceFirestore] clockIn ok id=${ref.id} user=$userId '
        'store=$storeId',
      );
      return AttendanceSessionModel.fromFirestore(await ref.get());
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[AttendanceFirestore] clockIn FAIL code=${e.code} message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  Future<AttendanceSessionModel> clockOut({
    required String attendanceId,
    required String actorUid,
    required GeoLocation location,
    DateTime? at,
  }) async {
    final ref = _col.doc(attendanceId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('출퇴근 기록을 찾을 수 없습니다.');
    }
    final current = AttendanceSessionModel.fromFirestore(snap);
    await _permission.requireSelfOrManager(
      storeId: current.storeId,
      uid: actorUid,
      resourceOwnerUid: current.userId,
    );

    try {
      await ref.update({
        'clockOutAt': Timestamp.fromDate(at ?? DateTime.now()),
        'clockOutLocation': location.toMap(),
        'status': AttendanceSessionStatus.clockedOut.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[AttendanceFirestore] clockOut ok id=$attendanceId');
      return AttendanceSessionModel.fromFirestore(await ref.get());
    } on FirebaseException catch (e, st) {
      debugPrint(
        '[AttendanceFirestore] clockOut FAIL id=$attendanceId code=${e.code} '
        'message=${e.message}',
      );
      debugPrint('$st');
      rethrow;
    }
  }

  /// 사장/매니저 최종 승인
  Future<AttendanceSessionModel> approve({
    required String attendanceId,
    required String approverUid,
  }) async {
    final ref = _col.doc(attendanceId);
    final snap = await ref.get();
    if (!snap.exists) {
      throw StateError('출퇴근 기록을 찾을 수 없습니다.');
    }
    final current = AttendanceSessionModel.fromFirestore(snap);
    await _permission.requireManager(
      storeId: current.storeId,
      uid: approverUid,
    );

    await ref.update({
      'isApproved': true,
      'approvedBy': approverUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint(
      '[AttendanceFirestore] approved id=$attendanceId by=$approverUid',
    );

    return AttendanceSessionModel.fromFirestore(await ref.get());
  }

  Future<AttendanceSessionModel?> getById(String attendanceId) async {
    final snap = await _col.doc(attendanceId).get();
    if (!snap.exists) return null;
    return AttendanceSessionModel.fromFirestore(snap);
  }

  Future<List<AttendanceSessionModel>> listByUser(
    String userId, {
    String? storeId,
  }) async {
    Query<Map<String, dynamic>> q = _col.where('userId', isEqualTo: userId);
    if (storeId != null) {
      q = q.where('storeId', isEqualTo: storeId);
    }
    final snap = await q.get();
    return snap.docs.map(AttendanceSessionModel.fromFirestore).toList();
  }

  Future<void> delete({
    required String attendanceId,
    required String actorUid,
  }) async {
    final snap = await _col.doc(attendanceId).get();
    if (!snap.exists) return;
    final current = AttendanceSessionModel.fromFirestore(snap);
    await _permission.requireSelfOrManager(
      storeId: current.storeId,
      uid: actorUid,
      resourceOwnerUid: current.userId,
    );
    await _col.doc(attendanceId).delete();
    debugPrint('[AttendanceFirestore] delete ok id=$attendanceId by=$actorUid');
  }
}
