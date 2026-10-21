import '../../../models/enums/shift_request_status.dart';
import '../../../models/enums/shift_request_type.dart';
import '../../../models/schedule_model.dart';
import '../../../models/shift_request_model.dart';
import '../../../services/schedule_assign_service.dart';
import '../../../services/shift_request_service.dart';

/// 근무 배정·변경 요청 도메인 서비스 (features/schedule)
///
/// 푸시 알림은 Firestore 트리거 Cloud Functions 가 처리합니다.
class ScheduleService {
  ScheduleService({
    ScheduleAssignService? assign,
    ShiftRequestService? requests,
  })  : _assign = assign ?? ScheduleAssignService(),
        _requests = requests ?? ShiftRequestService();

  static final ScheduleService instance = ScheduleService();

  final ScheduleAssignService _assign;
  final ShiftRequestService _requests;

  /// 사장이 알바생에게 근무 배정 (+ FCM 알림)
  Future<ScheduleModel> assignShift({
    required String storeId,
    required String createdBy,
    required String workerUid,
    required DateTime startTime,
    required DateTime endTime,
    required int hourlyWage,
    int breakMinutes = 0,
    String? note,
    String? storeName,
  }) {
    return _assign.assign(
      storeId: storeId,
      createdBy: createdBy,
      workerUid: workerUid,
      startTime: startTime,
      endTime: endTime,
      hourlyWage: hourlyWage,
      breakMinutes: breakMinutes,
      note: note,
      storeName: storeName,
    );
  }

  Future<ScheduleModel> updateShift({
    required String scheduleId,
    required String actorUid,
    DateTime? startTime,
    DateTime? endTime,
    int? hourlyWage,
    int? breakMinutes,
    String? note,
  }) {
    return _assign.update(
      scheduleId: scheduleId,
      actorUid: actorUid,
      startTime: startTime,
      endTime: endTime,
      hourlyWage: hourlyWage,
      breakMinutes: breakMinutes,
      note: note,
    );
  }

  /// 사장 또는 권한 검증 후 삭제
  Future<void> deleteShift({
    required String scheduleId,
    required String actorUid,
  }) {
    return _assign.delete(scheduleId: scheduleId, actorUid: actorUid);
  }

  Future<ShiftRequestModel> requestChange({
    required String storeId,
    required String applicantUid,
    required ShiftRequestType type,
    String? scheduleId,
    String? targetWorkerUid,
    String? reason,
    DateTime? proposedStart,
    DateTime? proposedEnd,
    String? notifyApproverUid,
  }) {
    return _requests.create(
      storeId: storeId,
      applicantUid: applicantUid,
      type: type,
      scheduleId: scheduleId,
      targetWorkerUid: targetWorkerUid,
      reason: reason,
      proposedStart: proposedStart,
      proposedEnd: proposedEnd,
      notifyApproverUid: notifyApproverUid,
    );
  }

  Future<ShiftRequestModel> resolveRequest({
    required String requestId,
    required String approverUid,
    required bool approve,
  }) {
    return _requests.resolve(
      requestId: requestId,
      approverUid: approverUid,
      approve: approve,
    );
  }

  Future<List<ShiftRequestModel>> listPending(String storeId) {
    return _requests.listByStore(
      storeId,
      status: ShiftRequestStatus.pending,
    );
  }
}
