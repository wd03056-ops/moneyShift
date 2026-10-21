import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// 위도·경도 공통 모델 (매장 위치 / 출퇴근 GPS)
class GeoLocation extends Equatable {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.address,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? address;
  final bool isMocked;

  factory GeoLocation.fromMap(Map<String, dynamic> map) {
    return GeoLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      address: map['address'] as String?,
      isMocked: map['isMocked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (address != null) 'address': address,
      'isMocked': isMocked,
    };
  }

  /// Firestore GeoPoint 변환 (쿼리용, 필요 시)
  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);

  @override
  List<Object?> get props => [latitude, longitude, accuracy, address, isMocked];
}
