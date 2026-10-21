import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';

/// Vercel Express API 클라이언트 (dio)
///
/// ## Repository 연동 예시
/// ```dart
/// class ScheduleRepository {
///   ScheduleRepository({ApiService? api})
///       : _api = api ?? ApiService.instance;
///
///   final ApiService _api;
///
///   Future<void> ping() => _api.get('/api/schedules/ping');
/// }
/// ```
class ApiService {
  ApiService({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
                validateStatus: (code) => code != null && code < 500,
              ),
            );

  static final ApiService instance = ApiService();

  final Dio _dio;

  Dio get dio => _dio;

  String get baseUrl => _dio.options.baseUrl;

  /// 런타임에 baseUrl 교체 (테스트·환경 전환)
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url.endsWith('/')
        ? url.substring(0, url.length - 1)
        : url;
  }

  /// `GET /api/health` — 서버 생존 확인
  Future<ApiHealthResult> checkServerHealth() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/health');
      final data = res.data ?? const <String, dynamic>{};
      final ok = res.statusCode == 200 && data['ok'] == true;
      return ApiHealthResult(
        ok: ok,
        statusCode: res.statusCode,
        body: data,
        message: ok
            ? '서버 정상 (${data['service'] ?? 'api'})'
            : '응답 이상 status=${res.statusCode}',
      );
    } on DioException catch (e) {
      debugPrint('[ApiService] health FAIL: ${e.message}');
      return ApiHealthResult(
        ok: false,
        statusCode: e.response?.statusCode,
        message: e.message ?? '연결 실패',
      );
    } catch (e) {
      debugPrint('[ApiService] health FAIL: $e');
      return ApiHealthResult(ok: false, message: '$e');
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Options? options,
  }) {
    return _dio.put<T>(path, data: data, options: options);
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Options? options,
  }) {
    return _dio.delete<T>(path, data: data, options: options);
  }

  /// `DELETE /api/account` — 서버 DB 익명화·언링크
  Future<AccountDeletionApiResult> deleteAccount({
    required String userId,
    String authProvider = 'kakao',
    String? kakaoAccessToken,
  }) async {
    final payload = <String, dynamic>{
      'userId': userId,
      'authProvider': authProvider,
      'confirm': true,
      if (kakaoAccessToken != null && kakaoAccessToken.isNotEmpty)
        'kakaoAccessToken': kakaoAccessToken,
    };
    try {
      final res = await _dio.delete<Map<String, dynamic>>(
        '/api/account',
        data: payload,
        options: Options(
          headers: {
            'X-User-Id': userId,
            'X-Auth-Provider': authProvider,
            if (kakaoAccessToken != null && kakaoAccessToken.isNotEmpty)
              'Authorization': 'Bearer $kakaoAccessToken',
          },
        ),
      );
      final data = res.data ?? const <String, dynamic>{};
      // stub 모드는 더 이상 성공으로 치지 않음 — firestore 실연동만 OK
      final mode = data['mode']?.toString();
      final ok = (res.statusCode == 200) &&
          data['ok'] == true &&
          (mode == null || mode == 'firestore');
      if (!ok && (res.statusCode == 404 || res.statusCode == 405)) {
        // 일부 환경에서 DELETE 미지원 → POST fallback
        return _deleteAccountPost(payload, userId, authProvider, kakaoAccessToken);
      }
      return AccountDeletionApiResult(
        ok: ok,
        statusCode: res.statusCode,
        mode: mode,
        message: data['message']?.toString() ??
            (ok
                ? 'OK'
                : (data['error']?.toString() ?? 'status=${res.statusCode}')),
        body: data,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        return _deleteAccountPost(payload, userId, authProvider, kakaoAccessToken);
      }
      debugPrint('[ApiService] deleteAccount FAIL: ${e.message}');
      final body = e.response?.data;
      var msg = e.message ?? '연결 실패';
      if (body is Map && body['message'] != null) {
        msg = body['message'].toString();
      }
      return AccountDeletionApiResult(
        ok: false,
        statusCode: e.response?.statusCode,
        mode: body is Map ? body['mode']?.toString() : null,
        message: msg,
        body: body is Map<String, dynamic>
            ? body
            : const <String, dynamic>{},
      );
    } catch (e) {
      debugPrint('[ApiService] deleteAccount FAIL: $e');
      return AccountDeletionApiResult(ok: false, message: '$e');
    }
  }

  Future<AccountDeletionApiResult> _deleteAccountPost(
    Map<String, dynamic> payload,
    String userId,
    String authProvider,
    String? kakaoAccessToken,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/account/delete',
        data: payload,
        options: Options(
          headers: {
            'X-User-Id': userId,
            'X-Auth-Provider': authProvider,
            if (kakaoAccessToken != null && kakaoAccessToken.isNotEmpty)
              'Authorization': 'Bearer $kakaoAccessToken',
          },
        ),
      );
      final data = res.data ?? const <String, dynamic>{};
      final mode = data['mode']?.toString();
      final ok = (res.statusCode == 200) &&
          data['ok'] == true &&
          (mode == null || mode == 'firestore');
      return AccountDeletionApiResult(
        ok: ok,
        statusCode: res.statusCode,
        mode: mode,
        message: data['message']?.toString() ??
            (ok
                ? 'OK'
                : (data['error']?.toString() ?? 'status=${res.statusCode}')),
        body: data,
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      String msg = e.message ?? '연결 실패';
      if (body is Map && body['message'] != null) {
        msg = body['message'].toString();
      }
      return AccountDeletionApiResult(
        ok: false,
        statusCode: e.response?.statusCode,
        message: msg,
      );
    }
  }
}

class AccountDeletionApiResult {
  const AccountDeletionApiResult({
    required this.ok,
    this.statusCode,
    this.mode,
    this.message = '',
    this.body = const {},
  });

  final bool ok;
  final int? statusCode;
  final String? mode;
  final String message;
  final Map<String, dynamic> body;
}

class ApiHealthResult {
  const ApiHealthResult({
    required this.ok,
    this.statusCode,
    this.body = const {},
    this.message = '',
  });

  final bool ok;
  final int? statusCode;
  final Map<String, dynamic> body;
  final String message;
}
