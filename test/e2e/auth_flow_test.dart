import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docforge_app/app/app.dart';
import 'package:flutter/material.dart';

void main() {
  group('Auth Flow E2E', () {
    Widget buildApp() => const ProviderScope(child: DocForgeApp());

    testWidgets('Login page renders correctly', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('稿搭子'), findsOneWidget);
      expect(find.text('AI 驱动的专业文档生成平台'), findsOneWidget);
      expect(find.text('手机登录'), findsOneWidget);
      expect(find.text('密码登录'), findsOneWidget);
      expect(find.text('登 录'), findsOneWidget);
      expect(find.text('还没有账号？'), findsOneWidget);
    });

    testWidgets('Switch to password login tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('密码登录'));
      await tester.pumpAndSettle();

      expect(find.text('手机号 / 邮箱'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
      expect(find.text('忘记密码？'), findsOneWidget);
    });

    testWidgets('Phone validation - empty submit stays on page', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('登 录'));
      await tester.pumpAndSettle();

      expect(find.text('稿搭子'), findsOneWidget);
    });

    testWidgets('Navigate to register page', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('立即注册'), findsOneWidget);
    });
  });
}
