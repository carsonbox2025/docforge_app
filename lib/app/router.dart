import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'shell.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/profile_setup_page.dart';
import '../features/auth/presentation/pages/onboarding_page.dart';
import '../features/auth/domain/providers/auth_provider.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/generate/presentation/pages/generate_page.dart';
import '../features/polish/presentation/pages/polish_page.dart';
import '../features/translate/presentation/pages/translate_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/notification/presentation/pages/notification_page.dart';
import '../features/notification/presentation/pages/notification_detail_page.dart';
import '../features/membership/presentation/pages/subscription_page.dart';
import '../features/template/presentation/pages/template_gallery_page.dart';
import '../features/template/presentation/pages/template_preview_page.dart';
import '../features/document/presentation/pages/document_center_page.dart';
import '../features/document/presentation/pages/document_detail_page.dart';
import '../features/glossary/presentation/pages/glossary_page.dart';
import '../features/search/presentation/pages/search_page.dart';
import '../features/profile/presentation/pages/settings_page.dart';
import '../features/profile/presentation/pages/usage_page.dart';
import '../features/profile/presentation/pages/about_page.dart';
import '../features/auth/presentation/pages/legal_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/feedback/presentation/pages/feedback_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

CustomTransitionPage _fastFadePage(Widget child, ValueKey<String> key) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _AuthListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthListenable();

  ref.listen(authProvider, (_, _) {
    authNotifier.notify();
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isSplashPage = state.matchedLocation == '/splash';
      final isAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/forgot-password';
      final isProfileSetup = state.matchedLocation == '/profile-setup';
      final isLegalPage = state.matchedLocation.startsWith('/legal');
      final isAuthenticated = authState.isAuthenticated;
      final isRestoring = authState.isRestoring;

      if (isRestoring) return isSplashPage ? null : '/splash';

      if (isSplashPage) return null;

      if (!isAuthenticated) {
        return isAuthPage || isProfileSetup || isLegalPage ? null : '/login';
      }

      // 阶段1: 新用户 → 资料补全
      if (authState.isNewUser) {
        return state.matchedLocation == '/profile-setup' ? null : '/profile-setup';
      }

      // 阶段2: 资料补全完成 → 功能引导
      if (authState.needsOnboarding) {
        return state.matchedLocation == '/onboarding' ? null : '/onboarding';
      }

      // 阶段3: 正常使用
      return isAuthPage ? '/' : null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordPage()),
      GoRoute(path: '/profile-setup', builder: (_, _) => const ProfileSetupPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(
        path: '/legal/:type',
        builder: (_, state) {
          final type = state.pathParameters['type'] ?? 'terms';
          return LegalPage(type: type);
        },
      ),

      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, navigationShell) =>
                AppNavigationShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(path: '/', builder: (_, _) => const HomePage()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/generate', builder: (_, _) => const GeneratePage()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/polish', builder: (_, _) => const PolishPage()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/translate', builder: (_, _) => const TranslatePage()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
              ]),
            ],
          ),
        ],
      ),

      GoRoute(path: '/notifications', pageBuilder: (_, _) => _fastFadePage(const NotificationPage(), const ValueKey('notifications'))),
      GoRoute(
        path: '/notifications/:id',
        pageBuilder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return _fastFadePage(NotificationDetailPage(notificationId: id), ValueKey('notif-$id'));
        },
      ),
      GoRoute(path: '/subscription', pageBuilder: (_, _) => _fastFadePage(const SubscriptionPage(), const ValueKey('subscription'))),
      GoRoute(path: '/templates', pageBuilder: (_, _) => _fastFadePage(const TemplateGalleryPage(), const ValueKey('templates'))),
      GoRoute(path: '/templates/:id', pageBuilder: (_, state) {
        final id = state.pathParameters['id'] ?? '';
        return _fastFadePage(TemplatePreviewPage(templateId: id), ValueKey('template-$id'));
      }),
      GoRoute(path: '/documents', pageBuilder: (_, _) => _fastFadePage(const DocumentCenterPage(), const ValueKey('documents'))),
      GoRoute(path: '/documents/:id', pageBuilder: (_, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return _fastFadePage(DocumentDetailPage(docId: id), ValueKey('doc-$id'));
      }),
      GoRoute(path: '/glossary', pageBuilder: (_, _) => _fastFadePage(const GlossaryPage(), const ValueKey('glossary'))),
      GoRoute(path: '/search', pageBuilder: (_, _) => _fastFadePage(const SearchPage(), const ValueKey('search'))),
      GoRoute(path: '/settings', pageBuilder: (_, _) => _fastFadePage(const SettingsPage(), const ValueKey('settings'))),
      GoRoute(path: '/usage', pageBuilder: (_, _) => _fastFadePage(const UsagePage(), const ValueKey('usage'))),
      GoRoute(path: '/about', pageBuilder: (_, _) => _fastFadePage(const AboutPage(), const ValueKey('about'))),
      GoRoute(path: '/feedback', pageBuilder: (_, _) => _fastFadePage(const FeedbackPage(), const ValueKey('feedback'))),
    ],
  );
});
