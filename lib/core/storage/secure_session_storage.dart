import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 로그인 세션·소셜 토큰 등 민감 정보 (Keychain / EncryptedSharedPreferences)
class SecureSessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  static final SecureSessionStorage instance = SecureSessionStorage();

  static const _keyAccessToken = 'session_access_token';
  static const _keyRefreshToken = 'session_refresh_token';
  static const _keyUserId = 'session_user_id';
  static const _keyAuthProvider = 'session_auth_provider';
  static const _keyFirebaseUid = 'session_firebase_uid';

  final FlutterSecureStorage _storage;

  Future<void> saveSession({
    required String userId,
    required String authProvider,
    String? accessToken,
    String? refreshToken,
    String? firebaseUid,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _keyUserId, value: userId),
        _storage.write(key: _keyAuthProvider, value: authProvider),
        if (accessToken != null)
          _storage.write(key: _keyAccessToken, value: accessToken),
        if (refreshToken != null)
          _storage.write(key: _keyRefreshToken, value: refreshToken),
        if (firebaseUid != null)
          _storage.write(key: _keyFirebaseUid, value: firebaseUid),
      ]);
    } catch (e, st) {
      debugPrint('[SecureSession] save FAIL: $e');
      debugPrint('$st');
    }
  }

  Future<String?> readAccessToken() => _storage.read(key: _keyAccessToken);

  Future<String?> readUserId() => _storage.read(key: _keyUserId);

  Future<String?> readAuthProvider() => _storage.read(key: _keyAuthProvider);

  /// 토큰·세션 키 전부 삭제
  Future<void> clear() async {
    try {
      await _storage.deleteAll();
      debugPrint('[SecureSession] cleared');
    } catch (e, st) {
      debugPrint('[SecureSession] clear FAIL: $e');
      debugPrint('$st');
      // 키별 재시도
      for (final key in [
        _keyAccessToken,
        _keyRefreshToken,
        _keyUserId,
        _keyAuthProvider,
        _keyFirebaseUid,
      ]) {
        try {
          await _storage.delete(key: key);
        } catch (_) {}
      }
    }
  }
}
