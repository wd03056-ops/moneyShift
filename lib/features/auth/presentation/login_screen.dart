import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/config/dev_auth_config.dart';
import '../../../core/config/kakao_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/deeplink/invite_deep_link_service.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_store.dart';
import '../../../mock/mock_user.dart';
import '../../legal/legal_document_screen.dart';
import '../../legal/legal_texts.dart';
import '../data/auth_service.dart';
import '../data/mock_auth_service.dart';
import 'widgets/kakao_login_button.dart';

/// 개발·테스트용 계정 선택 로그인 + 카카오 로그인
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _kakaoLoading = false;

  void _loginAs(MockUser user) {
    MockSession.instance.loginAs(user);
  }

  Future<void> _loginWithMock(MockAuthPersona persona) async {
    if (_kakaoLoading) return;
    setState(() => _kakaoLoading = true);
    try {
      final result = await AuthService.instance.signInWithMock(
        persona: persona,
      );
      if (!mounted) return;
      debugPrint(
        '[LoginScreen] Mock OK uid=${result.mockUser.uid} '
        'userDoc=${result.user.docPath}',
      );
      MockSession.instance.loginAs(result.mockUser);
      // AuthHomeGate 가 realName 유무로 메인/온보딩 분기
      _showMessage(
        result.needsProfileSetup
            ? '실명 등록이 필요합니다'
            : '${result.user.preferredDisplayName}님 (Mock) 로그인',
      );
    } catch (e, st) {
      debugPrint('[LoginScreen] Mock login FAIL: $e');
      debugPrint('$st');
      if (!mounted) return;
      _showMessage('Mock 로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _kakaoLoading = false);
    }
  }

  Future<void> _loginWithKakao() async {
    if (_kakaoLoading) return;

    // Mock 모드에서도 강제 실로그인 테스트가 필요하면 플래그를 끈다.
    if (DevAuthConfig.isMockAuthEnabled) {
      await _loginWithMock(MockAuthPersona.owner);
      return;
    }

    if (!KakaoConfig.isConfigured) {
      _showMessage(
        '카카오 네이티브 앱 키를 설정하세요. '
        '(KakaoConfig / android/kakao.properties / ios Flutter Kakao-Keys.xcconfig)',
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
    } on KakaoAuthException catch (e, st) {
      debugPrint(
        '[LoginScreen] KakaoAuthException ${e.error}: ${e.errorDescription}',
      );
      debugPrint('$st');
      if (!mounted) return;
      if (e.error == AuthErrorCause.accessDenied) return;
      _showMessage('카카오 로그인 실패: ${e.errorDescription ?? e.error}');
    } on KakaoClientException catch (e, st) {
      debugPrint('[LoginScreen] KakaoClientException ${e.reason}: ${e.msg}');
      debugPrint('$st');
      if (!mounted) return;
      if (e.reason == ClientErrorCause.cancelled) return;
      _showMessage('카카오 로그인 실패: ${e.msg}');
    } on FirebaseAuthException catch (e, st) {
      debugPrint('[LoginScreen] FirebaseAuthException ${e.code}: ${e.message}');
      debugPrint('$st');
      if (!mounted) return;
      _showMessage('Firebase 인증 실패: ${e.message ?? e.code}');
    } on FirebaseException catch (e, st) {
      debugPrint('[LoginScreen] FirebaseException ${e.code}: ${e.message}');
      debugPrint('$st');
      if (!mounted) return;
      _showMessage('Firestore 저장 실패: ${e.message ?? e.code}');
    } catch (e, st) {
      debugPrint('[LoginScreen] Kakao login FAIL: $e');
      debugPrint('$st');
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('CANCELED') || msg.contains('cancelled')) return;
      _showMessage('카카오 로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _kakaoLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openLegal(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final slug = title.hashCode.toRadixString(16);
    AppNavigation.pushSingleTop(
      name: AppRouteNames.legal(slug),
      builder: (_) => LegalDocumentScreen(title: title, body: body),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = MockUser.switchableAccounts;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: ScrollablePageBody(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppConstants.appName,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DevAuthConfig.isMockAuthEnabled
                  ? 'Mock 인증 모드 · 카카오 SDK 없이 테스트'
                  : '카카오로 로그인하거나 테스트 계정을 선택하세요',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '데모 매장 · 초대코드 ${MockStore.demoInviteCode}',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              '만 ${AppConstants.minimumAgeYears}세 이상만 이용할 수 있습니다.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textCaption,
              ),
            ),
            if (DevAuthConfig.isMockAuthEnabled) ...[
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'useMockAuth=true\n'
                  '사장 UID: ${MockAuthService.ownerUid}\n'
                  '알바 UID: ${MockAuthService.staffUid}\n'
                  '끄려면 DevAuthConfig.useMockAuth = false',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
            ],
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
            const SizedBox(height: 28),
            if (DevAuthConfig.isMockAuthEnabled) ...[
              AppCard(
                onTap: _kakaoLoading
                    ? null
                    : () => _loginWithMock(MockAuthPersona.owner),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mock 사장으로 로그인',
                      style: textTheme.titleMedium,
                    ),
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
                onTap: _kakaoLoading
                    ? null
                    : () => _loginWithMock(MockAuthPersona.staff),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mock 알바로 로그인',
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '테스트 알바 · ${MockAuthService.staffUid}',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ] else ...[
              KakaoLoginButton(
                onPressed: _kakaoLoading ? null : _loginWithKakao,
                isLoading: _kakaoLoading,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '또는 로컬 목업 계정',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.border)),
              ],
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < accounts.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _AccountLoginCard(
                user: accounts[i],
                onTap: () => _loginAs(accounts[i]),
              ),
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
                  onTap: () => _openLegal(
                    context,
                    title: '이용약관',
                    body: LegalTexts.termsOfServiceMarkdown,
                  ),
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
                  onTap: () => _openLegal(
                    context,
                    title: '개인정보처리방침',
                    body: LegalTexts.privacyPolicyMarkdown,
                  ),
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
            const SizedBox(height: 16),
            Text(
              DevAuthConfig.isMockAuthEnabled
                  ? 'Mock Auth ON · Firestore users/stores 시드'
                  : (KakaoConfig.isConfigured
                      ? '카카오 로그인 · Firestore 연동'
                      : '카카오 키 미설정'),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
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
  final VoidCallback onTap;

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
