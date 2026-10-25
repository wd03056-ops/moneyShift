import 'package:flutter/material.dart';

import '../../../mock/mock_session.dart';
import '../../home/presentation/main_shell_screen.dart';
import 'logged_out_home.dart';
import 'profile_setup_screen.dart';

/// 로그인 / 실명 온보딩 / 메인 분기
///
/// - 미로그인 → [LoggedOutHome] (로그인 화면을 push — 뒤로가기 가능)
/// - 로그인 + realName 없음 → [ProfileSetupScreen]
/// - 로그인 + realName 있음 → [MainShellScreen]
class AuthHomeGate extends StatelessWidget {
  const AuthHomeGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MockSession.instance,
      builder: (context, _) {
        final session = MockSession.instance;
        // home 하위만 키로 교체 (MaterialApp/Navigator Inherited 유지)
        final gateKey = !session.isLoggedIn
            ? 'logged_out'
            : session.needsProfileSetup
                ? 'setup_${session.currentUser!.uid}'
                : 'home_${session.currentUser!.uid}';

        Widget child;
        if (!session.isLoggedIn) {
          child = const LoggedOutHome();
        } else if (session.needsProfileSetup) {
          child = ProfileSetupScreen(
            uid: session.currentUser!.uid,
            initialName: session.currentUser!.displayName,
          );
        } else {
          child = const MainShellScreen();
        }

        return KeyedSubtree(
          key: ValueKey<String>(gateKey),
          child: child,
        );
      },
    );
  }
}
