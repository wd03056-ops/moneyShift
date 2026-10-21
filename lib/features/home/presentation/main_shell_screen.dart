import 'package:flutter/material.dart';

import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_route_names.dart';
import '../../../core/theme/app_decorations.dart';
import '../../rooms/presentation/create_room_screen.dart';
import '../../rooms/presentation/room_list_screen.dart';

/// 앱 루트 — 하단 내비게이션 (홈 / 방만들기)
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  void _openCreate() {
    AppNavigation.pushSingleTop(
      name: AppRouteNames.createRoom,
      builder: (_) => const CreateRoomScreen(),
    );
  }

  void _onDestinationSelected(int index) {
    if (index == 1) {
      _openCreate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const RoomListScreen(),
      bottomNavigationBar: DecoratedBox(
        decoration: AppDecorations.topHairline,
        child: NavigationBar(
          selectedIndex: 0,
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
          ],
        ),
      ),
    );
  }
}
