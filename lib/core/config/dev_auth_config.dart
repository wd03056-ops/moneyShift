import 'package:flutter/foundation.dart';

/// 개발용 Mock 인증 스위치
///
/// - [useMockAuth] 를 `false` 로 바꾸면 실제 카카오 SDK 로그인으로 전환됩니다.
/// - 릴리즈 빌드에서는 항상 꺼집니다 (`kDebugMode` 가드).
/// - CLI: `--dart-define=USE_MOCK_AUTH=false`
class DevAuthConfig {
  DevAuthConfig._();

  /// 여기만 바꿔도 됩니다. `true` = Mock UID, `false` = 카카오 로그인.
  static const bool useMockAuth = bool.fromEnvironment(
    'USE_MOCK_AUTH',
    defaultValue: true,
  );

  /// 앱 시작 시 Mock 사장으로 자동 로그인
  static const bool autoSignInOnLaunch = true;

  /// 디버그 + 플래그가 모두 켜진 경우에만 Mock 경로 사용
  static bool get isMockAuthEnabled => kDebugMode && useMockAuth;

  static void logStatus() {
    if (!kDebugMode) return;
    debugPrint(
      '[DevAuth] useMockAuth=$useMockAuth '
      'enabled=$isMockAuthEnabled '
      'autoSignIn=$autoSignInOnLaunch',
    );
  }
}
