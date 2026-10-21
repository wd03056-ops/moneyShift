import '../constants/app_constants.dart';

/// 직원 초대 링크 생성·파싱 (HTTPS 앱링크 + 커스텀 스킴)
abstract final class InviteLink {
  InviteLink._();

  /// 공유용 HTTPS 링크 — 메신저/브라우저에서 열림
  static String buildHttps(String code) {
    final normalized = normalizeCode(code);
    return '${AppConstants.inviteWebBaseUrl}?code=$normalized';
  }

  /// 하위 호환 커스텀 스킴
  static String buildCustomScheme(String code) {
    final normalized = normalizeCode(code);
    return '${AppConstants.appCustomScheme}://join?code=$normalized';
  }

  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  /// URI에서 초대 코드 추출. 해당 없으면 null.
  static String? parseCode(Uri? uri) {
    if (uri == null) return null;

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    final isHttpsInvite = (scheme == 'https' || scheme == 'http') &&
        (host == AppConstants.appLinkHost || host == 'www.${AppConstants.appLinkHost}') &&
        (path == '/join' || path.startsWith('/join/'));

    final isCustomInvite = scheme == AppConstants.appCustomScheme &&
        (host == 'join' || path == '/join' || path.startsWith('/join'));

    if (!isHttpsInvite && !isCustomInvite) return null;

    final fromQuery = uri.queryParameters['code'];
    if (fromQuery != null && fromQuery.trim().isNotEmpty) {
      return normalizeCode(fromQuery);
    }

    // /join/TVQ63FWB
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 && segments.first.toLowerCase() == 'join') {
      return normalizeCode(segments[1]);
    }

    return null;
  }

  static String? parseCodeFromString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return parseCode(Uri.parse(raw.trim()));
    } catch (_) {
      return null;
    }
  }
}
