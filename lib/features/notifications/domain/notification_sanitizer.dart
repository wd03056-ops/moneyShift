/// 알림 title/body XSS·스크립트 인젝션 방지
abstract final class NotificationSanitizer {
  NotificationSanitizer._();

  static const int maxTitleLength = 120;
  static const int maxBodyLength = 500;

  /// HTML 태그·스크립트·제어문자 제거 후 길이 제한
  static String sanitize(String input, {int maxLength = maxBodyLength}) {
    var text = input;
    // null byte / 제어문자
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    // HTML / script 태그
    text = text.replaceAll(
      RegExp(r'<script[\s\S]*?>[\s\S]*?</script>', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    // javascript: / data: URL 스킴
    text = text.replaceAll(
      RegExp(r'(javascript|data|vbscript)\s*:', caseSensitive: false),
      '',
    );
    // 이벤트 핸들러 속성 잔여
    text = text.replaceAll(
      RegExp(r'\bon\w+\s*=', caseSensitive: false),
      '',
    );
    text = text.replaceAll('&lt;', '<').replaceAll('&gt;', '>');
    // 다시 태그 제거 (디코드 후)
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.trim();
    if (text.length > maxLength) {
      text = '${text.substring(0, maxLength - 1)}…';
    }
    return text;
  }

  static String sanitizeTitle(String input) =>
      sanitize(input, maxLength: maxTitleLength);

  static String sanitizeBody(String input) =>
      sanitize(input, maxLength: maxBodyLength);
}
