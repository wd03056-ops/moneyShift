import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 네트워크 일시 오류만 제한적으로 재시도 (무한 루프·DB 폭주 방지)
///
/// - 최대 [maxRetries]회 (기본 2 → 총 시도 3회)
/// - 지수 백오프 + 지터
/// - 4xx / 취소 / 타임아웃(선택)은 재시도하지 않음
class LimitedRetryInterceptor extends Interceptor {
  LimitedRetryInterceptor({
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 400),
    this.retryTimeouts = false,
  });

  final int maxRetries;
  final Duration baseDelay;
  final bool retryTimeouts;

  static const _extraKey = 'limited_retry_count';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final count = (err.requestOptions.extra[_extraKey] as int?) ?? 0;
    if (!_shouldRetry(err) || count >= maxRetries) {
      return handler.next(err);
    }

    final next = count + 1;
    err.requestOptions.extra[_extraKey] = next;
    final delay = _backoff(next);
    debugPrint(
      '[DioRetry] ${err.requestOptions.method} ${err.requestOptions.path} '
      'retry $next/$maxRetries after ${delay.inMilliseconds}ms '
      '(${err.type.name})',
    );
    await Future<void>.delayed(delay);

    try {
      final response = await Dio(
        BaseOptions(
          baseUrl: err.requestOptions.baseUrl,
          connectTimeout: err.requestOptions.connectTimeout,
          receiveTimeout: err.requestOptions.receiveTimeout,
          sendTimeout: err.requestOptions.sendTimeout,
          headers: err.requestOptions.headers,
          validateStatus: err.requestOptions.validateStatus,
        ),
      ).fetch(err.requestOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    } catch (e) {
      return handler.next(
        DioException(requestOptions: err.requestOptions, error: e),
      );
    }
  }

  bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.cancel) return false;
    if (err.type == DioExceptionType.badResponse) {
      final code = err.response?.statusCode ?? 0;
      // 5xx only
      return code >= 500;
    }
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return retryTimeouts;
    }
    return err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.unknown;
  }

  Duration _backoff(int attempt) {
    final exp = pow(2, attempt - 1).toInt();
    final jitterMs = Random().nextInt(120);
    return Duration(
      milliseconds: baseDelay.inMilliseconds * exp + jitterMs,
    );
  }
}
