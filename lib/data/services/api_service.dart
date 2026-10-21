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
