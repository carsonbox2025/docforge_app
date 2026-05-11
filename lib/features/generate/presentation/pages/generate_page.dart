import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/providers/generate_provider.dart';
import '../widgets/input_stage.dart';
import '../widgets/generating_stage.dart';
import '../widgets/review_stage.dart';

class GeneratePage extends ConsumerWidget {
  const GeneratePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(generateProvider.select((s) => s.stage));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _buildStage(stage),
      ),
    );
  }

  Widget _buildStage(GenerateStage stage) {
    switch (stage) {
      case GenerateStage.input:
        return const InputStage();
      case GenerateStage.generating:
        return const GeneratingStage();
      case GenerateStage.review:
        return const ReviewStage();
    }
  }
}
