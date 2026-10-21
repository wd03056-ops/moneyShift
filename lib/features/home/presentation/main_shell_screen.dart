import 'package:flutter/material.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/theme/app_decorations.dart';
import '../../profile/presentation/my_info_screen.dart';
import '../../rooms/presentation/create_room_screen.dart';
import '../../rooms/presentation/join_room_screen.dart';
import '../../rooms/presentation/room_list_screen.dart';

/// 앱 루트 — 하단 내비게이션 (홈 / 방만들기 / 초대코드 / 내정보)
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  /// 0: 홈, 1: 내정보
  int _contentIndex = 0;

  int get _navIndex => _contentIndex == 0 ? 0 : 3;

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
    switch (index) {
      case 0:
        setState(() => _contentIndex = 0);
      case 1:
        _openCreate();
      case 2:
        _openJoin();
      case 3:
        setState(() => _contentIndex = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _contentIndex,
        children: const [
          RoomListScreen(),
          MyInfoScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: AppDecorations.topHairline,
        child: NavigationBar(
          selectedIndex: _navIndex,
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
              icon: Icon(Icons.qr_code_outlined),
              selectedIcon: Icon(Icons.qr_code),
              label: '초대코드',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: '내정보',
            ),
          ],
        ),
      ),
    );
  }
}
