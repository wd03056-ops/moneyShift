import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/scrollable_page_body.dart';
import '../../../mock/app_listenables.dart';
import '../../../mock/mock_session.dart';
import '../../../mock/mock_user.dart';

/// 홈 하단 — 사장/직원 목업 계정 전환 (테스트용)
class TestAccountSwitchTab extends StatelessWidget {
  const TestAccountSwitchTab({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: AppListenables.sessionAndStore,
      builder: (context, _) {
        final current = MockSession.instance.currentUser;

        return Scaffold(
          body: ScrollablePageBody(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('계정 전환', style: textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '사장·직원 화면을 바로 비교합니다 (테스트용)',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                ...MockUser.switchableAccounts.map((account) {
                  final selected = current?.uid == account.uid;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${account.personaLabel} · ${account.displayName}',
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(account.email),
                        trailing: selected
                            ? Text(
                                '사용 중',
                                style: textTheme.labelSmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                              ),
                        onTap: selected
                            ? null
                            : () {
                                MockSession.instance.loginAs(account);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${account.personaLabel} · '
                                      '${account.displayName}으로 전환',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                      ),
                      const Divider(height: 1),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
