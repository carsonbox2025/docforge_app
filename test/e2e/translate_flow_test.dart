import 'package:flutter_test/flutter_test.dart';
import 'package:docforge_app/features/translate/presentation/pages/translate_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Translate Flow E2E', () {
    Widget buildTestWidget(Widget child) {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => child),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    testWidgets('Translate page renders correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget(const TranslatePage()));
      await tester.pumpAndSettle();

      expect(find.text('智能翻译'), findsOneWidget);
      expect(find.text('文本翻译'), findsOneWidget);
      expect(find.text('文档翻译'), findsOneWidget);
    });

    testWidgets('Can switch to document translation mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(const TranslatePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('文档翻译'));
      await tester.pumpAndSettle();

      expect(find.text('上传文档翻译'), findsOneWidget);
    });
  });
}
