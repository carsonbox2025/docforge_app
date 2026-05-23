import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/first_visit_tip.dart';
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
      body: FirstVisitTip(
        id: 'generate',
        icon: Icons.bolt,
        title: '描述需求，生成专业文档',
        description: '输入主题或关键词，选择场景，即可生成10万字长文档。\n生成后可在线预览、精修、翻译。',
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
