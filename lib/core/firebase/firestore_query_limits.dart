/// Firestore 목록 조회 상한 — 읽기 요금·대역폭 폭탄 방어
abstract final class FirestoreQueryLimits {
  FirestoreQueryLimits._();

  /// 일반 목록 (멤버·초대·요청 등)
  static const int list = 40;

  /// 스케줄·출퇴근 이력 등 시계열
  static const int timeline = 60;

  /// 알림함
  static const int inbox = 40;

  /// 매장/방 목록 (소유 한도가 작아도 상한 유지)
  static const int rooms = 20;

  /// 탈퇴 익명화 등 배치 작업 페이지
  static const int batchPage = 100;
}
