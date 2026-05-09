import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/domain/providers/auth_provider.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/generate/presentation/pages/generate_page.dart';
import '../features/polish/presentation/pages/polish_page.dart';
import '../features/translate/presentation/pages/translate_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/notification/presentation/pages/notification_page.dart';
import '../features/membership/presentation/pages/subscription_page.dart';
import '../features/template/presentation/pages/template_gallery_page.dart';
import '../features/template/presentation/pages/template_preview_page.dart';
import '../features/history/presentation/pages/history_list_page.dart';
import '../features/history/presentation/pages/history_detail_page.dart';
import '../features/glossary/presentation/pages/glossary_page.dart';
import '../features/search/presentation/pages/search_page.dart';
import '../features/profile/presentation/pages/settings_page.dart';
import '../features/profile/presentation/pages/usage_page.dart';
import '../features/draft/presentation/pages/drafts_page.dart';
import 'shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class _AuthListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthListenable();

  ref.listen(authProvider, (_, __) {
    authNotifier.notify();
  });

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isAuthenticated = authState.isAuthenticated;
      final isRestoring = authState.isLoading;

      if (isRestoring) return null;
      if (!isAuthenticated && !isAuthPage) return '/login';
      if (isAuthenticated && isAuthPage) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),

      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, __, navigationShell) =>
                AppNavigationShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(path: '/', builder: (_, __) => const HomePage()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/generate', builder: (_, __) => const GeneratePage()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/polish', builder: (_, __) => const PolishPage()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/translate', builder: (_, __) => const TranslatePage()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
              ]),
            ],
          ),
        ],
      ),

      GoRoute(path: '/notifications', builder: (_, __) => const NotificationPage()),
      GoRoute(path: '/subscription', builder: (_, __) => const SubscriptionPage()),
      GoRoute(path: '/templates', builder: (_, __) => const TemplateGalleryPage()),
      GoRoute(path: '/templates/:id', builder: (_, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return TemplatePreviewPage(templateId: id);
      }),
      GoRoute(path: '/history', builder: (_, __) => const HistoryListPage()),
      GoRoute(path: '/history/:id', builder: (_, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return HistoryDetailPage(documentId: id);
      }),
      GoRoute(path: '/glossary', builder: (_, __) => const GlossaryPage()),
      GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(path: '/usage', builder: (_, __) => const UsagePage()),
      GoRoute(path: '/drafts', builder: (_, __) => const DraftsPage()),
    ],
  );
});
