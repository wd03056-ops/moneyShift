import 'package:flutter/foundation.dart';

/// Vercel Express API 기본 주소 설정
///
/// ## 환경 전환
/// - 기본: 디버그 → [localBaseUrl], 릴리즈 → [productionBaseUrl]
/// - 강제: `--dart-define=API_BASE_URL=https://...`
/// - 로컬 강제: `--dart-define=USE_LOCAL_API=true`
///
/// 예)
/// ```bash
/// flutter run --dart-define=USE_LOCAL_API=true
/// flutter run --dart-define=API_BASE_URL=https://moneyshift.vercel.app
/// ```
abstract final class ApiConfig {
  ApiConfig._();

  /// 배포된 Vercel 서버
  static const String productionBaseUrl = 'https://moneyshift.vercel.app';

  /// 로컬 Express (`npm run dev` → api/local.js)
  static const String localBaseUrl = 'http://127.0.0.1:3000';

  /// CLI로 주입한 절대 URL (있으면 최우선)
  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// `true`면 디버그에서 로컬 API 사용
  static const bool _useLocalApi = bool.fromEnvironment(
    'USE_LOCAL_API',
    defaultValue: false,
  );

  /// Dio / 앱 전역에서 쓰는 API 루트 (끝 슬래시 없음)
  static String get baseUrl {
    final override = _overrideBaseUrl.trim();
    if (override.isNotEmpty) {
      return _stripTrailingSlash(override);
    }
    if (_useLocalApi || (kDebugMode && _preferLocalInDebug)) {
      return localBaseUrl;
    }
    return productionBaseUrl;
  }

  /// 디버그에서 기본을 로컬로 둘지 여부.
  /// 기본 `false` — 배포 API를 바로 쓰게 하고, 로컬은 USE_LOCAL_API로 켠다.
  static const bool _preferLocalInDebug = false;

  static bool get isProduction => baseUrl == productionBaseUrl;

  static bool get isLocal => baseUrl == localBaseUrl;

  static String _stripTrailingSlash(String url) {
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  static void logStatus() {
    if (!kDebugMode) return;
    debugPrint(
      '[ApiConfig] baseUrl=$baseUrl '
      '(local=$isLocal production=$isProduction)',
    );
  }
}
