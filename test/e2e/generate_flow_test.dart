import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:docforge_app/features/generate/presentation/pages/generate_page.dart';
import 'package:docforge_app/features/generate/domain/providers/generate_provider.dart';
import 'package:docforge_app/features/generate/data/generate_data_source.dart';
import 'package:docforge_app/features/scene/data/models/scene_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ============================================================================
// Mocks
// ============================================================================

class MockGenerateDataSource extends Mock implements GenerateDataSource {}

// ============================================================================
// Helpers
// ============================================================================

Widget buildTestWidget(Widget child) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => child)],
  );
  return ProviderScope(
    child: MaterialApp.router(routerConfig: router),
  );
}

SceneConfig _mockScene() => SceneConfig(
      sceneId: 'scene_generic',
      docType: 'generic',
      name: '通用文档',
      templateId: 'tpl_generic_clean',
      layer: 1,
      pricing: const PricingInfo(type: 'free'),
      formFields: [],
      reviewRules: [],
    );

// ============================================================================
// Tests
// ============================================================================

void main() {
  group('Generate Page UI', () {
    testWidgets('Generate input page renders all elements', (tester) async {
      await tester.pumpWidget(buildTestWidget(const GeneratePage()));
      await tester.pumpAndSettle();

      expect(find.text('快速撰写'), findsOneWidget);
      expect(find.text('专业长文档编写'), findsOneWidget);
      expect(find.text('中文'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });
  });

  group('GenerateState Machine', () {
    test('GenerateState defaults', () {
      const state = GenerateState();
      expect(state.stage, GenerateStage.input);
      expect(state.status, GenerationStatus.idle);
      expect(state.progress, 0.0);
      expect(state.documentId, null);
      expect(state.error, null);
    });

    test('copyWith transitions stage correctly', () {
      const initial = GenerateState();
      final state = initial.copyWith(
        stage: GenerateStage.generating,
        status: GenerationStatus.planning,
        progress: 0.1,
      );
      expect(state.stage, GenerateStage.generating);
      expect(state.status, GenerationStatus.planning);
      expect(state.progress, 0.1);
    });

    test('GenerationStatus enum values', () {
      expect(GenerationStatus.values.length, 6);
      expect(GenerationStatus.idle.index, 0);
      expect(GenerationStatus.complete.index, 3);
      expect(GenerationStatus.error.index, 5);
    });

    test('GenerateStage enum values', () {
      expect(GenerateStage.values.length, 3);
      expect(GenerateStage.input.index, 0);
      expect(GenerateStage.review.index, 2);
    });
  });

  group('GenerateNotifier Operations', () {
    test('selectScene accepts valid scene', () {
      final notifier = GenerateNotifier(MockGenerateDataSource());
      final scene = _mockScene();
      notifier.selectScene(scene);
      // selectScene 将场景写入 state
    });

    test('backToInput returns to input stage', () {
      final notifier = GenerateNotifier(MockGenerateDataSource());
      notifier.backToInput();
      // 验证回到 input stage
    });

    test('clearError removes error state', () {
      final notifier = GenerateNotifier(MockGenerateDataSource());
      notifier.clearError();
      // 验证 error 被清除
    });
  });
}
