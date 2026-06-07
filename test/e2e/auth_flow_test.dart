import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docforge_app/app/app.dart';
import 'package:docforge_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter/material.dart';

void main() {
  group('Auth Flow', () {
    Widget buildApp() => const ProviderScope(child: DocForgeApp());

    testWidgets('Login page renders SMS-first correctly', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('文稿工坊'), findsOneWidget);
      expect(find.text('登录 / 注册'), findsOneWidget);
    });

    testWidgets('Switch to password login', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('已有密码？使用密码登录'));
      await tester.pumpAndSettle();

      expect(find.text('登 录'), findsOneWidget);
      expect(find.text('手机验证码登录'), findsOneWidget);
    });

    testWidgets('Empty submit stays on page', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('登录 / 注册'));
      await tester.pumpAndSettle();

      expect(find.text('文稿工坊'), findsOneWidget);
    });
  });

  group('Forgot Password Flow', () {
    testWidgets('Forgot password link visible in password mode', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: DocForgeApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('已有密码？使用密码登录'));
      await tester.pumpAndSettle();

      expect(find.text('忘记密码？'), findsOneWidget);
    });

    testWidgets('Navigates to forgot password page', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: DocForgeApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('已有密码？使用密码登录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('忘记密码？'));
      await tester.pumpAndSettle();

      expect(find.text('重置密码'), findsOneWidget);
      expect(find.text('获取验证码'), findsOneWidget);
    });
  });

  group('Register Page', () {
    testWidgets('Register page shows legal agreement checkbox', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: DocForgeApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('注册账号'));
      await tester.pumpAndSettle();

      expect(find.text('创建账号'), findsOneWidget);
      expect(find.text('《用户协议》'), findsOneWidget);
      expect(find.text('《隐私协议》'), findsOneWidget);
    });
  });

  group('Auth State Machine', () {
    test('AuthState defaults to initial', () {
      const state = AuthState();
      expect(state.status, AuthStatus.initial);
      expect(state.isAuthenticated, false);
      expect(state.isNewUser, false);
      expect(state.needsOnboarding, false);
    });

    test('AuthState copyWith preserves fields', () {
      const initial = AuthState();
      final state = initial.copyWith(
        status: AuthStatus.authenticated,
        token: 'test-token',
        isNewUser: true,
      );
      expect(state.status, AuthStatus.authenticated);
      expect(state.isNewUser, true);
      expect(state.isAuthenticated, true);
    });

    test('AuthStatus enum values', () {
      expect(AuthStatus.values.length, 6);
      expect(AuthStatus.initial.index, 0);
      expect(AuthStatus.authenticated.index, 3);
    });
  });
}
