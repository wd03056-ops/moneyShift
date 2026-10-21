import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_store.dart';
import '../../../mock/mock_user.dart';
import '../../auth/data/account_deletion_service.dart';
import '../../legal/legal_document_screen.dart';
import '../../legal/legal_texts.dart';
import '../../notifications/presentation/notification_test_screen.dart';
import 'edit_profile_screen.dart';

/// 계정·약관·테스트 메뉴 (알림 토글은 제외 — 방 화면에 이미 있음)
class AccountExtrasSection extends StatelessWidget {
  const AccountExtrasSection({
    super.key,
    this.showProfileEdit = true,
    this.showLogoutDelete = true,
    this.showLegal = true,
    this.showLegalSectionLabel = true,
    this.showTestAccounts = true,
    this.showSupportEmail = true,
    this.showNotificationTest = true,
  });

  final bool showProfileEdit;
  final bool showLogoutDelete;
  final bool showLegal;
  final bool showLegalSectionLabel;
  final bool showTestAccounts;
  final bool showSupportEmail;

  /// 개발용 알림 테스트 메뉴 (kDebugMode일 때만 실제 표시)
  final bool showNotificationTest;

  void _openEdit(BuildContext context) {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.editProfile,
      builder: (_) => const EditProfileScreen(),
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
    try {
      await AccountDeletionService.instance.logout();
    } finally {
      // pushAndRemoveUntil 로 로딩 dialog 도 함께 제거됨
    }
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
    final textTheme = Theme.of(context).textTheme;
    final user = MockSession.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showProfileEdit) ...[
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 24,
            horizontalTitleGap: 12,
            leading: const Icon(
              Icons.edit_outlined,
              color: AppColors.primary,
            ),
            title: Text(
              '프로필 수정',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              user?.preferredDisplayName ?? user?.displayName ?? '프로필',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
            onTap: () => _openEdit(context),
          ),
        ],
        if (showNotificationTest && kDebugMode) ...[
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 24,
            horizontalTitleGap: 12,
            leading: const Icon(
              Icons.bug_report_outlined,
              color: AppColors.primary,
            ),
            title: Text(
              '알림 테스트',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              '개발용',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
            onTap: () {
              AppNavigation.pushSingleTop(
                name: AppRouteNames.notificationTest,
                builder: (_) => const NotificationTestScreen(),
              );
            },
          ),
        ],
        if (showTestAccounts) ...[
          const SizedBox(height: 20),
          const _SectionLabel(title: '테스트 계정'),
          Text(
            '목업 계정으로 사장·직원 화면을 바로 비교합니다',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...MockUser.switchableAccounts.map((account) {
            final selected = user?.uid == account.uid;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              minLeadingWidth: 24,
              horizontalTitleGap: 12,
              title: Text('${account.personaLabel} · ${account.displayName}'),
              subtitle: Text(account.email),
              trailing: selected
                  ? Text(
                      '사용 중',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                      ),
                    )
                  : null,
              onTap: selected
                  ? null
                  : () => MockSession.instance.loginAs(account),
            );
          }),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 24,
            horizontalTitleGap: 12,
            title: const Text('데모 데이터 초기화'),
            onTap: () {
              MockStore.instance.resetAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('데모 매장·초대 데이터를 다시 불러왔습니다.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
        if (showLogoutDelete) ...[
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 24,
            horizontalTitleGap: 12,
            title: Text(
              '로그아웃',
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.holiday,
              ),
            ),
            onTap: () => _confirmLogout(context),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 24,
            horizontalTitleGap: 12,
            title: Text(
              '계정 삭제',
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.holiday,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: () => _confirmDeleteAccount(context),
          ),
        ],
        if (showLegal) ...[
          if (showLegalSectionLabel) ...[
            const SizedBox(height: 20),
            const _SectionLabel(title: '약관 및 정책'),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 24,
            horizontalTitleGap: 12,
            title: const Text('이용약관'),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
            onTap: () => _openLegal(
              context,
              title: '이용약관',
              body: LegalTexts.termsOfServiceMarkdown,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 24,
            horizontalTitleGap: 12,
            title: const Text('개인정보처리방침'),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
            onTap: () => _openLegal(
              context,
              title: '개인정보처리방침',
              body: LegalTexts.privacyPolicyMarkdown,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 24,
            horizontalTitleGap: 12,
            title: const Text('오픈소스 라이선스'),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppConstants.appName,
              applicationLegalese:
                  '© ${DateTime.now().year} ${AppConstants.developerName}',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            minLeadingWidth: 24,
            horizontalTitleGap: 12,
            title: Text(AppConstants.appVersionLabel),
          ),
        ],
        if (showSupportEmail) ...[
          const SizedBox(height: 16),
          Text(
            '문의 ${AppConstants.supportEmail}',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
