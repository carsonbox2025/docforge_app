import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:docforge_app/app/app.dart';
import 'package:flutter/material.dart';

void main() {
  group('Navigation E2E', () {
    Widget buildApp() => const ProviderScope(child: DocForgeApp());

    testWidgets('App starts with login page', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('稿搭子'), findsOneWidget);
    });
  });
}
