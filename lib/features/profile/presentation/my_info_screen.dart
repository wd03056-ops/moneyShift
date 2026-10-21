import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/app_listenables.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_store.dart';
import '../../../mock/mock_user.dart';
import '../../auth/data/account_deletion_service.dart';
import '../../legal/legal_document_screen.dart';
import '../../legal/legal_texts.dart';
import '../../notifications/presentation/notification_test_screen.dart';
import '../../notifications/presentation/push_notification_switch_tile.dart';
import 'edit_profile_screen.dart';

/// 하단 탭 — 내정보 (+ 테스트 계정 전환)
class MyInfoScreen extends StatelessWidget {
  const MyInfoScreen({super.key});

  void _switchTo(MockUser user) {
    MockSession.instance.loginAs(user);
  }

  void _openEdit(BuildContext context) {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.editProfile,
      builder: (_) => const EditProfileScreen(),
    );
  }

  void _openLegal(BuildContext context, {required String title, required String body}) {
    final slug = title.hashCode.toRadixString(16);
    AppNavigation.pushSingleTop(
      name: AppRouteNames.legal(slug),
      builder: (_) => LegalDocumentScreen(title: title, body: body),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('로그아웃'),
        content: const Text('이 계정에서 로그아웃할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await AccountDeletionService.instance.logout();
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('계정 삭제'),
        content: const Text(
          '계정을 삭제하면 소셜 로그인 연동이 해제되고, '
          '프로필·푸시 토큰 등 개인정보가 파기됩니다.\n\n'
          '매장의 근무·급여 기록은 \'(탈퇴한 회원)\'으로 남으며 '
          '복구할 수 없습니다.\n\n계속하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '삭제',
              style: TextStyle(color: AppColors.holiday),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final result =
          await AccountDeletionService.instance.deleteCurrentAccount();
      if (!result.ok && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      messenger?.showSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: result.ok ? null : AppColors.holiday,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('계정 삭제 실패: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.holiday,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppListenables.sessionAndStore,
      builder: (context, _) {
        final user = MockSession.instance.currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('로그인 정보가 없습니다.')),
          );
        }

        final textTheme = Theme.of(context).textTheme;

        return Scaffold(
          body: ScrollablePageBody(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('내정보', style: textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '계정·약관·앱 정보를 관리합니다',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                AppCard(
                  onTap: () => _openEdit(context),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${user.personaLabel} · ${user.email}',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_outlined,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('알림', style: textTheme.titleMedium),
                const SizedBox(height: 10),
                const PushNotificationSwitchTile(),
                if (kDebugMode) ...[
                  const SizedBox(height: 10),
                  AppCard(
                    onTap: () {
                      AppNavigation.pushSingleTop(
                        name: AppRouteNames.notificationTest,
                        builder: (_) => const NotificationTestScreen(),
                      );
                    },
                    child: Text(
                      '알림 테스트 (개발용)',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text('약관 및 정책', style: textTheme.titleMedium),
                const SizedBox(height: 10),
                AppCard(
                  onTap: () => _openLegal(
                    context,
                    title: '이용약관',
                    body: LegalTexts.termsOfServiceMarkdown,
                  ),
                  child: Text('이용약관', style: textTheme.bodyLarge),
                ),
                const SizedBox(height: 10),
                AppCard(
                  onTap: () => _openLegal(
                    context,
                    title: '개인정보처리방침',
                    body: LegalTexts.privacyPolicyMarkdown,
                  ),
                  child: Text('개인정보처리방침', style: textTheme.bodyLarge),
                ),
                const SizedBox(height: 10),
                AppCard(
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppConstants.appName,
                    applicationLegalese:
                        '© ${DateTime.now().year} ${AppConstants.developerName}',
                  ),
                  child: Text('오픈소스 라이선스', style: textTheme.bodyLarge),
                ),
                const SizedBox(height: 10),
                AppCard(
                  child: Text(
                    AppConstants.appVersionLabel,
                    style: textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 24),
                const AppSectionDivider(height: 8),
                const SizedBox(height: 24),
                Text('테스트 계정 전환', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '목업 계정으로 사장·직원 화면을 바로 비교합니다',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                ...MockUser.switchableAccounts.expand((account) {
                  final selected = user.uid == account.uid;
                  return [
                    if (account != MockUser.switchableAccounts.first)
                      const SizedBox(height: 10),
                    _SwitchAccountTile(
                      selected: selected,
                      title:
                          '${account.personaLabel} · ${account.displayName}',
                      subtitle: account.email,
                      onTap: selected ? null : () => _switchTo(account),
                    ),
                  ];
                }),
                const SizedBox(height: 12),
                AppCard(
                  onTap: () {
                    MockStore.instance.resetAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('데모 매장·초대 데이터를 다시 불러왔습니다.'),
                      ),
                    );
                  },
                  child: Text('데모 데이터 초기화', style: textTheme.bodyLarge),
                ),
                const SizedBox(height: 10),
                AppCard(
                  onTap: () => _confirmLogout(context),
                  child: Text(
                    '로그아웃',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.holiday,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AppCard(
                  onTap: () => _confirmDeleteAccount(context),
                  child: Text(
                    '계정 삭제',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.holiday,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '문의 ${AppConstants.supportEmail}',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SwitchAccountTile extends StatelessWidget {
  const _SwitchAccountTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (selected)
            Text(
              '사용 중',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.success,
                  ),
            ),
        ],
      ),
    );
  }
}
