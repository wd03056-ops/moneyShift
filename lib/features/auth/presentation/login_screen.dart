import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/config/dev_auth_config.dart';
import '../../../core/config/kakao_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/deeplink/invite_deep_link_service.dart';
import '../../../core/storage/secure_session_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../core/widgets/sticky_action_button.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_store.dart';
import '../../../mock/mock_user.dart';
import '../../legal/legal_links.dart';
import '../data/auth_flow_exception.dart';
import '../data/auth_service.dart';
import '../data/mock_auth_service.dart';
import 'widgets/kakao_login_button.dart';

/// 카카오 로그인(실연동) + 개발용 테스트 로그인
///
/// 릴리즈(Play 심사)용: 안내 문구 2초 내 5연타 → 심사용 Mock 로그인 다이얼로그
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _hiddenTapTarget = 5;
  static const Duration _hiddenTapWindow = Duration(seconds: 2);

  bool _kakaoLoading = false;
  bool _mockLoading = false;
  int _hiddenTapCount = 0;
  Timer? _hiddenTapResetTimer;

  bool get _busy => _kakaoLoading || _mockLoading;

  @override
  void initState() {
    super.initState();
    MockSession.instance.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _hiddenTapResetTimer?.cancel();
    MockSession.instance.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// Play 심사용 히든 트리거 — 2초 이내 5연타
  void _onHiddenSubtitleTap() {
    if (_busy) return;

    _hiddenTapResetTimer?.cancel();
    _hiddenTapCount += 1;

    if (_hiddenTapCount >= _hiddenTapTarget) {
      _hiddenTapCount = 0;
      HapticFeedback.mediumImpact();
      unawaited(_showReviewerTestLoginDialog());
      return;
    }

    _hiddenTapResetTimer = Timer(_hiddenTapWindow, () {
      _hiddenTapCount = 0;
    });
  }

  Future<void> _showReviewerTestLoginDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('테스트 계정 로그인'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('구글 심사용 테스트 계정으로 로그인하시겠습니까?'),
              const SizedBox(height: 20),
              StickyActionButton(
                label: '사장님 테스트 계정 로그인',
                variant: StickyActionVariant.filled,
                onPressed: _busy
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        unawaited(_loginWithMock(MockAuthPersona.owner));
                      },
              ),
              const SizedBox(height: 8),
              StickyActionButton(
                label: '직원 테스트 계정 로그인',
                variant: StickyActionVariant.primary,
                onPressed: _busy
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        unawaited(_loginWithMock(MockAuthPersona.staff));
                      },
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('취소'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 로그인 성공 시 push 된 로그인 라우트를 닫아 AuthHomeGate(메인/온보딩)가 보이게 함
  void _onSessionChanged() {
    if (!mounted) return;
    if (!MockSession.instance.isLoggedIn) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  void _loginAs(MockUser user) {
    MockSession.instance.loginAs(user);
  }

  Future<void> _loginWithMock(MockAuthPersona persona) async {
    if (_busy) return;
    setState(() => _mockLoading = true);
    try {
      final result = await AuthService.instance.signInWithMock(
        persona: persona,
      );
      if (!mounted) return;
      debugPrint(
        '[LoginScreen] Mock OK uid=${result.mockUser.uid} '
        'userDoc=${result.user.docPath}',
      );
      await SecureSessionStorage.instance.saveSession(
        userId: result.user.uid,
        authProvider: result.usedMockAuth ? 'mock' : result.user.authProvider,
        accessToken: result.kakao.accessToken,
        refreshToken: result.kakao.refreshToken,
        firebaseUid: result.firebaseUid,
      );
      MockSession.instance.loginAs(result.mockUser);
      // AuthHomeGate 가 사장/직원 메인으로 전환 (로그인 라우트 pop)
      _showMessage(
        result.needsProfileSetup
            ? '실명 등록이 필요합니다'
            : '${result.user.preferredDisplayName}님 테스트 로그인',
      );
    } catch (e, st) {
      debugPrint('[LoginScreen] Mock login FAIL: $e');
      debugPrint('$st');
      if (!mounted) return;
      _showMessage('Mock 로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _mockLoading = false);
    }
  }

  /// 실제 카카오 SDK 로그인 창 (톡/계정)
  Future<void> _loginWithKakao() async {
    if (_busy) return;

    if (!KakaoConfig.isConfigured) {
      await _showErrorDialog(
        '카카오 설정 필요',
        '카카오 네이티브 앱 키를 설정하세요.\n'
        '(KakaoConfig / android/kakao.properties)',
      );
      return;
    }

    setState(() => _kakaoLoading = true);
    try {
      final result = await AuthService.instance.signInWithKakao();
      if (!mounted) return;
      debugPrint(
        '[LoginScreen] Kakao+Firebase OK firebaseUid=${result.firebaseUid} '
        'userDoc=${result.user.docPath} kakaoId=${result.kakao.userId}',
      );
      await SecureSessionStorage.instance.saveSession(
        userId: result.user.uid,
        authProvider: result.user.authProvider,
        accessToken: result.kakao.accessToken,
        refreshToken: result.kakao.refreshToken,
        firebaseUid: result.firebaseUid,
      );
      MockSession.instance.loginAs(result.mockUser);
      debugPrint(
        '[LoginScreen] route → '
        '${result.needsProfileSetup ? "ProfileSetup" : "Main"}',
      );
      _showMessage(
        result.needsProfileSetup
            ? '실명을 등록해 주세요'
            : '${result.user.preferredDisplayName}님, 카카오 로그인 완료',
      );
    } on AuthFlowException catch (e, st) {
      debugPrint('[LoginScreen] AuthFlowException ${e.code}: ${e.message}');
      debugPrint('$st');
      if (!mounted) return;
      if (e.userCancelled) return;
      await _showErrorDialog(
        e.network ? '네트워크 오류' : '로그인 실패',
        e.message,
      );
    } on KakaoAuthException catch (e, st) {
      debugPrint(
        '[LoginScreen] KakaoAuthException ${e.error}: ${e.errorDescription}',
      );
      debugPrint('$st');
      if (!mounted) return;
      if (e.error == AuthErrorCause.accessDenied) return;
      await _showErrorDialog(
        '카카오 로그인 실패',
        e.errorDescription ?? e.error.toString(),
      );
    } on KakaoClientException catch (e, st) {
      debugPrint('[LoginScreen] KakaoClientException ${e.reason}: ${e.msg}');
      debugPrint('$st');
      if (!mounted) return;
      if (e.reason == ClientErrorCause.cancelled) return;
      await _showErrorDialog('카카오 로그인 실패', e.msg);
    } on FirebaseAuthException catch (e, st) {
      debugPrint('[LoginScreen] FirebaseAuthException ${e.code}: ${e.message}');
      debugPrint('$st');
      if (!mounted) return;
      await _showErrorDialog(
        'Firebase 인증 실패',
        e.message ?? e.code,
      );
    } on FirebaseException catch (e, st) {
      debugPrint('[LoginScreen] FirebaseException ${e.code}: ${e.message}');
      debugPrint('$st');
      if (!mounted) return;
      await _showErrorDialog(
        '사용자 정보 저장 실패',
        e.message ?? e.code,
      );
    } catch (e, st) {
      debugPrint('[LoginScreen] Kakao login FAIL: $e');
      debugPrint('$st');
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('CANCELED') || msg.contains('cancelled')) return;
      await _showErrorDialog('로그인 실패', msg);
    } finally {
      if (mounted) setState(() => _kakaoLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showErrorDialog(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _onAppBarBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    // 로그아웃 후 루트 로그인 — 스택에 돌아갈 화면이 없을 때
    // (시스템 뒤로가기와 동일하게 앱을 종료하지 않고 안내만)
  }

  @override
  Widget build(BuildContext context) {
    final accounts = MockUser.switchableAccounts;
    final textTheme = Theme.of(context).textTheme;
    final canPop = Navigator.of(context).canPop();
    final showTestLogin = DevAuthConfig.isMockAuthEnabled || kDebugMode;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: '뒤로',
                onPressed: _onAppBarBack,
              )
            : null,
        title: const Text('로그인'),
        centerTitle: false,
      ),
      body: ScrollablePageBody(
        top: false,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppConstants.appName,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onHiddenSubtitleTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '카카오 계정으로 간편하게 시작하세요',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '만 ${AppConstants.minimumAgeYears}세 이상만 이용할 수 있습니다.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textCaption,
              ),
            ),
            FutureBuilder<String?>(
              future: InviteDeepLinkService.instance.peekPendingCode(),
              builder: (context, snap) {
                final code = snap.data;
                if (code == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '초대 코드 $code 가 대기 중입니다. 로그인하면 참여 화면으로 이동합니다.',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            KakaoLoginButton(
              onPressed: _busy ? null : _loginWithKakao,
              isLoading: _kakaoLoading,
            ),
            if (!KakaoConfig.isConfigured) ...[
              const SizedBox(height: 8),
              Text(
                '카카오 앱 키가 없습니다. 설정 후 이용할 수 있습니다.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.holiday,
                ),
              ),
            ],
            if (showTestLogin) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '테스트 로그인',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '개발용 · 카카오 SDK 없이 바로 진입',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textCaption,
                ),
              ),
              if (DevAuthConfig.isMockAuthEnabled) ...[
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Mock Auth ON\n'
                    '사장 UID: ${MockAuthService.ownerUid}\n'
                    '알바 UID: ${MockAuthService.staffUid}',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  onTap: _busy
                      ? null
                      : () => _loginWithMock(MockAuthPersona.owner),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mock 사장으로 로그인', style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '테스트 사용자 · ${MockAuthService.ownerUid}',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  onTap: _busy
                      ? null
                      : () => _loginWithMock(MockAuthPersona.staff),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mock 알바로 로그인', style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '테스트 알바 · ${MockAuthService.staffUid}',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '데모 매장 · 초대코드 ${MockStore.demoInviteCode}',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textCaption,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < accounts.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _AccountLoginCard(
                  user: accounts[i],
                  onTap: _busy ? null : () => _loginAs(accounts[i]),
                ),
              ],
            ],
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '계속하면 ',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: () => LegalLinks.openTermsOfService(context),
                  child: Text(
                    '이용약관',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  ' 및 ',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: () => LegalLinks.openPrivacyPolicy(context),
                  child: Text(
                    '개인정보처리방침',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  '에 동의하는 것으로 간주됩니다.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountLoginCard extends StatelessWidget {
  const _AccountLoginCard({
    required this.user,
    required this.onTap,
  });

  final MockUser user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isOwner = user.isOwnerPersona;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isOwner ? '사장 계정으로 로그인' : '직원 계정으로 로그인',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${user.displayName} · ${user.personaLabel}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
