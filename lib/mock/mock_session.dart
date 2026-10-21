import 'package:flutter/foundation.dart';

import 'mock_store.dart';
import 'mock_user.dart';

/// 목업 세션 — 사장/직원 테스트 계정 전환
class MockSession extends ChangeNotifier {
  MockSession._();

  static final MockSession instance = MockSession._();

  MockUser? _currentUser;

  /// 계정별 프로필 수정본 (사장↔직원 전환 후에도 유지)
  final Map<String, MockUser> _profileOverrides = {};

  MockUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// 실명 온보딩 필요 (로그인됨 + realName 미등록)
  bool get needsProfileSetup {
    final user = _currentUser;
    if (user == null) return false;
    return !user.hasRealName;
  }

  String get requireUid {
    final user = _currentUser;
    if (user == null) {
      throw StateError('목업 세션이 없습니다.');
    }
    return user.uid;
  }

  /// 사장 계정으로 로그인 (데모 매장 시드 보장)
  void loginAsOwner() => _login(MockUser.owner);

  /// 초대받은 직원 계정으로 로그인
  void loginAsStaff() => _login(MockUser.staff);

  void loginAs(MockUser user) => _login(user);

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  /// Play 정책: 계정 삭제 — 관련 목업 데이터 제거 후 로그아웃
  void deleteAccount() {
    final user = _currentUser;
    if (user == null) {
      throw StateError('목업 세션이 없습니다.');
    }
    MockStore.instance.deleteAccountData(user.uid);
    _profileOverrides.remove(user.uid);
    _currentUser = null;
    notifyListeners();
  }

  /// 표시 이름·이메일 등 프로필 수정
  void updateProfile({
    String? displayName,
    String? email,
    String? realName,
  }) {
    final user = _currentUser;
    if (user == null) {
      throw StateError('목업 세션이 없습니다.');
    }

    final nextName = displayName?.trim();
    final nextEmail = email?.trim();
    final nextReal = realName?.trim();
    final updated = user.copyWith(
      displayName: (nextName != null && nextName.isNotEmpty)
          ? nextName
          : user.displayName,
      email: (nextEmail != null && nextEmail.isNotEmpty)
          ? nextEmail
          : user.email,
      realName: (nextReal != null && nextReal.isNotEmpty)
          ? nextReal
          : user.realName,
    );

    _currentUser = updated;
    _profileOverrides[updated.uid] = updated;
    MockStore.instance.syncMemberDisplayName(
      userId: updated.uid,
      displayName: updated.preferredDisplayName,
    );
    notifyListeners();
  }

  /// 온보딩 실명 저장 후 메인으로 진입 가능 상태
  void completeRealNameSetup(String realName) {
    final trimmed = realName.trim();
    if (trimmed.length < 2) {
      throw ArgumentError('실명은 2자 이상이어야 합니다.');
    }
    updateProfile(displayName: trimmed, realName: trimmed);
  }

  void _login(MockUser user) {
    MockStore.instance.ensureDemoWorkspace();
    _currentUser = _profileOverrides[user.uid] ?? user;
    notifyListeners();
  }
}
