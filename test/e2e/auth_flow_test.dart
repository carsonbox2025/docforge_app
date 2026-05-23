import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docforge_app/app/app.dart';
import 'package:flutter/material.dart';

void main() {
  group('Auth Flow E2E', () {
    Widget buildApp() => const ProviderScope(child: DocForgeApp());

    testWidgets('Login page renders SMS-first correctly', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('稿搭子'), findsOneWidget);
      expect(find.text('AI 驱动的专业文档生成平台'), findsOneWidget);
      expect(find.text('登录 / 注册'), findsOneWidget);
      expect(find.text('已有密码？使用密码登录'), findsOneWidget);
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

      expect(find.text('稿搭子'), findsOneWidget);
    });
  });
}
