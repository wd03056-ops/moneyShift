import 'dart:async';

import 'package:flutter/foundation.dart';

/// 버튼 연타·중복 비동기 요청 차단
///
/// ```dart
/// final _guard = AsyncActionGuard();
///
/// onPressed: () => _guard.run(() async { ... }),
/// // 또는
/// if (!_guard.tryLock()) return;
/// try { ... } finally { _guard.unlock(); }
/// ```
class AsyncActionGuard {
  AsyncActionGuard({this.cooldown = const Duration(milliseconds: 400)});

  /// 연속 호출 최소 간격 (락 해제 후에도 짧게 쿨다운)
  final Duration cooldown;

  bool _locked = false;
  DateTime? _lastFinishedAt;

  bool get isBusy => _locked;

  /// 잠금 가능하면 true. 이미 실행 중이면 false.
  bool tryLock() {
    if (_locked) return false;
    final last = _lastFinishedAt;
    if (last != null && DateTime.now().difference(last) < cooldown) {
      return false;
    }
    _locked = true;
    return true;
  }

  void unlock() {
    _locked = false;
    _lastFinishedAt = DateTime.now();
  }

  /// [action] 실행. 이미 busy면 즉시 null 반환.
  Future<T?> run<T>(Future<T> Function() action) async {
    if (!tryLock()) {
      debugPrint('[AsyncActionGuard] skip — busy');
      return null;
    }
    try {
      return await action();
    } finally {
      unlock();
    }
  }
}
