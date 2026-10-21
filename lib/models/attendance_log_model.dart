import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/firestore_paths.dart';
import 'enums/attendance_type.dart';
import 'geo_location.dart';

/// `attendance_logs/{logId}` 문서 — GPS 기반 출퇴근 기록
class AttendanceLogModel extends Equatable {
  const AttendanceLogModel({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.type,
    required this.timestamp,
    required this.location,
    required this.distanceFromStoreMeters,
    required this.isValid,
    this.scheduleId,
    this.rejectionReason,
    this.createdAt,
  });

  final String id;
  final String roomId;
  final String userId;
  final AttendanceType type;
  final DateTime timestamp;
  final GeoLocation location;

  /// 매장 중심 좌표와의 거리 (미터)
  final double distanceFromStoreMeters;

  /// 반경 내 + 모의 위치 아님 → true
  final bool isValid;

  final String? scheduleId;

  /// 실패 사유: `out_of_range` | `mocked_location` | `permission_denied` 등
  final String? rejectionReason;

  final DateTime? createdAt;

  factory AttendanceLogModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AttendanceLogModel.fromMap(data, id: doc.id);
  }

  factory AttendanceLogModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final loc = map['location'];
    return AttendanceLogModel(
      id: id ?? map['id'] as String? ?? '',
      roomId: map['roomId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      type: AttendanceType.fromFirestore(
        map['type'] as String? ?? 'clock_in',
      ),
      timestamp: _requireDateTime(map['timestamp']),
      location: loc is Map<String, dynamic>
          ? GeoLocation.fromMap(loc)
          : const GeoLocation(latitude: 0, longitude: 0),
      distanceFromStoreMeters:
          (map['distanceFromStoreMeters'] as num?)?.toDouble() ?? 0,
      isValid: map['isValid'] as bool? ?? false,
      scheduleId: map['scheduleId'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      createdAt: _toDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    return {
      'roomId': roomId,
      'userId': userId,
      'type': type.firestoreValue,
      'timestamp': Timestamp.fromDate(timestamp),
      'location': location.toMap(),
      'distanceFromStoreMeters': distanceFromStoreMeters,
      'isValid': isValid,
      if (scheduleId != null) 'scheduleId': scheduleId,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String get docPath => FirestorePaths.attendanceLog(id);

  AttendanceLogModel copyWith({
    DateTime? timestamp,
    String? scheduleId,
    String? rejectionReason,
    bool? isValid,
  }) {
    return AttendanceLogModel(
      id: id,
      roomId: roomId,
      userId: userId,
      type: type,
      timestamp: timestamp ?? this.timestamp,
      location: location,
      distanceFromStoreMeters: distanceFromStoreMeters,
      isValid: isValid ?? this.isValid,
      scheduleId: scheduleId ?? this.scheduleId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
    );
  }

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
        roomId,
        userId,
        type,
        timestamp,
        location,
        distanceFromStoreMeters,
        isValid,
        scheduleId,
        rejectionReason,
        createdAt,
      ];
}
