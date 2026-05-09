import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/generate_models.dart';
import '../../domain/providers/generate_provider.dart';
import '../../../../shared/widgets/feature_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stage 2: 生成中
class GeneratingStage extends ConsumerStatefulWidget {
  const GeneratingStage({super.key});

  @override
  ConsumerState<GeneratingStage> createState() => _GeneratingStageState();
}

class _GeneratingStageState extends ConsumerState<GeneratingStage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generateProvider);
    final notifier = ref.read(generateProvider.notifier);

    ref.listen<GenerateState>(generateProvider, (prev, next) {
      if (next.generatedContent != prev?.generatedContent) {
        _scrollToBottom();
      }
    });

    final pctText = '${(state.progress * 100).round()}%';

    return Column(
      children: [
        // 蓝色头部
        FeatureHeader(
          color: AppColors.primary,
          title: '正在生成',
          subtitle: '${state.docTitle.isEmpty ? state.selectedType.label : state.docTitle} · ${state.selectedType.label}文本',
          showBackButton: true,
          onBack: () => notifier.backToInput(),
        ),
        // 步骤指示器
        _buildSteps(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            '第二步 · AI 实时生成文档',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ),
        // 流式内容区域
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                // 白色卡片
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题行 + 绿色脉冲点
                      Row(
                        children: [
                          const _PulseDot(),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.docTitle.isEmpty ? state.selectedType.label : state.docTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 渲染流式内容
                      _buildStreamContent(state.generatedContent, state.stage),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 进度条
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: AppColors.borderLight,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: state.progress.clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              pctText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSteps() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepDot(StepStatus.done),
          _stepLine(StepStatus.done),
          _stepDot(StepStatus.active),
          _stepLine(StepStatus.pending),
          _stepDot(StepStatus.pending),
        ],
      ),
    );
  }

  Widget _stepDot(StepStatus status) {
    Color color;
    switch (status) {
      case StepStatus.done:
        color = AppColors.success;
      case StepStatus.active:
        color = AppColors.primary;
      case StepStatus.pending:
        color = AppColors.border;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _stepLine(StepStatus status) {
    return Container(
      width: 32,
      height: 2,
      color: status == StepStatus.done ? AppColors.success : AppColors.border,
    );
  }

  Widget _buildStreamContent(String content, GenerateStage stage) {
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    final lines = content.split('\n');
    final List<Widget> widgets = [];

    for (final line in lines) {
      if (line.isEmpty) continue;
      if (line.startsWith('### ')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
            ),
            child: Text(
              line.substring(4),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
                height: 1.8,
              ),
            ),
          ),
        );
      }
    }

    // 生成中时显示光标
    if (stage == GenerateStage.generating) {
      widgets.add(const _Cursor());
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}

/// 绿色脉冲点
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 0.5),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: 0.5),
      ]).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// 闪烁光标
class _Cursor extends StatefulWidget {
  const _Cursor();

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 0.5),
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 0.5),
      ]).animate(_controller),
      child: Container(
        width: 2,
        height: 14,
        margin: const EdgeInsets.only(left: 2),
        color: AppColors.primary,
      ),
    );
  }
}
