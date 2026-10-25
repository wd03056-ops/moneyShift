import 'package:flutter/foundation.dart';

/// AdMob 단위 ID · 플랫폼 지원 여부
///
/// 개발(`kDebugMode`)에서는 Google 공식 테스트 ID만 사용한다.
/// 릴리즈는 `--dart-define=ADMOB_BANNER_ID=...` 등으로 교체한다.
abstract final class AdConfig {
  AdConfig._();

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get useTestAds =>
      kDebugMode ||
      const bool.fromEnvironment('USE_TEST_ADS', defaultValue: false);

  /// Android [MainActivity] 에 등록한 네이티브 팩토리 ID
  static const nativeFactoryId = 'listTile';

  // —— Google 테스트 단위 (Android) ——
  static const _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const _testNativeAndroid =
      'ca-app-pub-3940256099942544/2247696110';
  static const _testNativeVideoAndroid =
      'ca-app-pub-3940256099942544/1044960115';

  // —— Google 테스트 단위 (iOS) ——
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testNativeIos = 'ca-app-pub-3940256099942544/3986624511';
  static const _testNativeVideoIos =
      'ca-app-pub-3940256099942544/2521693116';

  static bool get _isAndroid =>
      defaultTargetPlatform == TargetPlatform.android;

  static String get bannerAdUnitId {
    if (useTestAds) {
      return _isAndroid ? _testBannerAndroid : _testBannerIos;
    }
    const fromEnv = String.fromEnvironment('ADMOB_BANNER_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    // 프로덕션 ID 미설정 시에도 정책상 테스트 ID 유지
    return _isAndroid ? _testBannerAndroid : _testBannerIos;
  }

  static String get nativeAdUnitId {
    if (useTestAds) {
      return _isAndroid ? _testNativeAndroid : _testNativeIos;
    }
    const fromEnv = String.fromEnvironment('ADMOB_NATIVE_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _isAndroid ? _testNativeAndroid : _testNativeIos;
  }

  /// 일반 네이티브 실패 시 폴백용 비디오 네이티브 테스트 ID
  static String get nativeVideoAdUnitId =>
      _isAndroid ? _testNativeVideoAndroid : _testNativeVideoIos;

  static void logStatus() {
    if (!kDebugMode) return;
    debugPrint(
      '[Ads] supported=$isSupported useTest=$useTestAds '
      'banner=${bannerAdUnitId.substring(bannerAdUnitId.length - 8)} '
      'native=${nativeAdUnitId.substring(nativeAdUnitId.length - 8)}',
    );
  }
}
