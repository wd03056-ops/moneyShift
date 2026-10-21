import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../mock/mock_session.dart';
import '../../../models/notification_item.dart';
import '../data/notification_inbox_service.dart';

/// 알림함 리스트·편집/선택 상태
///
/// [uid] 가 세션 전환으로 바뀌면 [bindUser] 로 다시 구독합니다.
class NotificationInboxController extends ChangeNotifier {
  NotificationInboxController({
    required String uid,
    NotificationInboxService? service,
  })  : _uid = uid,
        _service = service ?? NotificationInboxService();

  /// 현재 구독 중인 수신자 UID (계정 전환 시 [bindUser]로 갱신)
  String _uid;
  final NotificationInboxService _service;

  StreamSubscription<List<NotificationItem>>? _sub;
  VoidCallback? _sessionListener;

  List<NotificationItem> _items = const [];
  final Set<String> _selectedIds = {};
  bool _editing = false;
  bool _loading = true;
  bool _busy = false;
  bool _refreshing = false;
  String? _fatalError;

  String get uid => _uid;
  List<NotificationItem> get items => _items;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  bool get editing => _editing;
  bool get loading => _loading;
  bool get busy => _busy;
  bool get refreshing => _refreshing;
  String? get fatalError => _fatalError;

  int get selectedCount => _selectedIds.length;
  int get unreadCount => _items.where((e) => !e.isRead).length;
  bool get hasSelection => _selectedIds.isNotEmpty;
  bool get isAllSelected =>
      _items.isNotEmpty && _selectedIds.length == _items.length;
  bool get isEmpty => !_loading && _items.isEmpty;

  void start() {
    _attachSessionWatcher();
    _subscribe(_uid);
  }

  /// 계정 전환 시 현재 로그인 UID로 재바인딩
  void bindUser(String newUid) {
    if (newUid.isEmpty || newUid == _uid) return;
    _uid = newUid;
    _selectedIds.clear();
    _editing = false;
    _subscribe(newUid);
  }

  void _attachSessionWatcher() {
    _sessionListener?.call();
    void onSession() {
      final current = MockSession.instance.currentUser?.uid;
      if (current != null && current != _uid) {
        bindUser(current);
      }
    }

    MockSession.instance.addListener(onSession);
    _sessionListener = () {
      MockSession.instance.removeListener(onSession);
    };
  }

  void _subscribe(String userId) {
    _loading = true;
    _fatalError = null;
    notifyListeners();

    _sub?.cancel();
    _sub = _service.watchInbox(userId).listen(
      _onSnapshot,
      onError: (Object e, StackTrace st) {
        debugPrint('[InboxController] stream error: $e');
        debugPrint('$st');
        unawaited(_fallbackFetch(fromStreamError: true));
      },
    );
  }

  void _onSnapshot(List<NotificationItem> list) {
    _items = list;
    _selectedIds.removeWhere((id) => !_items.any((e) => e.id == id));
    if (_items.isEmpty) {
      _editing = false;
      _selectedIds.clear();
    }
    _loading = false;
    _fatalError = null;
    notifyListeners();
  }

  Future<void> _fallbackFetch({bool fromStreamError = false}) async {
    try {
      _items = await _service.fetchInbox(_uid);
      _selectedIds.removeWhere((id) => !_items.any((e) => e.id == id));
      _fatalError = null;
    } catch (e, st) {
      debugPrint('[InboxController] fetch FAIL: $e');
      debugPrint('$st');
      _items = const [];
      _selectedIds.clear();
      _editing = false;
      _fatalError = null;
    } finally {
      _loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    notifyListeners();
    // 세션 UID 동기화 후 fetch
    final current = MockSession.instance.currentUser?.uid;
    if (current != null && current != _uid) {
      _uid = current;
    }
    await _fallbackFetch();
  }

  void enterEditMode({String? selectId}) {
    _editing = true;
    if (selectId != null) {
      _selectedIds
        ..clear()
        ..add(selectId);
    }
    notifyListeners();
  }

  void exitEditMode() {
    _editing = false;
    _selectedIds.clear();
    notifyListeners();
  }

  void toggleEditMode() {
    if (_editing) {
      exitEditMode();
    } else {
      enterEditMode();
    }
  }

  void toggleSelect(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  void selectAll() {
    _selectedIds
      ..clear()
      ..addAll(_items.map((e) => e.id));
    notifyListeners();
  }

  void toggleSelectAll() {
    if (isAllSelected) {
      clearSelection();
    } else {
      selectAll();
    }
  }

  Future<void> markReadAction() async {
    if (_editing && hasSelection) {
      await markSelectedRead();
    } else {
      await markAllRead();
    }
  }

  Future<void> markSelectedRead() async {
    final targets = _selectedIds.toList();
    if (targets.isEmpty) return;

    _busy = true;
    notifyListeners();
    try {
      _items = [
        for (final item in _items)
          targets.contains(item.id) ? item.copyWith(isRead: true) : item,
      ];
      notifyListeners();
      await _service.markRead(
        recipientUid: _uid,
        ids: targets,
        isRead: true,
      );
      _selectedIds.clear();
    } catch (e, st) {
      debugPrint('[InboxController] markRead FAIL: $e');
      debugPrint('$st');
      await refresh();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    final unread = _items.where((e) => !e.isRead).map((e) => e.id).toList();
    if (unread.isEmpty) return;

    _busy = true;
    notifyListeners();
    try {
      _items = [for (final item in _items) item.copyWith(isRead: true)];
      notifyListeners();
      await _service.markRead(
        recipientUid: _uid,
        ids: unread,
        isRead: true,
      );
      _selectedIds.clear();
    } catch (e, st) {
      debugPrint('[InboxController] markAllRead FAIL: $e');
      debugPrint('$st');
      await refresh();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteAction() async {
    if (_editing && hasSelection) {
      await deleteSelected();
    } else {
      await deleteSelected(deleteAllIfEmpty: true);
    }
  }

  Future<void> deleteSelected({bool deleteAllIfEmpty = false}) async {
    final targets = _selectedIds.isNotEmpty
        ? _selectedIds.toList()
        : (deleteAllIfEmpty ? _items.map((e) => e.id).toList() : <String>[]);
    if (targets.isEmpty) return;

    _busy = true;
    notifyListeners();
    try {
      final remove = targets.toSet();
      _items = _items.where((e) => !remove.contains(e.id)).toList();
      _selectedIds.clear();
      if (_items.isEmpty) _editing = false;
      notifyListeners();
      await _service.deleteMany(recipientUid: _uid, ids: targets);
    } catch (e, st) {
      debugPrint('[InboxController] delete FAIL: $e');
      debugPrint('$st');
      await refresh();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteOne(String id) async {
    _busy = true;
    notifyListeners();
    try {
      _items = _items.where((e) => e.id != id).toList();
      _selectedIds.remove(id);
      if (_items.isEmpty) _editing = false;
      notifyListeners();
      await _service.deleteMany(recipientUid: _uid, ids: [id]);
    } catch (e, st) {
      debugPrint('[InboxController] deleteOne FAIL: $e');
      debugPrint('$st');
      await refresh();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> markOneRead(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    if (_items[idx].isRead) return;

    // 저장소 먼저 반영 — 알림 탭으로 inbox가 pop 되어도 읽음 유지
    try {
      await _service.markRead(
        recipientUid: _uid,
        ids: [id],
        isRead: true,
      );
      if (!_items.any((e) => e.id == id)) return;
      _items = [
        for (final e in _items) e.id == id ? e.copyWith(isRead: true) : e,
      ];
      notifyListeners();
    } catch (e, st) {
      debugPrint('[InboxController] markOneRead FAIL: $e');
      debugPrint('$st');
      await refresh();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sessionListener?.call();
    _sessionListener = null;
    super.dispose();
  }
}
