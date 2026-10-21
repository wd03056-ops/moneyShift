import '../../../models/enums/notification_type.dart';
import 'notification_sanitizer.dart';

/// 푸시·알림함 공통 문구 템플릿 (Cloud Functions · 테스트 시뮬레이터 동기화)
abstract final class NotificationTemplates {
  NotificationTemplates._();

  // ----- 1. 직원 등록 -----
  static const staffJoinedTitle = '[직원 등록] 새로운 팀원이 합류했어요';
  static String staffJoinedBody(String displayName) =>
      '${_name(displayName)}님이 직원 등록을 했습니다.';

  // ----- 2. 근무 배정 -----
  static const scheduleAssignedTitle = '[근무 배정] 새로운 근무가 등록되었어요';
  static String scheduleAssignedBody(String storeName) =>
      '[${_name(storeName)}] 새로운 근무 일정이 배정되었습니다. 일정을 확인해 보세요.';

  // ----- 2-b. 직원이 배정 근무 확인 (알바 → 사장) -----
  static const scheduleConfirmedTitle = '[근무 확인] 배정 근무가 확인되었어요';
  static String scheduleConfirmedBody(String displayName) =>
      '${_name(displayName)}님이 배정된 근무 일정을 확인했습니다.';

  // ----- 3. 일정 변경 요청 (알바 → 사장) -----
  static const scheduleChangeRequestTitle = '[일정 변경 요청]';
  static String scheduleChangeRequestBody(String displayName) =>
      '${_name(displayName)}님이 근무 일정 변경을 요청했습니다.';

  // ----- 3-b. 일정 변경 요청 (사장 → 알바) -----
  static const ownerScheduleChangeRequestTitle = '[일정 변경 요청]';
  static String ownerScheduleChangeRequestBody(String storeName) =>
      '[${_name(storeName)}] 사장님이 근무 일정 변경을 요청했습니다. 확인해 주세요.';

  // ----- 4. 일정 변경 결과 (사장 → 알바) -----
  static const scheduleChangeResultTitle = '[일정 변경 결과]';
  static String scheduleChangeResultBody({required bool approved}) =>
      '요청하신 근무 일정 변경이 ${approved ? '승인' : '거절'}되었습니다.';

  // ----- 4-b. 직원이 사장 변경 요청에 응답 (알바 → 사장) -----
  static const staffScheduleChangeResultTitle = '[일정 변경 결과]';
  static String staffScheduleChangeResultBody({
    required String displayName,
    required bool approved,
  }) =>
      '${_name(displayName)}님이 일정 변경 요청을 '
      '${approved ? '수락' : '거절'}했습니다.';

  // ----- 5-1. 대타 요청 (A → B) -----
  static const swapRequestTitle = '[대타 요청] 근무 대타 요청이 도착했어요';
  static String swapRequestBody(String fromName) =>
      '${_name(fromName)}님이 근무 대타를 요청했습니다. 일정을 확인해 보세요.';

  // ----- 5-2. 대타 동료 수락 → 사장 -----
  static const swapOwnerApprovalTitle = '[대타 승인 요청] 근무자 변경 승인이 필요해요';
  static String swapOwnerApprovalBody({
    required String storeName,
    required String fromName,
    required String toName,
  }) =>
      '[${_name(storeName)}] ${_name(fromName)}님의 근무를 ${_name(toName)}님이 '
      '대신 수락했습니다. 최종 승인해 주세요.';

  // ----- 5-3. 사장 최종 승인 → A, B -----
  static const swapConfirmedTitle = '[대타 확정] 근무 일정이 변경되었습니다';
  static String swapConfirmedBody(String storeName) =>
      '[${_name(storeName)}] 사장님이 대타 요청을 최종 승인하여 근무표가 변경되었습니다.';

  // ----- 5-4. 대타 거절 (동료 또는 사장) -----
  static const swapRejectedTitle = '[대타 거절] 대타 요청이 거절되었어요';
  static String swapRejectedByColleagueBody(String toName) =>
      '${_name(toName)}님이 대타 요청을 거절했습니다.';
  static String swapRejectedByOwnerBody(String storeName) =>
      '[${_name(storeName)}] 사장님이 대타 요청을 거절했습니다.';

  // ----- 6. 출·퇴근 -----
  static const attendanceTitle = '[출퇴근 알림]';
  static String attendanceBody({
    required String displayName,
    required bool isClockIn,
  }) =>
      '${_name(displayName)}님이 ${isClockIn ? '출근' : '퇴근'}했습니다.';

  // ----- 7. 결근 -----
  static const absentTitle = '[근태 안내] 결근 처리되었습니다';
  static String absentBody(String storeName) =>
      '[${_name(storeName)}] 사장님에 의해 해당 근무 일정이 결근으로 처리되었습니다.';

  // ----- 8. 매장 공지 -----
  static const noticeTitle = '[매장 공지] 새로운 공지가 등록되었어요';
  static String noticeBody(String storeName) =>
      '[${_name(storeName)}] 사장님이 새로운 공지사항을 등록했습니다. 확인해 보세요!';

  // ----- 근태 수정 요청 (사장 → 알바) -----
  static const commuteCorrectionRequestTitle =
      '[근태 수정 요청] 출·퇴근 기록 수정 요청';
  static String commuteCorrectionRequestBody(String storeName) =>
      '[${_name(storeName)}] 사장님이 출·퇴근 시간 수정을 요청했습니다. '
      '확인 후 승인해 주세요.';

  // ----- 근태 수정 결과 (알바 → 사장) -----
  static const commuteCorrectionApprovedTitle = '[근태 수정 완료]';
  static String commuteCorrectionApprovedBody(String displayName) =>
      '${_name(displayName)}님이 근태 수정을 승인했습니다.';

  static const commuteCorrectionRejectedTitle = '[근태 수정 거절]';
  static String commuteCorrectionRejectedBody(String displayName) =>
      '${_name(displayName)}님이 근태 수정을 거절했습니다.';

  static String _name(String raw) {
    final s = NotificationSanitizer.sanitize(raw, maxLength: 40);
    return s.isEmpty ? '직원' : s;
  }
}

/// 알림 이벤트 → [NotificationType] 매핑
enum NotificationEventKind {
  staffJoined,
  scheduleAssigned,
  scheduleConfirmed,
  scheduleChangeRequested,
  scheduleChangeApproved,
  scheduleChangeRejected,
  swapRequested,
  swapColleagueAccepted,
  swapOwnerApproved,
  swapRejected,
  attendanceClockIn,
  attendanceClockOut,
  scheduleAbsent,
  storeNotice,
  commuteCorrectionRequested,
  commuteCorrectionApproved,
  commuteCorrectionRejected;

  NotificationType get notificationType {
    switch (this) {
      case NotificationEventKind.staffJoined:
        return NotificationType.register;
      case NotificationEventKind.scheduleAssigned:
        return NotificationType.assign;
      case NotificationEventKind.scheduleConfirmed:
        return NotificationType.scheduleConfirmed;
      case NotificationEventKind.scheduleChangeRequested:
        return NotificationType.requestUpdate;
      case NotificationEventKind.scheduleChangeApproved:
      case NotificationEventKind.scheduleChangeRejected:
        return NotificationType.resultUpdate;
      case NotificationEventKind.swapRequested:
        return NotificationType.subRequest;
      case NotificationEventKind.swapColleagueAccepted:
        return NotificationType.subAccept;
      case NotificationEventKind.swapOwnerApproved:
        return NotificationType.subConfirm;
      case NotificationEventKind.swapRejected:
        return NotificationType.resultUpdate;
      case NotificationEventKind.attendanceClockIn:
      case NotificationEventKind.attendanceClockOut:
        return NotificationType.commute;
      case NotificationEventKind.scheduleAbsent:
        return NotificationType.absent;
      case NotificationEventKind.storeNotice:
        return NotificationType.notice;
      case NotificationEventKind.commuteCorrectionRequested:
        return NotificationType.commuteCorrection;
      case NotificationEventKind.commuteCorrectionApproved:
      case NotificationEventKind.commuteCorrectionRejected:
        return NotificationType.commuteCorrectionResult;
    }
  }

  String get firestoreValue => notificationType.firestoreValue;
}
