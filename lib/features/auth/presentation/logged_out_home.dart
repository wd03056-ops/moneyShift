import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/theme/app_colors.dart';
import 'login_screen.dart';
import 'widgets/kakao_login_button.dart';

/// 로그아웃·미로그인 루트 — 로그인 화면을 push 해 뒤로가기 가능하게 함
class LoggedOutHome extends StatefulWidget {
  const LoggedOutHome({super.key, this.openLoginOnStart = true});

  /// 앱 첫 진입 시 로그인 화면을 바로 연다
  final bool openLoginOnStart;

  @override
  State<LoggedOutHome> createState() => _LoggedOutHomeState();
}

class _LoggedOutHomeState extends State<LoggedOutHome> {
  var _opened = false;

  @override
  void initState() {
    super.initState();
    if (widget.openLoginOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openLogin());
    }
  }

  Future<void> _openLogin() async {
    if (!mounted || _opened) return;
    _opened = true;
    await AppNavigation.pushSingleTop(
      name: AppRouteNames.login,
      builder: (_) => const LoginScreen(),
    );
    if (mounted) _opened = false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppConstants.appName,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '근무·출퇴근·급여를 한곳에서',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              KakaoLoginButton(
                label: '로그인',
                onPressed: _openLogin,
              ),
              const SizedBox(height: 12),
              Text(
                '카카오 또는 테스트 계정으로 로그인합니다',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textCaption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
