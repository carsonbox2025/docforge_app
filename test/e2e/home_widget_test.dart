import 'package:flutter_test/flutter_test.dart';
import 'package:docforge_app/features/home/presentation/pages/home_page.dart';
import 'package:docforge_app/features/home/presentation/widgets/quick_actions.dart';
import 'package:docforge_app/features/home/presentation/widgets/recent_documents.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Home Page Widget Tests', () {
    Widget buildTestWidget(Widget child) {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => child),
          GoRoute(path: '/generate', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/polish', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/translate', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/templates', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/notifications', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/search', builder: (_, _) => const SizedBox()),
        ],
      );

      return MaterialApp.router(routerConfig: router);
    }

    testWidgets('Home page shows all key elements', (tester) async {
      await tester.pumpWidget(buildTestWidget(const HomePage()));
      await tester.pumpAndSettle();

      expect(find.text('稿搭子'), findsOneWidget);
      expect(find.text('智能文档工坊'), findsOneWidget);
      expect(find.text('文章撰写'), findsOneWidget);
      expect(find.text('精修排版'), findsOneWidget);
      expect(find.text('多语翻译'), findsOneWidget);
      expect(find.text('模板库'), findsOneWidget);
      expect(find.text('最近文档'), findsOneWidget);
    });

    testWidgets('Quick actions renders 4 items', (tester) async {
      await tester.pumpWidget(buildTestWidget(const QuickActions()));
      await tester.pumpAndSettle();

      expect(find.text('文章撰写'), findsOneWidget);
      expect(find.text('精修排版'), findsOneWidget);
      expect(find.text('多语翻译'), findsOneWidget);
      expect(find.text('模板库'), findsOneWidget);
    });

    testWidgets('Recent documents shows document list', (tester) async {
      await tester.pumpWidget(buildTestWidget(const RecentDocuments()));
      await tester.pumpAndSettle();

      expect(find.text('技术开发合作合同'), findsOneWidget);
      expect(find.text('智慧园区建设投标方案'), findsOneWidget);
    });
  });
}
