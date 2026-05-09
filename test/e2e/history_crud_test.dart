import 'package:flutter_test/flutter_test.dart';
import 'package:docforge_app/features/history/presentation/pages/history_list_page.dart';
import 'package:docforge_app/features/history/presentation/pages/history_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('History CRUD E2E', () {
    Widget buildTestWidget(Widget child) {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => child),
          GoRoute(
            path: '/history/:id',
            builder: (_, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return HistoryDetailPage(documentId: id);
            },
          ),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    testWidgets('History list page renders', (tester) async {
      await tester.pumpWidget(buildTestWidget(const HistoryListPage()));
      await tester.pumpAndSettle();

      expect(find.text('历史文档'), findsOneWidget);
    });

    testWidgets('History detail page renders', (tester) async {
      await tester.pumpWidget(buildTestWidget(const HistoryDetailPage(documentId: 1)));
      await tester.pumpAndSettle();

      expect(find.text('导出 Word'), findsOneWidget);
    });
  });
}
