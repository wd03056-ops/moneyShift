import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 대시보드 인건비/급여 카드 간략·상세 보기 상태 (SharedPreferences)
class DashboardPayViewStore extends ChangeNotifier {
  DashboardPayViewStore._();

  static final DashboardPayViewStore instance = DashboardPayViewStore._();

  static const _ownerPrefix = 'dash_pay_compact_owner_';
  static const _staffPrefix = 'dash_pay_compact_staff_';

  final Map<String, bool> _ownerCompact = {};
  final Map<String, bool> _staffCompact = {};
  var _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith(_ownerPrefix)) {
          final roomId = key.substring(_ownerPrefix.length);
          if (roomId.isEmpty) continue;
          _ownerCompact[roomId] = prefs.getBool(key) ?? false;
        } else if (key.startsWith(_staffPrefix)) {
          final roomId = key.substring(_staffPrefix.length);
          if (roomId.isEmpty) continue;
          _staffCompact[roomId] = prefs.getBool(key) ?? false;
        }
      }
    } catch (e, st) {
      debugPrint('[DashPayView] load FAIL: $e\n$st');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// true = 간략히 보기 (컴팩트). 미설정 시 기본값: 간략히 보기
  bool isOwnerCompact(String roomId) => _ownerCompact[roomId] ?? true;

  bool isStaffCompact(String roomId) => _staffCompact[roomId] ?? true;

  Future<void> setOwnerCompact(String roomId, bool compact) async {
    if (roomId.isEmpty) return;
    await ensureLoaded();
    final prev = isOwnerCompact(roomId);
    _ownerCompact[roomId] = compact;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_ownerPrefix$roomId', compact);
    } catch (e) {
      debugPrint('[DashPayView] save owner FAIL: $e');
      _ownerCompact[roomId] = prev;
      notifyListeners();
    }
  }

  Future<void> setStaffCompact(String roomId, bool compact) async {
    if (roomId.isEmpty) return;
    await ensureLoaded();
    final prev = isStaffCompact(roomId);
    _staffCompact[roomId] = compact;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_staffPrefix$roomId', compact);
    } catch (e) {
      debugPrint('[DashPayView] save staff FAIL: $e');
      _staffCompact[roomId] = prev;
      notifyListeners();
    }
  }

  void clearMemoryCache() {
    _ownerCompact.clear();
    _staffCompact.clear();
    _loaded = false;
  }
}
