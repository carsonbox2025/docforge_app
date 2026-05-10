import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/generate_models.dart';
import '../../domain/providers/generate_provider.dart';
import '../../../../shared/models/dsl/document_block.dart';
import '../../../../shared/widgets/feature_header.dart';
import '../../../../shared/widgets/blocks/block_renderer.dart';
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
      if (next.currentBlocks != prev?.currentBlocks) {
        _scrollToBottom();
      }
    });

    final hasBlocks = state.currentBlocks.isNotEmpty;
    final isGenerating = state.status == GenerationStatus.generating;

    return Column(
      children: [
        FeatureHeader(
          color: AppColors.primary,
          title: '正在生成',
          subtitle: '${state.selectedType.label} · ${state.selectedLanguage.label}',
          showBackButton: true,
          onBack: () => notifier.backToInput(),
        ),
        _buildSteps(),
        Expanded(
          child: hasBlocks
              ? _buildBlockLayout(state, isGenerating)
              : _buildLegacyLayout(state, isGenerating),
        ),
        // 底部进度条
        _buildProgressBar(state),
        const SizedBox(height: 16),
      ],
    );
  }

  // ===========================================================================
  // Block DSL 布局（左侧大纲 + 右侧渲染区）
  // ===========================================================================

  Widget _buildBlockLayout(GenerateState state, bool isGenerating) {
    return Row(
      children: [
        // 左侧大纲
        SizedBox(
          width: 120,
          child: _buildOutlinePanel(state),
        ),
        Container(width: 1, color: AppColors.border),
        // 右侧渲染区
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
              child: _buildBlockContent(state, isGenerating),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutlinePanel(GenerateState state) {
    return Container(
      color: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.outline.length,
        itemBuilder: (_, i) {
          final item = state.outline[i];
          final isActive = item.status == ChapterStatus.generating;
          final isDone = item.status == ChapterStatus.completed;

          final parsed = parseChapterId(item.chapterId);
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

  Widget _buildBlockContent(GenerateState state, bool isGenerating) {
    final outline = state.outline;
    final blocks = state.currentBlocks;

    if (outline.isEmpty && blocks.isEmpty) {
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
      final chId = item.chapterId;
      final chapterBlocks = blocks[chId] ?? [];

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

      // 章节 blocks
      int h3Counter = 0;
      int h4Counter = 0;
      final isLastChapter = oi == outline.length - 1;

      for (int bi = 0; bi < chapterBlocks.length; bi++) {
        final block = chapterBlocks[bi];
        final isLastBlock = isLastChapter && bi == chapterBlocks.length - 1;
        final showCursor = isLastBlock && isGenerating;

        // heading 编号跟踪
        if (block.type == BlockType.heading) {
          final level = block.level ?? 2;
          if (level == 3) { h3Counter++; h4Counter = 0; }
          if (level == 4) h4Counter++;
        }

        // 跳过与章节标题匹配的 heading block
        if (block.type == BlockType.heading) {
          final headingText = block.text ?? '';
          if (stripHeadingNumber(headingText).trim() == cleanTitle) continue;
        }

        widgets.add(BlockRenderer(
          block: block,
          isStreaming: showCursor,
          chapterIndex: mainChapterIdx,
          h3Counter: h3Counter,
          h4Counter: h4Counter,
        ));
      }

      if (item.status == ChapterStatus.generating && chapterBlocks.isEmpty) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  // ===========================================================================
  // 旧版纯文本布局（direct_llm 兼容）
  // ===========================================================================

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
              state.generatedContent,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text, height: 1.8),
            ),
            if (isGenerating) const _Cursor(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 公共组件
  // ===========================================================================

  Widget _buildSteps() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
    final completed = state.outline.where((o) => o.status == ChapterStatus.completed).length;
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

/// 脉冲点
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

/// 小脉冲点（大纲用）
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
