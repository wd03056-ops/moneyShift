/// 알림 이벤트 타입 — Firestore `type` / FCM data.type
///
/// 레거시 문자열도 [fromFirestore] 로 수용합니다.
enum NotificationType {
  /// 직원 등록 (초대 코드 가입)
  register,

  /// 근무 배정
  assign,

  /// 직원이 배정 근무를 확인 (알바 → 사장)
  scheduleConfirmed,

  /// 일정 변경 요청 (알바 → 사장)
  requestUpdate,

  /// 일정 변경 결과 (사장 → 알바)
  resultUpdate,

  /// 대타 요청 (A → B)
  subRequest,

  /// 대타 동료 수락 → 사장 승인 요청
  subAccept,

  /// 대타 사장 최종 승인 → A, B
  subConfirm,

  /// 출·퇴근
  commute,

  /// 결근 수동 처리
  absent,

  /// 매장 공지
  notice,

  /// 근태 수정 요청 (사장 → 알바)
  commuteCorrection,

  /// 근태 수정 결과 (알바 → 사장)
  commuteCorrectionResult,

  /// 기타/레거시
  generic;

  String get firestoreValue {
    switch (this) {
      case NotificationType.register:
        return 'register';
      case NotificationType.assign:
        return 'assign';
      case NotificationType.scheduleConfirmed:
        return 'schedule_confirmed';
      case NotificationType.requestUpdate:
        return 'request_update';
      case NotificationType.resultUpdate:
        return 'result_update';
      case NotificationType.subRequest:
        return 'sub_request';
      case NotificationType.subAccept:
        return 'sub_accept';
      case NotificationType.subConfirm:
        return 'sub_confirm';
      case NotificationType.commute:
        return 'commute';
      case NotificationType.absent:
        return 'absent';
      case NotificationType.notice:
        return 'notice';
      case NotificationType.commuteCorrection:
        return 'commute_correction';
      case NotificationType.commuteCorrectionResult:
        return 'commute_correction_result';
      case NotificationType.generic:
        return 'generic';
    }
  }

  String get labelKo {
    switch (this) {
      case NotificationType.register:
        return '직원 등록';
      case NotificationType.assign:
        return '근무 배정';
      case NotificationType.scheduleConfirmed:
        return '근무 확인';
      case NotificationType.requestUpdate:
        return '일정 변경 요청';
      case NotificationType.resultUpdate:
        return '일정 변경 결과';
      case NotificationType.subRequest:
        return '대타 요청';
      case NotificationType.subAccept:
        return '대타 승인 요청';
      case NotificationType.subConfirm:
        return '대타 확정';
      case NotificationType.commute:
        return '출퇴근';
      case NotificationType.absent:
        return '결근';
      case NotificationType.notice:
        return '매장 공지';
      case NotificationType.commuteCorrection:
        return '근태 수정 요청';
      case NotificationType.commuteCorrectionResult:
        return '근태 수정 결과';
      case NotificationType.generic:
        return '알림';
    }
  }

  static NotificationType fromFirestore(String? value) {
    switch (value) {
      case 'register':
      case 'staff_joined':
        return NotificationType.register;
      case 'assign':
      case 'schedule_assigned':
        return NotificationType.assign;
      case 'schedule_confirmed':
        return NotificationType.scheduleConfirmed;
      case 'request_update':
      case 'schedule_change_requested':
      case 'shift_request_created':
        return NotificationType.requestUpdate;
      case 'result_update':
      case 'schedule_change_approved':
      case 'schedule_change_rejected':
      case 'shift_request_approved':
      case 'shift_request_rejected':
        return NotificationType.resultUpdate;
      case 'sub_request':
      case 'swap_requested':
        return NotificationType.subRequest;
      case 'sub_accept':
      case 'swap_colleague_accepted':
        return NotificationType.subAccept;
      case 'sub_confirm':
      case 'swap_owner_approved':
        return NotificationType.subConfirm;
      case 'commute':
      case 'attendance_clock_in':
      case 'attendance_clock_out':
        return NotificationType.commute;
      case 'absent':
      case 'schedule_absent':
        return NotificationType.absent;
      case 'notice':
      case 'store_notice':
        return NotificationType.notice;
      case 'commute_correction':
        return NotificationType.commuteCorrection;
      case 'commute_correction_result':
      case 'commute_correction_approved':
      case 'commute_correction_rejected':
        return NotificationType.commuteCorrectionResult;
      default:
        return NotificationType.generic;
    }
  }
}
