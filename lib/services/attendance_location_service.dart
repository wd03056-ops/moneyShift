import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/constants/app_constants.dart';
import '../models/geo_location.dart';

/// GPS 출퇴근 반경 검증 실패 유형
enum AttendanceGeoFailKind {
  /// 허용 반경 밖
  outOfRange,

  /// 권한·GPS 비활성
  permissionOrGps,

  /// 타임아웃 등 기타
  other,
}

/// GPS 출퇴근 반경 검증 결과
class AttendanceGeoCheckResult {
  const AttendanceGeoCheckResult({
    required this.allowed,
    required this.distanceMeters,
    required this.location,
    this.errorMessage,
    this.failKind,
    this.radiusMeters,
  });

  final bool allowed;
  final double distanceMeters;
  final GeoLocation location;
  final String? errorMessage;
  final AttendanceGeoFailKind? failKind;

  /// 검증에 사용된 허용 반경(m). outOfRange 일 때 표시용.
  final double? radiusMeters;

  bool get isError => errorMessage != null && !allowed;
  bool get isOutOfRange => failKind == AttendanceGeoFailKind.outOfRange;
  bool get isPermissionOrGps =>
      failKind == AttendanceGeoFailKind.permissionOrGps;
}

/// 매장 좌표 대비 직원 현재 위치 검증 (Geolocator)
class AttendanceLocationService {
  const AttendanceLocationService();

  static const permissionOrGpsMessage =
      '출퇴근 기록을 위해 위치 권한 및 GPS를 활성화해 주세요.';

  static String outOfRangeMessage({
    required double distanceMeters,
    required double radiusMeters,
  }) {
    final d = distanceMeters.round().clamp(0, 999999);
    final r = radiusMeters.round().clamp(0, 999999);
    return '현재 매장 위치(출퇴근 허용 반경)에서 벗어나 있습니다.\n'
        '매장 근처로 이동한 후 다시 시도해 주세요.\n'
        '(현재 매장과의 거리: 약 ${d}m / 허용 반경: ${r}m)';
  }

  /// [bypass] true면 GPS를 읽지 않고 매장 좌표로 통과(목업/테스트용).
  Future<AttendanceGeoCheckResult> checkWithinGeofence({
    required GeoLocation storeLocation,
    double radiusMeters = AppConstants.attendanceGeofenceRadiusMeters,
    bool bypass = false,
  }) async {
    final radius = radiusMeters > 0
        ? radiusMeters
        : AppConstants.attendanceGeofenceRadiusMeters;

    if (bypass) {
      return AttendanceGeoCheckResult(
        allowed: true,
        distanceMeters: 0,
        location: GeoLocation(
          latitude: storeLocation.latitude,
          longitude: storeLocation.longitude,
          isMocked: true,
        ),
        radiusMeters: radius,
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: -1,
        location: GeoLocation(latitude: 0, longitude: 0),
        errorMessage: permissionOrGpsMessage,
        failKind: AttendanceGeoFailKind.permissionOrGps,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: -1,
        location: GeoLocation(latitude: 0, longitude: 0),
        errorMessage: permissionOrGpsMessage,
        failKind: AttendanceGeoFailKind.permissionOrGps,
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
        failKind: AttendanceGeoFailKind.other,
      );
    } on PermissionDeniedException {
      return const AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: -1,
        location: GeoLocation(latitude: 0, longitude: 0),
        errorMessage: permissionOrGpsMessage,
        failKind: AttendanceGeoFailKind.permissionOrGps,
      );
    } on LocationServiceDisabledException {
      return const AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: -1,
        location: GeoLocation(latitude: 0, longitude: 0),
        errorMessage: permissionOrGpsMessage,
        failKind: AttendanceGeoFailKind.permissionOrGps,
      );
    } catch (_) {
      return const AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: -1,
        location: GeoLocation(latitude: 0, longitude: 0),
        errorMessage: '위치를 가져오지 못했습니다. 잠시 후 다시 시도해 주세요.',
        failKind: AttendanceGeoFailKind.other,
      );
    }

    final distance = Geolocator.distanceBetween(
      storeLocation.latitude,
      storeLocation.longitude,
      pos.latitude,
      pos.longitude,
    );

    final location = GeoLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      isMocked: pos.isMocked,
    );

    if (distance > radius) {
      return AttendanceGeoCheckResult(
        allowed: false,
        distanceMeters: distance,
        location: location,
        errorMessage: outOfRangeMessage(
          distanceMeters: distance,
          radiusMeters: radius,
        ),
        failKind: AttendanceGeoFailKind.outOfRange,
        radiusMeters: radius,
      );
    }

    return AttendanceGeoCheckResult(
      allowed: true,
      distanceMeters: distance,
      location: location,
      radiusMeters: radius,
    );
  }
}
