import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/providers/generate_provider.dart';
import '../../../../shared/models/dsl/dsl_node.dart' show DslNode;
import '../../../../shared/widgets/feature_header.dart';
import '../../../../shared/widgets/dsl/dsl_renderer.dart';
import '../../../../shared/utils/chapter_numbering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeneratingStage extends ConsumerStatefulWidget {
  const GeneratingStage({super.key});

  @override
  ConsumerState<GeneratingStage> createState() => _GeneratingStageState();
}

class _GeneratingStageState extends ConsumerState<GeneratingStage> {
  final _scrollController = ScrollController();
  bool _userScrolledUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    _userScrolledUp = max - current > 80;
  }

  void _scrollToBottom() {
    if (_userScrolledUp) return;
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
      if (next.dslNodes != prev?.dslNodes) {
        _scrollToBottom();
      }
    });

    final hasNodes = state.dslNodes.isNotEmpty &&
        state.dslNodes.values.any((list) => list.isNotEmpty);
    final isGenerating = state.status == GenerationStatus.generating;

    final hasError = state.error != null;

    return Column(
      children: [
        FeatureHeader(
          color: hasError ? AppColors.error : AppColors.primary,
          title: hasError ? '生成失败' : '正在生成',
          subtitle: '${state.selectedType.label} · ${state.selectedLanguage.label}',
          showBackButton: true,
          onBack: () => notifier.backToInput(),
        ),
        _buildSteps(isGenerating, notifier),
        if (hasError)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(child: Text(state.error!, style: TextStyle(fontSize: 12, color: AppColors.error))),
                TextButton(
                  onPressed: () => notifier.backToInput(),
                  child: Text('返回修改', style: TextStyle(fontSize: 12, color: AppColors.error)),
                ),
              ],
            ),
          ),
        if (!hasError)
          Expanded(
            child: hasNodes
                ? _buildDslLayout(state, isGenerating)
                : _buildLegacyLayout(state, isGenerating),
          ),
        if (!hasError)
          _buildProgressBar(state),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─── DSL 布局（统一渲染器）───

  Widget _buildDslLayout(GenerateState state, bool isGenerating) {
    return Row(
      children: [
        // 左侧大纲
        SizedBox(
          width: 120,
          child: _buildOutlinePanel(state),
        ),
        Container(width: 1, color: AppColors.border),
        // 右侧 DSL 渲染区
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: _buildDslContent(state, isGenerating),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDslContent(GenerateState state, bool isGenerating) {
    final outline = state.outline;
    final nodes = state.dslNodes;

    if (outline.isEmpty && nodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulseDot(),
              SizedBox(height: 12),
              Text('AI 正在规划文档结构...', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
    }

    final List<Widget> widgets = [];
    int mainChapterIdx = 0;

    for (int oi = 0; oi < outline.length; oi++) {
      final item = outline[oi];
      final chId = item.id;
      final sectionNodes = nodes[chId] ?? [];

      // 章节标题
      final parsed = parseChapterId(chId);
      final isSub = parsed?.sub != null;
      if (!isSub) mainChapterIdx++;
      final chNum = isSub ? '${parsed!.top}.${parsed.sub}' : toChineseNum(mainChapterIdx);
      final cleanTitle = stripTitleNumber(item.title);

      widgets.add(Padding(
        padding: EdgeInsets.only(top: oi == 0 ? 0 : 16, bottom: 8),
        child: isSub
            ? Text('$chNum $cleanTitle', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text))
            : Text('$chNum、$cleanTitle', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
      ));

      // 章节内容 — 使用 DslRenderer
      final isLastSection = oi == outline.length - 1;
      if (sectionNodes.isNotEmpty) {
        widgets.add(DslRenderer(
          nodes: sectionNodes,
          isStreaming: isLastSection && isGenerating,
        ));
      } else if (item.status == 'generating') {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildOutlinePanel(GenerateState state) {
    return Container(
      color: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.outline.length,
        itemBuilder: (_, i) {
          final item = state.outline[i];
          final isActive = item.status == 'generating';
          final isDone = item.status == 'completed';

          final parsed = parseChapterId(item.id);
          final chapterNum = parsed != null ? toChineseNum(parsed.top) : '${i + 1}';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: isDone
                      ? const Icon(Icons.check_circle, size: 14, color: AppColors.success)
                      : isActive
                          ? const _MiniPulseDot()
                          : Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                            ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$chapterNum、${stripTitleNumber(item.title)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? AppColors.primary : isDone ? AppColors.text : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── 旧版纯文本布局（兼容无 DSL 数据时）───

  Widget _buildLegacyLayout(GenerateState state, bool isGenerating) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _PulseDot(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.docTitle.isEmpty ? state.selectedType.label : state.docTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              state.progressMsg ?? '正在处理...',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text, height: 1.8),
            ),
            if (isGenerating) const _Cursor(),
          ],
        ),
      ),
    );
  }

  // ─── 公共组件 ───

  Widget _buildSteps(bool isGenerating, GenerateNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stepDot(StepStatus.done),
                _stepLine(true),
                _stepDot(StepStatus.active),
                _stepLine(false),
                _stepDot(StepStatus.pending),
              ],
            ),
          ),
          if (isGenerating)
            TextButton.icon(
              onPressed: () => _confirmCancel(notifier),
              icon: Icon(Icons.stop_circle_outlined, size: 18, color: AppColors.textMuted),
              label: Text('取消', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  void _confirmCancel(GenerateNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消生成'),
        content: const Text('已生成的内容将不会保存，确定取消吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('继续生成'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.cancelGenerate();
            },
            child: Text('确定取消', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _stepDot(StepStatus status) {
    final color = switch (status) {
      StepStatus.done => AppColors.success,
      StepStatus.active => AppColors.primary,
      StepStatus.pending => AppColors.border,
    };
    return Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  Widget _stepLine(bool done) {
    return Container(width: 32, height: 2, color: done ? AppColors.success : AppColors.border);
  }

  Widget _buildProgressBar(GenerateState state) {
    final completed = state.outline.where((o) => o.status == 'completed').length;
    final total = state.outline.length;
    final progress = total > 0 ? completed / total : state.progress;
    final pctText = '${(progress * 100).round()}%';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(pctText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 0.5),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: 0.5),
      ]).animate(_controller),
      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
    );
  }
}

class _MiniPulseDot extends StatefulWidget {
  const _MiniPulseDot();
  @override
  State<_MiniPulseDot> createState() => _MiniPulseDotState();
}

class _MiniPulseDotState extends State<_MiniPulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
    );
  }
}

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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 0.5),
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 0.5),
      ]).animate(_controller),
      child: Container(width: 2, height: 14, margin: const EdgeInsets.only(left: 2), color: AppColors.primary),
    );
  }
}
