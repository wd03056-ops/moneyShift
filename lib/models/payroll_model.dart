import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/firestore_paths.dart';

/// `payrolls/{storeId}_{workerUid}_{yyyyMM}` — 월별 급여 정산
class PayrollModel extends Equatable {
  const PayrollModel({
    required this.id,
    required this.storeId,
    required this.workerUid,
    required this.yearMonth,
    required this.confirmedWorkMinutes,
    required this.basePay,
    required this.weeklyHolidayPay,
    required this.nightPay,
    required this.overtimePay,
    required this.totalPay,
    this.hourlyWage,
    this.attendanceCount = 0,
    this.isFinalized = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String storeId;
  final String workerUid;

  /// `yyyy-MM`
  final String yearMonth;

  /// 확정 근무 분
  final int confirmedWorkMinutes;
  final int basePay;
  final int weeklyHolidayPay;
  final int nightPay;
  final int overtimePay;
  final int totalPay;
  final int? hourlyWage;
  final int attendanceCount;
  final bool isFinalized;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get docPath => FirestorePaths.payroll(id);

  static String docIdFor({
    required String storeId,
    required String workerUid,
    required String yearMonth,
  }) =>
      '${storeId}_${workerUid}_$yearMonth';

  factory PayrollModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PayrollModel.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory PayrollModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return PayrollModel(
      id: id ?? map['id'] as String? ?? '',
      storeId: map['storeId'] as String? ?? '',
      workerUid: map['workerUid'] as String? ?? '',
      yearMonth: map['yearMonth'] as String? ?? '',
      confirmedWorkMinutes: map['confirmedWorkMinutes'] as int? ?? 0,
      basePay: map['basePay'] as int? ?? 0,
      weeklyHolidayPay: map['weeklyHolidayPay'] as int? ?? 0,
      nightPay: map['nightPay'] as int? ?? 0,
      overtimePay: map['overtimePay'] as int? ?? 0,
      totalPay: map['totalPay'] as int? ?? 0,
      hourlyWage: map['hourlyWage'] as int?,
      attendanceCount: map['attendanceCount'] as int? ?? 0,
      isFinalized: map['isFinalized'] as bool? ?? false,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    return {
      'storeId': storeId,
      'workerUid': workerUid,
      'yearMonth': yearMonth,
      'confirmedWorkMinutes': confirmedWorkMinutes,
      'basePay': basePay,
      'weeklyHolidayPay': weeklyHolidayPay,
      'nightPay': nightPay,
      'overtimePay': overtimePay,
      'totalPay': totalPay,
      if (hourlyWage != null) 'hourlyWage': hourlyWage,
      'attendanceCount': attendanceCount,
      'isFinalized': isFinalized,
      'updatedAt': FieldValue.serverTimestamp(),
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        storeId,
        workerUid,
        yearMonth,
        confirmedWorkMinutes,
        basePay,
        weeklyHolidayPay,
        nightPay,
        overtimePay,
        totalPay,
        hourlyWage,
        attendanceCount,
        isFinalized,
        createdAt,
        updatedAt,
      ];
}
