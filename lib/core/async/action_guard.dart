import 'dart:async';

/// CUD 버튼·API Write 연타 방지 (in-flight + cooldown debounce)
///
/// ```dart
/// final guard = ActionGuard(cooldown: Duration(milliseconds: 800));
/// if (!guard.tryStart()) return;
/// try { await save(); } finally { guard.end(); }
/// ```
class ActionGuard {
  ActionGuard({
    this.cooldown = const Duration(milliseconds: 800),
  });

  /// 성공/실패 후 동일 액션 재진입까지 최소 대기
  final Duration cooldown;

  var _inFlight = false;
  DateTime? _lastEndedAt;

  bool get isBusy => _inFlight;

  /// 진행 중이거나 cooldown 안이면 false
  bool tryStart() {
    if (_inFlight) return false;
    final last = _lastEndedAt;
    if (last != null && DateTime.now().difference(last) < cooldown) {
      return false;
    }
    _inFlight = true;
    return true;
  }

  void end() {
    _inFlight = false;
    _lastEndedAt = DateTime.now();
  }

  /// [action] 실행. 진입 실패 시 null 반환.
  Future<T?> run<T>(Future<T> Function() action) async {
    if (!tryStart()) return null;
    try {
      return await action();
    } finally {
      end();
    }
  }
}

/// 연속 호출을 [delay] 뒤로 모아 1회만 실행 (조회 API 디바운스)
class DebouncedAction {
  DebouncedAction({this.delay = const Duration(milliseconds: 600)});

  final Duration delay;
  Timer? _timer;
  int _generation = 0;

  void run(void Function() action) {
    _timer?.cancel();
    final gen = ++_generation;
    _timer = Timer(delay, () {
      if (gen != _generation) return;
      action();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _generation++;
  }

  void dispose() => cancel();
}
