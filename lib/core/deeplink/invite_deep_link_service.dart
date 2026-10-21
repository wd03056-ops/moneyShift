import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'invite_link.dart';

/// 초대 딥링크 수신 + 미로그인 시 코드 보류
class InviteDeepLinkService {
  InviteDeepLinkService._();

  static final InviteDeepLinkService instance = InviteDeepLinkService._();

  static const _pendingKey = 'pending_invite_code_v1';

  final _appLinks = AppLinks();
  final _incoming = StreamController<String>.broadcast();

  StreamSubscription<Uri>? _sub;
  bool _started = false;

  /// 앱이 처리해야 할 초대 코드 스트림
  Stream<String> get inviteCodes => _incoming.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final initial = await _appLinks.getInitialLink();
      final fromInitial = InviteLink.parseCode(initial);
      if (fromInitial != null) {
        await _emit(fromInitial);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[InviteDeepLink] initial: $e');
    }

    _sub = _appLinks.uriLinkStream.listen(
      (uri) async {
        final code = InviteLink.parseCode(uri);
        if (code != null) await _emit(code);
      },
      onError: (Object e) {
        if (kDebugMode) debugPrint('[InviteDeepLink] stream: $e');
      },
    );
  }

  Future<void> _emit(String code) async {
    await savePendingCode(code);
    if (!_incoming.isClosed) _incoming.add(code);
  }

  Future<void> savePendingCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, InviteLink.normalizeCode(code));
  }

  Future<String?> takePendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_pendingKey);
    if (code == null || code.isEmpty) return null;
    await prefs.remove(_pendingKey);
    return InviteLink.normalizeCode(code);
  }

  Future<String?> peekPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_pendingKey);
    if (code == null || code.isEmpty) return null;
    return InviteLink.normalizeCode(code);
  }

  Future<void> clearPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
