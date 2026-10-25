/// 앱 전역 상수
class AppConstants {
  AppConstants._();

  static const String appName = 'Money Shift';
  static const String packageName = 'com.money.money_shift';

  /// pubspec.yaml `version:` 과 동기화 (plugin 없이 표시)
  static const String appVersionName = '1.0.0';
  static const String appVersionCode = '1';
  static String get appVersionLabel =>
      '앱 버전 $appVersionName ($appVersionCode)';


  /// Play Console·문의용
  static const String supportEmail = 'baekson777@gmail.com';
  static const String developerName = 'Money Shift';

  /// 호스팅된 개인정보처리방침·이용약관 (Play Console 제출용)
  /// `/privacy` 는 Vercel에서 Notion으로 302 리다이렉트
  static const String privacyPolicyUrl =
      'https://moneyshift-ten.vercel.app/privacy';
  static const String termsOfServiceUrl =
      'https://giddy-gaura-998.notion.site/Terms-Conditions-401ad28bec5c8067b331cf4858ed20ac';

  /// 계정·데이터 삭제 요청 웹 페이지 (Play Console 계정 삭제 URL)
  static const String accountDeletionUrl =
      'https://moneyshift-ten.vercel.app/delete-account';

  /// 초대·앱링크 호스트 (웹 랜딩 + Android App Links / iOS Universal Links)
  static const String appLinkHost = 'moneyshift.app';
  static const String inviteWebBaseUrl = 'https://$appLinkHost/join';

  /// 커스텀 스킴 (하위 호환·앱 내부 fallback)
  static const String appCustomScheme = 'moneyshift';

  /// 스토어 (앱 미설치 시 웹 랜딩에서 리다이렉트)
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$packageName';
  static const String appStoreUrl =
      'https://apps.apple.com/app/id0000000000'; // 배포 전 실제 App ID로 교체

  /// 만 14세 미만 이용 불가 (청소년 보호·Play 대상 연령)
  static const int minimumAgeYears = 14;

  /// 무료 플랜: 사장 1인당 생성 가능한 최대 방(매장) 수
  /// 3개 이상은 추후 유료화 예정
  static const int freeMaxOwnedRooms = 2;

  /// 출퇴근 허용 반경 (미터)
  static const double attendanceGeofenceRadiusMeters = 100.0;

  /// 2026년 적용 최저시급 (고용노동부 고시)
  static const int minimumWageYear = 2026;
  static const int minimumHourlyWage = 10320;

  /// 탈퇴 회원 표시명 (매장 근무·급여 기록용 — API와 동일)
  static const String deletedMemberDisplayName = '(탈퇴한 회원)';

  /// FCM / 알림 타입 (NotificationType · Cloud Functions 동기화)
  static const String fcmTypeRegister = 'register';
  static const String fcmTypeAssign = 'assign';
  static const String fcmTypeRequestUpdate = 'request_update';
  static const String fcmTypeResultUpdate = 'result_update';
  static const String fcmTypeSubRequest = 'sub_request';
  static const String fcmTypeSubAccept = 'sub_accept';
  static const String fcmTypeSubConfirm = 'sub_confirm';
  static const String fcmTypeCommute = 'commute';
  static const String fcmTypeAbsent = 'absent';
  static const String fcmTypeNotice = 'notice';

  /// 레거시 alias (읽기 호환)
  static const String fcmTypeScheduleAssigned = fcmTypeAssign;
  static const String fcmTypeStaffJoined = fcmTypeRegister;
  static const String fcmTypeScheduleChangeRequested = fcmTypeRequestUpdate;
  static const String fcmTypeScheduleChangeApproved = fcmTypeResultUpdate;
  static const String fcmTypeScheduleChangeRejected = fcmTypeResultUpdate;
  static const String fcmTypeSwapRequested = fcmTypeSubRequest;
  static const String fcmTypeSwapColleagueAccepted = fcmTypeSubAccept;
  static const String fcmTypeSwapOwnerApproved = fcmTypeSubConfirm;
  static const String fcmTypeAttendanceClockIn = fcmTypeCommute;
  static const String fcmTypeAttendanceClockOut = fcmTypeCommute;
  static const String fcmTypeScheduleAbsent = fcmTypeAbsent;
  static const String fcmTypeStoreNotice = fcmTypeNotice;
  static const String fcmTypeScheduleConfirmed = 'schedule_confirmed';
  static const String fcmTypeShiftRequestCreated = fcmTypeRequestUpdate;
  static const String fcmTypeShiftRequestApproved = fcmTypeResultUpdate;
  static const String fcmTypeShiftRequestRejected = fcmTypeResultUpdate;
  static const String fcmTypeAttendanceApproved = 'attendance_approved';
}
