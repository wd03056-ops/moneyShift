/// 카카오·Firebase·토큰 교환 흐름에서 사용자에게 보여줄 인증 오류
class AuthFlowException implements Exception {
  const AuthFlowException(
    this.message, {
    this.code = 'auth_flow',
    this.userCancelled = false,
    this.network = false,
  });

  final String message;
  final String code;

  /// 사용자가 카카오 동의/로그인 창을 닫음 — UI 알림 생략
  final bool userCancelled;

  /// 네트워크/타임아웃
  final bool network;

  @override
  String toString() => 'AuthFlowException($code): $message';
}
