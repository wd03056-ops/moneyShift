import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/constants/app_constants.dart';
import '../core/geo/geo_distance.dart';
import '../models/geo_location.dart';

/// GPS 출퇴근 반경 검증 결과
class AttendanceGeoCheckResult {
  const AttendanceGeoCheckResult({
    required this.allowed,
    required this.distanceMeters,
    required this.location,
    this.errorMessage,
  });

  final bool allowed;
  final double distanceMeters;
  final GeoLocation location;
  final String? errorMessage;

  bool get isError => errorMessage != null && !allowed;
}

/// 매장 좌표 대비 직원 현재 위치 검증 (기본 100m)
class AttendanceLocationService {
  const AttendanceLocationService();

  static const outOfRangeMessage = '매장 반경 100m 이내에서만 출퇴근이 가능합니다.';

  /// [bypass] true면 GPS를 읽지 않고 매장 좌표로 통과(목업/테스트용).
  Future<AttendanceGeoCheckResult> checkWithinGeofence({
    required GeoLocation storeLocation,
    double radiusMeters = AppConstants.attendanceGeofenceRadiusMeters,
    bool bypass = false,
  }) async {
    if (bypass) {
      return AttendanceGeoCheckResult(
        allowed: true,
        distanceMeters: 0,
        location: GeoLocation(
          latitude: storeLocation.latitude,
          longitude: storeLocation.longitude,
          isMocked: true,
        ),
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: -1,
        location: GeoLocation(latitude: 0, longitude: 0),
        errorMessage: '위치 서비스가 꺼져 있습니다. 설정에서 GPS를 켜 주세요.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: -1,
        location: GeoLocation(latitude: 0, longitude: 0),
        errorMessage: '위치 권한이 필요합니다. 설정에서 허용해 주세요.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      return const AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: -1,
        location: GeoLocation(latitude: 0, longitude: 0),
        errorMessage: '위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 허용해 주세요.',
      );
    }

    late final Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      return const AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: -1,
        location: GeoLocation(latitude: 0, longitude: 0),
        errorMessage: '위치 확인 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.',
      );
    } on PermissionDeniedException {
      return const AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: -1,
        location: GeoLocation(latitude: 0, longitude: 0),
        errorMessage: '위치 권한이 필요합니다. 설정에서 허용해 주세요.',
      );
    } on LocationServiceDisabledException {
      return const AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: -1,
        location: GeoLocation(latitude: 0, longitude: 0),
        errorMessage: '위치 서비스가 꺼져 있습니다. 설정에서 GPS를 켜 주세요.',
      );
    } catch (_) {
      return const AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: -1,
        location: GeoLocation(latitude: 0, longitude: 0),
        errorMessage: '위치를 가져오지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }

    final distance = distanceMetersHaversine(
      lat1: storeLocation.latitude,
      lon1: storeLocation.longitude,
      lat2: pos.latitude,
      lon2: pos.longitude,
    );

    final location = GeoLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      isMocked: pos.isMocked,
    );

    if (distance > radiusMeters) {
      return AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: distance,
        location: location,
        errorMessage: outOfRangeMessage,
      );
    }

    return AttendanceGeoCheckResult(
      allowed: true,
      distanceMeters: distance,
      location: location,
    );
  }
}
