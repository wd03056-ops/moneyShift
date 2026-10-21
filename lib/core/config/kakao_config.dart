/// 카카오 네이티브 앱 키 및 플랫폼 식별자
///
/// 키 우선순위:
/// 1. `--dart-define=KAKAO_NATIVE_APP_KEY=...`
/// 2. [fallbackNativeAppKey] (로컬 개발용 기본값)
///
/// Android Manifest / iOS Info.plist 스킴도 동일 값으로 맞춰야 합니다.
/// 자세한 등록 절차: `docs/KAKAO_LOGIN_SETUP.md`
class KakaoConfig {
  KakaoConfig._();

  /// `--dart-define=KAKAO_NATIVE_APP_KEY=` 로 주입. 없으면 [fallbackNativeAppKey].
  static const String nativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: fallbackNativeAppKey,
  );

  /// 카카오디벨로퍼스 네이티브 앱 키 (디버그·릴리즈 공통)
  /// Android `kakao.properties` / iOS `Kakao-Keys.xcconfig` 와 동일.
  static const String fallbackNativeAppKey =
      'f180fab248825101fa969428a27827e8';

  static const String _unsetPlaceholder = 'YOUR_NATIVE_APP_KEY';

  /// Android 패키지명 (카카오 콘솔 [앱] > [플랫폼 키] > Android)
  static const String androidPackageName = 'com.money.money_shift';

  /// iOS Bundle ID (카카오 콘솔 [앱] > [플랫폼 키] > iOS)
  static const String iosBundleId = 'com.money.moneyShift';

  /// Redirect URI: `kakao{NATIVE_APP_KEY}://oauth`
  static String get redirectUri => 'kakao$nativeAppKey://oauth';

  static bool get isConfigured =>
      nativeAppKey.isNotEmpty && nativeAppKey != _unsetPlaceholder;
}
