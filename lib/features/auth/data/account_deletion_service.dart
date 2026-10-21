import 'package:flutter/foundation.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/storage/local_data_cleaner.dart';
import '../../../core/storage/secure_session_storage.dart';
import '../../../core/utils/async_action_guard.dart';
import '../../../data/services/api_service.dart';
import '../../../mock/mock_session.dart';
import '../../../services/fcm_service.dart';
import '../presentation/auth_home_gate.dart';
import 'social_auth_unlink_service.dart';

/// Play 정책 — 계정 삭제(탈퇴) 오케스트레이션
///
/// **순서 (API 성공 후에만 로컬·소셜 정리)**
/// 1) Vercel `DELETE /api/account` → Firestore 익명화 성공 확인
/// 2) 소셜 Unlink (카카오/구글) + Firebase 세션 종료
/// 3) SecureStorage / SharedPreferences 전량 clear
/// 4) 목업 세션 정리 + 로그인 게이트로 스택 리셋
class AccountDeletionService {
  AccountDeletionService({
    ApiService? api,
    SocialAuthUnlinkService? socialUnlink,
    SecureSessionStorage? secureStorage,
  })  : _api = api ?? ApiService.instance,
        _social = socialUnlink ?? SocialAuthUnlinkService.instance,
        _secure = secureStorage ?? SecureSessionStorage.instance;

  static final AccountDeletionService instance = AccountDeletionService();

  final ApiService _api;
  final SocialAuthUnlinkService _social;
  final SecureSessionStorage _secure;
  final _deleteGuard = AsyncActionGuard(
    cooldown: const Duration(seconds: 2),
  );
  final _logoutGuard = AsyncActionGuard();

  /// 현재 세션 계정 탈퇴. API 실패 시 Unlink/로컬 삭제를 하지 않는다.
  Future<AccountDeletionResult> deleteCurrentAccount() async {
    if (!_deleteGuard.tryLock()) {
      return const AccountDeletionResult(
        ok: false,
        message: '계정 삭제가 이미 진행 중입니다.',
      );
    }
    try {
      return await _deleteCurrentAccountBody();
    } finally {
      _deleteGuard.unlock();
    }
  }

  Future<AccountDeletionResult> _deleteCurrentAccountBody() async {
    final user = MockSession.instance.currentUser;
    if (user == null) {
      return const AccountDeletionResult(
        ok: false,
        message: '로그인 정보가 없습니다.',
      );
    }

    final uid = user.uid;
    final storedProvider = await _secure.readAuthProvider();
    final authProvider = (storedProvider != null && storedProvider.isNotEmpty)
        ? storedProvider
        : (user.personaLabel == '카카오' ? 'kakao' : 'mock');
    final accessToken = await _secure.readAccessToken();

    // 1) 서버 Firestore 익명화 — 성공 필수
    late final AccountDeletionApiResult apiResult;
    try {
      apiResult = await _api.deleteAccount(
        userId: uid,
        authProvider: authProvider,
        kakaoAccessToken: accessToken,
      );
      debugPrint(
        '[AccountDeletion] API ok=${apiResult.ok} mode=${apiResult.mode} '
        'status=${apiResult.statusCode} msg=${apiResult.message}',
      );
    } catch (e, st) {
      debugPrint('[AccountDeletion] API FAIL: $e');
      debugPrint('$st');
      return AccountDeletionResult(
        ok: false,
        message: '서버 연결에 실패했습니다. 잠시 후 다시 시도해 주세요.\n($e)',
      );
    }

    final firestoreOk =
        apiResult.ok && (apiResult.mode == null || apiResult.mode == 'firestore');
    if (!firestoreOk) {
      return AccountDeletionResult(
        ok: false,
        message: apiResult.message.isNotEmpty
            ? apiResult.message
            : '서버에서 계정 삭제에 실패했습니다. (status=${apiResult.statusCode})',
        apiMode: apiResult.mode,
      );
    }

    // 2) 소셜 Unlink + Firebase (API 성공 후)
    try {
      await FcmService.instance.unbind();
    } catch (_) {}
    await _social.unlinkAll(authProvider: authProvider);

    // 3) 로컬 완전 초기화
    await LocalDataCleaner.clearAllForAccountDeletion(userId: uid);

    // 4) 목업 세션·표시명 '(탈퇴한 회원)'
    try {
      MockSession.instance.deleteAccount();
    } catch (e, st) {
      debugPrint('[AccountDeletion] mock delete FAIL: $e');
      debugPrint('$st');
      MockSession.instance.logout();
    }

    // 5) 스택 클리어 → 로그인
    _goLoginGate();

    return AccountDeletionResult(
      ok: true,
      message: '계정이 삭제되었습니다.',
      apiMode: apiResult.mode,
    );
  }

  /// 로그아웃 (unlink 없음)
  Future<void> logout() async {
    await _logoutGuard.run(() async {
      final user = MockSession.instance.currentUser;
      final provider = (await _secure.readAuthProvider()) ?? 'kakao';
      try {
        await FcmService.instance.unbind();
      } catch (_) {}
      await _social.signOutOnly(authProvider: provider);
      await LocalDataCleaner.clearSessionOnly(userId: user?.uid);
      MockSession.instance.logout();
      _goLoginGate();
    });
  }

  void _goLoginGate() {
    if (appNavigatorKey.currentState == null) return;
    AppNavigation.pushAndRemoveUntilRoot(
      name: AppRouteNames.home,
      builder: (_) => const AuthHomeGate(),
    );
  }
}

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.ok,
    this.message = '',
    this.apiMode,
  });

  final bool ok;
  final String message;
  final String? apiMode;
}
