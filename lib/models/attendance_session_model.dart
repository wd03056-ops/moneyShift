import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/firestore_paths.dart';
import 'geo_location.dart';

/// `attendances/{id}` — 출근·퇴근 세션 (근무 실적)
enum AttendanceSessionStatus {
  clockedIn,
  clockedOut,
  incomplete,
  invalid;

  String get firestoreValue => name;

  static AttendanceSessionStatus fromFirestore(String value) {
    return AttendanceSessionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AttendanceSessionStatus.incomplete,
    );
  }
}

class AttendanceSessionModel extends Equatable {
  const AttendanceSessionModel({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.clockInAt,
    required this.clockInLocation,
    required this.status,
    this.clockOutAt,
    this.clockOutLocation,
    this.scheduleId,
    this.hourlyWage,
    this.isApproved = false,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String storeId;

  /// 알바생 카카오 UID
  final String userId;
  final DateTime clockInAt;
  final GeoLocation clockInLocation;
  final DateTime? clockOutAt;
  final GeoLocation? clockOutLocation;
  final AttendanceSessionStatus status;
  final String? scheduleId;
  final int? hourlyWage;

  /// 사장/매니저 최종 승인
  final bool isApproved;
  final String? approvedBy;
  final DateTime? approvedAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AttendanceSessionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AttendanceSessionModel.fromMap(data, id: doc.id);
  }

  factory AttendanceSessionModel.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    final inLoc = map['clockInLocation'];
    final outLoc = map['clockOutLocation'];
    return AttendanceSessionModel(
      id: id ?? map['id'] as String? ?? '',
      storeId: map['storeId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      clockInAt: _requireDateTime(map['clockInAt']),
      clockInLocation: inLoc is Map<String, dynamic>
          ? GeoLocation.fromMap(inLoc)
          : const GeoLocation(latitude: 0, longitude: 0),
      clockOutAt: _toDateTime(map['clockOutAt']),
      clockOutLocation: outLoc is Map<String, dynamic>
          ? GeoLocation.fromMap(outLoc)
          : null,
      status: AttendanceSessionStatus.fromFirestore(
        map['status'] as String? ?? 'clockedIn',
      ),
      scheduleId: map['scheduleId'] as String?,
      hourlyWage: map['hourlyWage'] as int?,
      isApproved: map['isApproved'] as bool? ?? false,
      approvedBy: map['approvedBy'] as String?,
      approvedAt: _toDateTime(map['approvedAt']),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    return {
      'storeId': storeId,
      'userId': userId,
      'clockInAt': Timestamp.fromDate(clockInAt),
      'clockInLocation': clockInLocation.toMap(),
      if (clockOutAt != null) 'clockOutAt': Timestamp.fromDate(clockOutAt!),
      if (clockOutLocation != null)
        'clockOutLocation': clockOutLocation!.toMap(),
      'status': status.firestoreValue,
      if (scheduleId != null) 'scheduleId': scheduleId,
      if (hourlyWage != null) 'hourlyWage': hourlyWage,
      'isApproved': isApproved,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String get docPath => FirestorePaths.attendance(id);

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static DateTime _requireDateTime(dynamic value) {
    final parsed = _toDateTime(value);
    if (parsed == null) {
      throw ArgumentError('Invalid Timestamp/DateTime: $value');
    }
    return parsed;
  }

  @override
  List<Object?> get props => [
        id,
        storeId,
        userId,
        clockInAt,
        clockInLocation,
        clockOutAt,
        clockOutLocation,
        status,
        scheduleId,
        hourlyWage,
        isApproved,
        approvedBy,
        approvedAt,
        createdAt,
        updatedAt,
      ];
}
