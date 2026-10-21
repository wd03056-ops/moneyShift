import 'package:flutter/foundation.dart';

/// 릴리즈에서는 민감 로그를 남기지 않음 (Play 보안·개인정보)
abstract final class SecureLog {
  SecureLog._();

  static void d(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// 토큰·키 등 — 디버그에서만 앞부분 미리보기
  static String redactToken(String? token, {int keep = 8}) {
    if (token == null || token.isEmpty) return '(empty)';
    if (!kDebugMode) return '(redacted)';
    if (token.length <= keep) return '…';
    return '${token.substring(0, keep)}…';
  }
}
