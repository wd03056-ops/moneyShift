import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_paths.dart';
import 'geo_location.dart';

/// `rooms/{roomId}` 문서 — 매장(방)
class RoomModel extends Equatable {
  const RoomModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.location,
    this.geofenceRadiusMeters = AppConstants.attendanceGeofenceRadiusMeters,
    this.memberCount = 1,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final GeoLocation location;

  /// 출퇴근 허용 반경 (기본 100m)
  final double geofenceRadiusMeters;

  final int memberCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RoomModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RoomModel.fromMap(data, id: doc.id);
  }

  factory RoomModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final loc = map['location'];
    return RoomModel(
      id: id ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      location: loc is Map<String, dynamic>
          ? GeoLocation.fromMap(loc)
          : const GeoLocation(latitude: 0, longitude: 0),
      geofenceRadiusMeters:
          (map['geofenceRadiusMeters'] as num?)?.toDouble() ??
              AppConstants.attendanceGeofenceRadiusMeters,
      memberCount: map['memberCount'] as int? ?? 0,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore({bool forCreate = false}) {
    return {
      'name': name,
      'ownerId': ownerId,
      'location': location.toMap(),
      'geofenceRadiusMeters': geofenceRadiusMeters,
      'memberCount': memberCount,
      'updatedAt': FieldValue.serverTimestamp(),
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  RoomModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    GeoLocation? location,
    double? geofenceRadiusMeters,
    int? memberCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      location: location ?? this.location,
      geofenceRadiusMeters:
          geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get docPath => FirestorePaths.room(id);

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        ownerId,
        location,
        geofenceRadiusMeters,
        memberCount,
        createdAt,
        updatedAt,
      ];
}
