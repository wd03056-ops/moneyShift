/// 방 생성 한도 초과 — UI에서 유료 결제 유도 팝업으로 분기
class RoomLimitExceededException implements Exception {
  const RoomLimitExceededException({
    required this.currentCount,
    required this.freeLimit,
  });

  final int currentCount;
  final int freeLimit;

  /// 유료 플랜 유도 여부 (3개째부터)
  bool get shouldShowPremiumUpsell => currentCount >= freeLimit;

  @override
  String toString() =>
      'RoomLimitExceededException(current=$currentCount, freeLimit=$freeLimit)';
}

class NotAuthenticatedException implements Exception {
  const NotAuthenticatedException([this.message = '로그인이 필요합니다.']);
  final String message;

  @override
  String toString() => message;
}

class RoomPermissionDeniedException implements Exception {
  const RoomPermissionDeniedException([
    this.message = '이 작업을 수행할 권한이 없습니다.',
  ]);
  final String message;

  @override
  String toString() => message;
}

class InviteInvalidException implements Exception {
  const InviteInvalidException([
    this.message = '존재하지 않거나 잘못된 초대 코드입니다.',
  ]);
  final String message;

  @override
  String toString() => message;
}

class AlreadyRoomMemberException implements Exception {
  const AlreadyRoomMemberException([this.message = '이미 속해 있는 방입니다.']);
  final String message;

  @override
  String toString() => message;
}

class RoomNotFoundException implements Exception {
  const RoomNotFoundException([this.message = '방을 찾을 수 없습니다.']);
  final String message;

  @override
  String toString() => message;
}
