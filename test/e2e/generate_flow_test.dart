import 'package:flutter_test/flutter_test.dart';
import 'package:docforge_app/features/generate/presentation/pages/generate_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Generate Flow E2E', () {
    Widget buildTestWidget(Widget child) {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => child),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    testWidgets('Generate input page renders all elements', (tester) async {
      await tester.pumpWidget(buildTestWidget(const GeneratePage()));
      await tester.pumpAndSettle();

      expect(find.text('专业长文档编写'), findsOneWidget);
      expect(find.text('合同'), findsOneWidget);
      expect(find.text('标书'), findsOneWidget);
      expect(find.text('公文'), findsOneWidget);
      expect(find.text('快速撰写'), findsOneWidget);
      expect(find.text('撰写大纲'), findsOneWidget);
      expect(find.text('中文'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('Can select document type chip', (tester) async {
      await tester.pumpWidget(buildTestWidget(const GeneratePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('标书'));
      await tester.pumpAndSettle();

      expect(find.text('标书'), findsOneWidget);
    });
  });
}
