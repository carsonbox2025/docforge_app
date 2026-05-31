import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../features/notification/domain/providers/notification_provider.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}

class AppNavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppNavigationShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadAsync.maybeWhen(data: (c) => c, orElse: () => 0);

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
              _centerNavItem(),
              _navItem(Icons.auto_fix_high_outlined, Icons.auto_fix_high, '精修'),
              _navItem(Icons.translate_outlined, Icons.translate, '翻译'),
              _profileNavItem(unreadCount),
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

  BottomNavigationBarItem _profileNavItem(int unreadCount) {
    final badge = unreadCount > 99 ? '99+' : '$unreadCount';
    return BottomNavigationBarItem(
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(badge, style: const TextStyle(fontSize: 9)),
        child: const Icon(Icons.person_outline, size: 22),
      ),
      activeIcon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(badge, style: const TextStyle(fontSize: 9)),
        child: const Icon(Icons.person, size: 22),
      ),
      label: '我的',
    );
  }

  BottomNavigationBarItem _centerNavItem() {
    return BottomNavigationBarItem(
      icon: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.bolt, size: 22, color: Colors.white),
      ),
      activeIcon: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.bolt, size: 24, color: Colors.white),
      ),
      label: '生成',
    );
  }
}
