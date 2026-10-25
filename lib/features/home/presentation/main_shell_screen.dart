import 'package:flutter/material.dart';

import '../../../core/ads/widgets/app_banner_ad.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/theme/app_decorations.dart';
import '../../rooms/presentation/create_room_screen.dart';
import '../../rooms/presentation/join_room_screen.dart';
import '../../rooms/presentation/room_list_screen.dart';
import 'test_account_switch_tab.dart';

/// 앱 루트 — 하단 내비게이션 (홈 / 방만들기 / 방들어가기 / 계정전환)
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  /// 0 = 홈, 1 = 계정전환 (방만들기·방들어가기는 push만)
  int _bodyIndex = 0;

  void _openCreate() {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.createRoom,
      builder: (_) => const CreateRoomScreen(),
    );
  }

  void _openJoin() {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.joinRoom,
      builder: (_) => const JoinRoomScreen(),
    );
  }

  void _onDestinationSelected(int index) {
    // 방만들기·방들어가기는 탭 화면이 아니라 push
    if (index == 1) {
      _openCreate();
      return;
    }
    if (index == 2) {
      _openJoin();
      return;
    }
    setState(() => _bodyIndex = index == 3 ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    // selectedIndex: 0=홈, 1·2는 항상 비선택, 3=계정전환
    final navIndex = _bodyIndex == 1 ? 3 : 0;

    return Scaffold(
      body: IndexedStack(
        index: _bodyIndex,
        children: const [
          RoomListScreen(),
          TestAccountSwitchTab(),
        ],
      ),
      bottomNavigationBar: BottomNavWithBanner(
        navigationBar: DecoratedBox(
          decoration: AppDecorations.topHairline,
          child: NavigationBar(
            selectedIndex: navIndex,
            onDestinationSelected: _onDestinationSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: '홈',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_business_outlined),
                selectedIcon: Icon(Icons.add_business),
                label: '방만들기',
              ),
              NavigationDestination(
                icon: Icon(Icons.login_outlined),
                selectedIcon: Icon(Icons.login_rounded),
                label: '방들어가기',
              ),
              NavigationDestination(
                icon: Icon(Icons.swap_horiz_outlined),
                selectedIcon: Icon(Icons.swap_horiz_rounded),
                label: '계정전환',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
