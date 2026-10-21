import '../../../core/constants/app_constants.dart';
import '../../../models/attendance_session_model.dart';
import '../../../models/store_model.dart';
import '../../../services/attendance_firestore_service.dart';
import 'geofence_service.dart';

/// 출퇴근 도메인 서비스 — 반경 검증 후 Firestore 기록
class AttendanceService {
  AttendanceService({
    AttendanceFirestoreService? firestore,
    GeofenceService? geofence,
  })  : _firestore = firestore ?? AttendanceFirestoreService(),
        _geofence = geofence ?? GeofenceService();

  static final AttendanceService instance = AttendanceService();

  final AttendanceFirestoreService _firestore;
  final GeofenceService _geofence;

  /// 반경 통과 시에만 출근 기록
  Future<AttendanceSessionModel> clockIn({
    required StoreModel store,
    required String workerUid,
    String? scheduleId,
    int? hourlyWage,
    bool bypassGeofence = false,
  }) async {
    final check = await _geofence.verifyClockInOut(
      storeLocation: store.location,
      radiusMeters: store.geofenceRadiusMeters > 0
          ? store.geofenceRadiusMeters
          : AppConstants.attendanceGeofenceRadiusMeters,
      bypass: bypassGeofence,
    );
    if (!check.allowed) {
      throw StateError(check.errorMessage ?? '출퇴근 위치가 유효하지 않습니다.');
    }

    return _firestore.clockIn(
      storeId: store.id,
      userId: workerUid,
      location: check.location,
      scheduleId: scheduleId,
      hourlyWage: hourlyWage,
    );
  }

  Future<AttendanceSessionModel> clockOut({
    required String attendanceId,
    required String actorUid,
    required StoreModel store,
    bool bypassGeofence = false,
  }) async {
    final check = await _geofence.verifyClockInOut(
      storeLocation: store.location,
      radiusMeters: store.geofenceRadiusMeters > 0
          ? store.geofenceRadiusMeters
          : AppConstants.attendanceGeofenceRadiusMeters,
      bypass: bypassGeofence,
    );
    if (!check.allowed) {
      throw StateError(check.errorMessage ?? '출퇴근 위치가 유효하지 않습니다.');
    }

    return _firestore.clockOut(
      attendanceId: attendanceId,
      actorUid: actorUid,
      location: check.location,
    );
  }

  Future<AttendanceSessionModel> approve({
    required String attendanceId,
    required String approverUid,
  }) {
    return _firestore.approve(
      attendanceId: attendanceId,
      approverUid: approverUid,
    );
  }

  Future<void> delete({
    required String attendanceId,
    required String actorUid,
  }) {
    return _firestore.delete(
      attendanceId: attendanceId,
      actorUid: actorUid,
    );
  }

  Future<List<AttendanceSessionModel>> listByWorker(
    String workerUid, {
    String? storeId,
  }) {
    return _firestore.listByUser(workerUid, storeId: storeId);
  }
}
