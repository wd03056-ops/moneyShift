import '../../../core/constants/app_constants.dart';
import '../../../core/geo/geo_distance.dart';
import '../../../models/geo_location.dart';
import '../../../services/attendance_location_service.dart';

/// GPS 출퇴근 반경 검증 (Haversine)
///
/// Clean Architecture — `features/attendance`
class GeofenceService {
  GeofenceService({AttendanceLocationService? locationService})
      : _location = locationService ?? const AttendanceLocationService();

  final AttendanceLocationService _location;

  /// 두 좌표 사이 거리(m)
  double distanceMeters({
    required double storeLat,
    required double storeLng,
    required double userLat,
    required double userLng,
  }) {
    return distanceMetersHaversine(
      lat1: storeLat,
      lon1: storeLng,
      lat2: userLat,
      lon2: userLng,
    );
  }

  /// 반경 이내 여부만 판정
  bool isWithinRadius({
    required double storeLat,
    required double storeLng,
    required double userLat,
    required double userLng,
    double radiusMeters = AppConstants.attendanceGeofenceRadiusMeters,
  }) {
    return distanceMeters(
          storeLat: storeLat,
          storeLng: storeLng,
          userLat: userLat,
          userLng: userLng,
        ) <=
        radiusMeters;
  }

  /// 현재 GPS 취득 + 매장 좌표 대비 반경 검증
  Future<AttendanceGeoCheckResult> verifyClockInOut({
    required GeoLocation storeLocation,
    double radiusMeters = AppConstants.attendanceGeofenceRadiusMeters,
    bool bypass = false,
  }) {
    return _location.checkWithinGeofence(
      storeLocation: storeLocation,
      radiusMeters: radiusMeters,
      bypass: bypass,
    );
  }
}
