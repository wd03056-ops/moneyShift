import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/monthly_labor_cost.dart';
import '../config/api_config.dart';
import '../network/limited_retry_interceptor.dart';

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
            ) {
    if (dio == null) {
      _dio.interceptors.add(
        LimitedRetryInterceptor(
          maxRetries: 2,
          baseDelay: const Duration(milliseconds: 400),
        ),
      );
    }
  }

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
  ///
  /// 5xx 도 예외로 던지지 않고 [ApiHealthResult]로 반환한다.
  Future<ApiHealthResult> checkServerHealth() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/health',
        options: Options(
          validateStatus: (_) => true,
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      final raw = res.data;
      final data = raw is Map<String, dynamic>
          ? raw
          : const <String, dynamic>{};
      final ok = res.statusCode == 200 && data['ok'] == true;
      if (!ok) {
        debugPrint(
          '[ApiService] health FAIL status=${res.statusCode} body=$data',
        );
      }
      return ApiHealthResult(
        ok: ok,
        statusCode: res.statusCode,
        body: data,
        message: ok
            ? '서버 정상 (${data['service'] ?? 'api'})'
            : '서버 응답 이상 status=${res.statusCode}',
      );
    } on DioException catch (e) {
      debugPrint('[ApiService] health FAIL: ${e.type.name} ${e.message}');
      return ApiHealthResult(
        ok: false,
        statusCode: e.response?.statusCode,
        message: '연결 실패 (${e.type.name})',
      );
    } catch (e) {
      debugPrint('[ApiService] health FAIL: $e');
      return ApiHealthResult(ok: false, message: '연결 실패');
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

  /// `POST /api/auth/kakao` — 카카오 토큰 → Firebase Custom Token
  Future<KakaoFirebaseAuthResult> exchangeKakaoForFirebaseToken({
    required String kakaoAccessToken,
    String? kakaoUserId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/kakao',
        data: {
          'kakaoAccessToken': kakaoAccessToken,
          if (kakaoUserId != null && kakaoUserId.isNotEmpty)
            'kakaoUserId': kakaoUserId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $kakaoAccessToken',
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (_) => true,
        ),
      );
      final data = res.data ?? const <String, dynamic>{};
      final token = data['customToken']?.toString();
      final ok = res.statusCode == 200 &&
          data['ok'] == true &&
          token != null &&
          token.isNotEmpty;
      if (!ok) {
        debugPrint(
          '[ApiService] auth/kakao FAIL status=${res.statusCode} body=$data',
        );
      }
      final code = data['error']?.toString() ??
          (ok ? null : 'http_${res.statusCode}');
      return KakaoFirebaseAuthResult(
        ok: ok,
        statusCode: res.statusCode,
        customToken: ok ? token : null,
        uid: data['uid']?.toString(),
        errorCode: code,
        message: _authKakaoUserMessage(
          ok: ok,
          statusCode: res.statusCode,
          serverMessage: data['message']?.toString(),
          errorCode: code,
        ),
      );
    } on DioException catch (e) {
      debugPrint('[ApiService] auth/kakao FAIL: ${e.type} ${e.message}');
      final network = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError;
      return KakaoFirebaseAuthResult(
        ok: false,
        statusCode: e.response?.statusCode,
        errorCode: network ? 'network' : 'dio_${e.type.name}',
        network: network,
        message: network
            ? '서버에 연결하지 못했습니다. 네트워크를 확인해 주세요.'
            : (e.message ?? '토큰 교환 요청에 실패했습니다.'),
      );
    } catch (e) {
      debugPrint('[ApiService] auth/kakao FAIL: $e');
      return KakaoFirebaseAuthResult(
        ok: false,
        errorCode: 'unknown',
        message: '토큰 교환 중 오류가 발생했습니다.',
      );
    }
  }

  static String _authKakaoUserMessage({
    required bool ok,
    int? statusCode,
    String? serverMessage,
    String? errorCode,
  }) {
    if (ok) return 'OK';
    if (serverMessage != null && serverMessage.trim().isNotEmpty) {
      return serverMessage.trim();
    }
    if (statusCode == 401) {
      return '카카오 토큰이 만료되었거나 유효하지 않습니다. 다시 로그인해 주세요.';
    }
    if (statusCode == 403) {
      return '카카오 계정 정보가 일치하지 않습니다.';
    }
    if (statusCode == 429) {
      return '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';
    }
    if (statusCode == 503 || errorCode == 'firebase_admin_not_configured') {
      return '서버 인증 설정이 완료되지 않았습니다. 잠시 후 다시 시도해 주세요.';
    }
    if (statusCode != null && statusCode >= 500) {
      return '서버 오류로 로그인을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
    return '로그인 토큰 교환에 실패했습니다. (status=$statusCode)';
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

  /// `GET /api/labor-cost/monthly`
  Future<MonthlyLaborCost?> fetchMonthlyLaborCost({
    required String roomId,
    required int year,
    required int month,
    bool includeWeeklyHoliday = false,
    bool includeEmployerSocialInsurance = false,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/labor-cost/monthly',
        queryParameters: {
          'roomId': roomId,
          'year': year,
          'month': month,
          'includeWeeklyHoliday': includeWeeklyHoliday,
          'includeEmployerSocialInsurance': includeEmployerSocialInsurance,
        },
        options: Options(validateStatus: (_) => true),
      );
      final data = res.data;
      if (res.statusCode != 200 || data is! Map<String, dynamic>) {
        debugPrint(
          '[ApiService] laborCost FAIL status=${res.statusCode} body=$data',
        );
        return null;
      }
      if (data['ok'] != true) {
        debugPrint('[ApiService] laborCost FAIL: ${data['error']}');
        return null;
      }
      return MonthlyLaborCost.fromJson(data);
    } on DioException catch (e) {
      debugPrint('[ApiService] laborCost FAIL: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[ApiService] laborCost FAIL: $e');
      return null;
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

class KakaoFirebaseAuthResult {
  const KakaoFirebaseAuthResult({
    required this.ok,
    this.statusCode,
    this.customToken,
    this.uid,
    this.errorCode,
    this.message = '',
    this.network = false,
  });

  final bool ok;
  final int? statusCode;
  final String? customToken;
  final String? uid;
  final String? errorCode;
  final String message;
  final bool network;
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
