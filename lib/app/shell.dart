import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/app_spacing.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}

class AppNavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppNavigationShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: navigationShell.currentIndex,
          onTap: (index) {
            if (index == navigationShell.currentIndex) return;
            navigationShell.goBranch(index);
          },
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          elevation: 0,
          items: [
            _navItem(Icons.home_outlined, Icons.home, '首页'),
            _navItem(Icons.bolt_outlined, Icons.bolt, '生成'),
            _navItem(Icons.auto_fix_high_outlined, Icons.auto_fix_high, '精修'),
            _navItem(Icons.translate_outlined, Icons.translate, '翻译'),
            _navItem(Icons.person_outline, Icons.person, '我的'),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData icon, IconData activeIcon, String label) {
    return BottomNavigationBarItem(
      icon: Icon(icon, size: 22),
      activeIcon: Icon(activeIcon, size: 22),
      label: label,
    );
  }
}
