import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/theme_provider.dart';

const _tabPaths = {'/', '/generate', '/polish', '/translate', '/profile'};

class DocForgeApp extends ConsumerStatefulWidget {
  const DocForgeApp({super.key});

  @override
  ConsumerState<DocForgeApp> createState() => _DocForgeAppState();
}

class _DocForgeAppState extends ConsumerState<DocForgeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 必须立即注册，确保在 GoRouter 的 RootBackButtonDispatcher 之前
    // handlePopRoute() 按正序遍历 observers，先注册的先拦截
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    final router = ref.read(routerProvider);
    final currentPath = router.state.matchedLocation;

    if (!_tabPaths.contains(currentPath)) {
      return false;
    }

    final context = rootNavigatorKey.currentContext;
    if (context == null) return false;

    if (currentPath != '/') {
      router.go('/');
      return true;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '确定要退出吗？',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('退出',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (shouldExit == true && context.mounted) {
      SystemNavigator.pop();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: '稿搭子',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
    );
  }
}
