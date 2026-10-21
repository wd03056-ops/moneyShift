/// 카카오 로컬(주소검색) REST API 키
///
/// 네이티브 앱 키와 **다릅니다**. 콘솔 [앱 키] > REST API 키 를 사용합니다.
///
/// 우선순위:
/// 1. `--dart-define=KAKAO_API_KEY=...`
/// 2. [fallbackRestApiKey]
abstract final class KakaoApiConfig {
  static const String kakaoApiKey = String.fromEnvironment(
    'KAKAO_API_KEY',
    defaultValue: fallbackRestApiKey,
  );

  /// 카카오디벨로퍼스 REST API 키 (주소/장소 검색용)
  static const String fallbackRestApiKey =
      'fef775404815e4adb31c151c1274f46f';

  static const String baseUrl = 'https://dapi.kakao.com';

  static bool get hasApiKey =>
      kakaoApiKey.isNotEmpty && kakaoApiKey != 'YOUR_REST_API_KEY';

  /// 카카오 로컬 API 공통 헤더
  static Map<String, String> get authHeaders {
    if (!hasApiKey) {
      throw StateError(
        'KAKAO_API_KEY(REST API 키)가 비어 있습니다. '
        '네이티브 앱 키가 아니라 콘솔의 REST API 키를 넣으세요. '
        'KakaoApiConfig.fallbackRestApiKey 또는 '
        'flutter run --dart-define=KAKAO_API_KEY=...',
      );
    }
    return {
      'Authorization': 'KakaoAK $kakaoApiKey',
      'Content-Type': 'application/json;charset=UTF-8',
    };
  }
}
