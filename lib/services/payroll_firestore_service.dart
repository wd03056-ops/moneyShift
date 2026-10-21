import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/constants/firestore_paths.dart';
import '../core/permissions/store_permission_guard.dart';
import '../models/attendance_session_model.dart';
import '../models/payroll_model.dart';
import 'payroll_calculator.dart';

/// `payrolls` 월별 급여 정산
class PayrollFirestoreService {
  PayrollFirestoreService({
    FirebaseFirestore? firestore,
    StorePermissionGuard? permission,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _permission = permission ?? StorePermissionGuard(firestore: firestore);

  final FirebaseFirestore _db;
  final StorePermissionGuard _permission;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.payrolls);

  /// 승인된 출퇴근 세션을 모아 월별 급여 문서 upsert
  Future<PayrollModel> recomputeMonth({
    required String storeId,
    required String workerUid,
    required String actorUid,
    required DateTime month,
    int hourlyWage = 10320,
    bool includeWeeklyHoliday = true,
    bool includeOvertimeNight = true,
  }) async {
    await _permission.requireManager(storeId: storeId, uid: actorUid);

    final yearMonth = DateFormat('yyyy-MM').format(month);
    final sessions = await _db
        .collection(FirestorePaths.attendances)
        .where('storeId', isEqualTo: storeId)
        .where('userId', isEqualTo: workerUid)
        .where('isApproved', isEqualTo: true)
        .get();

    var totalMinutes = 0;
    var basePay = 0;
    var weeklyHolidayPay = 0;
    var nightPay = 0;
    var overtimePay = 0;
    var count = 0;

    for (final doc in sessions.docs) {
      final a = AttendanceSessionModel.fromFirestore(doc);
      if (a.clockOutAt == null) continue;
      if (!_sameMonth(a.clockInAt, month)) continue;

      final wage = a.hourlyWage ?? hourlyWage;
      final estimate = PayrollCalculator.estimate(
        startTime: a.clockInAt,
        endTime: a.clockOutAt!,
        hourlyWage: wage,
        includeWeeklyHoliday: includeWeeklyHoliday,
        includeOvertimeNight: includeOvertimeNight,
      );
      totalMinutes += estimate.netWorkedMinutes;
      basePay += estimate.basePay;
      weeklyHolidayPay += estimate.weeklyHolidayPay;
      // PayEstimate 는 연장·야간을 합산 — 분 비율로 분리 저장
      final premium = estimate.overtimeNightPay;
      final premiumMins = estimate.overtimeMinutes + estimate.nightMinutes;
      if (premiumMins > 0) {
        overtimePay +=
            (premium * estimate.overtimeMinutes / premiumMins).round();
        nightPay += (premium * estimate.nightMinutes / premiumMins).round();
      }
      count += 1;
    }

    final totalPay = basePay + weeklyHolidayPay + nightPay + overtimePay;
    final id = PayrollModel.docIdFor(
      storeId: storeId,
      workerUid: workerUid,
      yearMonth: yearMonth,
    );
    final model = PayrollModel(
      id: id,
      storeId: storeId,
      workerUid: workerUid,
      yearMonth: yearMonth,
      confirmedWorkMinutes: totalMinutes,
      basePay: basePay,
      weeklyHolidayPay: weeklyHolidayPay,
      nightPay: nightPay,
      overtimePay: overtimePay,
      totalPay: totalPay,
      hourlyWage: hourlyWage,
      attendanceCount: count,
    );

    final ref = _col.doc(id);
    final exists = (await ref.get()).exists;
    await ref.set(model.toFirestore(forCreate: !exists), SetOptions(merge: true));
    debugPrint(
      '[Payroll] recompute ok $id total=$totalPay minutes=$totalMinutes '
      'sessions=$count',
    );
    return PayrollModel.fromFirestore(await ref.get());
  }

  Future<PayrollModel?> get({
    required String storeId,
    required String workerUid,
    required String yearMonth,
  }) async {
    final id = PayrollModel.docIdFor(
      storeId: storeId,
      workerUid: workerUid,
      yearMonth: yearMonth,
    );
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return PayrollModel.fromFirestore(snap);
  }

  Future<PayrollModel> finalize({
    required String storeId,
    required String workerUid,
    required String yearMonth,
    required String actorUid,
  }) async {
    await _permission.requireManager(storeId: storeId, uid: actorUid);
    final id = PayrollModel.docIdFor(
      storeId: storeId,
      workerUid: workerUid,
      yearMonth: yearMonth,
    );
    await _col.doc(id).update({
      'isFinalized': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[Payroll] finalized $id by=$actorUid');
    return PayrollModel.fromFirestore(await _col.doc(id).get());
  }

  bool _sameMonth(DateTime a, DateTime month) =>
      a.year == month.year && a.month == month.month;
}
