import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/firestore_paths.dart';
import 'geo_location.dart';

/// `stores/{storeId}` 문서 — 매장
class StoreModel extends Equatable {
  const StoreModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.location,
    this.geofenceRadiusMeters = AppConstants.attendanceGeofenceRadiusMeters,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final GeoLocation location;
  final double geofenceRadiusMeters;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory StoreModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StoreModel.fromMap(data, id: doc.id);
  }

  factory StoreModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final loc = map['location'];
    return StoreModel(
      id: id ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      location: loc is Map<String, dynamic>
          ? GeoLocation.fromMap(loc)
          : const GeoLocation(latitude: 0, longitude: 0),
      geofenceRadiusMeters:
          (map['geofenceRadiusMeters'] as num?)?.toDouble() ??
              AppConstants.attendanceGeofenceRadiusMeters,
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
      'updatedAt': FieldValue.serverTimestamp(),
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  StoreModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    GeoLocation? location,
    double? geofenceRadiusMeters,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      location: location ?? this.location,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get docPath => FirestorePaths.store(id);

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
        createdAt,
        updatedAt,
      ];
}
