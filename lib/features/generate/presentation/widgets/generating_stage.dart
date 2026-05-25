import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/providers/generate_provider.dart';
import '../../../../shared/widgets/feature_header.dart';
import '../../../../shared/widgets/dsl/dsl_renderer.dart';
import '../../../../shared/models/dsl/dsl_node.dart';
import '../../../../shared/utils/chapter_numbering.dart';
import 'planning_stage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeneratingStage extends ConsumerStatefulWidget {
  const GeneratingStage({super.key});

  @override
  ConsumerState<GeneratingStage> createState() => _GeneratingStageState();
}

class _GeneratingStageState extends ConsumerState<GeneratingStage> {
  final _scrollController = ScrollController();
  bool _userScrolledUp = false;
  int _buildCount = 0;
  bool _isOutlineCollapsed = false;
  final Map<String, GlobalKey> _sectionKeys = {};
  String? _activeChapterId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    debugPrint('[GeneratingStage] initState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('[GeneratingStage] didChangeDependencies');
  }

  @override
  void dispose() {
    debugPrint('[GeneratingStage] dispose');
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
    final status = ref.watch(generateProvider.select((s) => s.status));
    final hasError = ref.watch(generateProvider.select((s) => s.error != null));
    final errorMsg = ref.watch(generateProvider.select((s) => s.error));
    final hasNodes = ref.watch(generateProvider.select(
        (s) => s.dslNodes.isNotEmpty && s.dslNodes.values.any((list) => list.isNotEmpty)));
    final hasOutline = ref.watch(generateProvider.select(
        (s) => s.outline.isNotEmpty && !(s.outline.length == 1 && s.outline.first.id == 'main')));

    final isGenerating = status == GenerationStatus.generating;
    final isPlanning = status == GenerationStatus.planning;

    final docTitle = ref.watch(generateProvider.select((s) => s.docTitle));
    final sceneName = ref.watch(generateProvider.select((s) => s.selectedScene?.name ?? '文档'));
    final langLabel = ref.watch(generateProvider.select((s) => s.selectedLanguage.label));
    
    final notifier = ref.read(generateProvider.notifier);
    _buildCount++;

    ref.listen(
      generateProvider.select((s) => s.dslNodes),
      (prev, next) {
        final hasNodes = next.isNotEmpty && next.values.any((list) => list.isNotEmpty);
        if (hasNodes) {
          _scrollToBottom();
        }
      },
    );

    return Column(
      children: [
        FeatureHeader(
          color: hasError ? AppColors.error : AppColors.primary,
          title: hasError ? '生成失败' : '正在生成',
          subtitle: '$sceneName · $langLabel',
          showBackButton: true,
          onBack: () => notifier.backToInput(),
        ),
        _buildSteps(isGenerating, isPlanning, notifier),
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
                const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMsg!, style: const TextStyle(fontSize: 12, color: AppColors.error))),
                TextButton(
                  onPressed: () => notifier.backToInput(),
                  child: const Text('返回修改', style: TextStyle(fontSize: 12, color: AppColors.error)),
                ),
              ],
            ),
          ),
        if (!hasError)
          Expanded(
            child: isPlanning
                ? Consumer(builder: (ctx, ref, _) {
                    final thoughts = ref.watch(generateProvider.select((s) => s.planningThoughts));
                    final phase = ref.watch(generateProvider.select((s) => s.planningPhase));
                    return PlanningStage(
                      thoughts: thoughts,
                      phase: phase,
                      title: docTitle.isNotEmpty ? docTitle : sceneName,
                    );
                  })
                : hasNodes || hasOutline
                    ? _buildDslLayout(isGenerating)
                    : _buildLegacyLayout(isGenerating),
          ),
        if (!hasError)
          _buildProgressBar(),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─── DSL 布局（统一渲染器）───

  Widget _buildDslLayout(bool isGenerating) {
    return Consumer(builder: (context, ref, _) {
      final outline = ref.watch(generateProvider.select((s) => s.outline));
      final hasOutline = outline.isNotEmpty;
      final isLayer1Style = !hasOutline ||
          (outline.length == 1 && outline.first.id == 'main');
      final showOutline = hasOutline && !isLayer1Style;

      return Row(
        children: [
          if (showOutline && !_isOutlineCollapsed) ...[
            SizedBox(
              width: 120,
              child: _buildOutlinePanel(outline),
            ),
            _buildCollapseToggle(isCollapsed: false),
          ],
          if (showOutline && _isOutlineCollapsed)
            _buildCollapseToggle(isCollapsed: true),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(6, 12, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 16, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: _buildDslContent(outline, isLayer1Style, isGenerating),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCollapseToggle({required bool isCollapsed}) {
    return GestureDetector(
      onTap: () => setState(() => _isOutlineCollapsed = !isCollapsed),
      child: _HoverToggle(isCollapsed: isCollapsed),
    );
  }

  Widget _buildDslContent(List<DslOutline> outline, bool isLayer1Style, bool isGenerating) {
    return Consumer(builder: (context, ref, _) {
      if (isLayer1Style) {
        final mainNodes = ref.watch(generateProvider.select((s) => s.dslNodes['main'] ?? const []));
        if (mainNodes.isNotEmpty) {
          try {
            return DslRenderer(
              nodes: mainNodes,
              isStreaming: isGenerating,
            );
          } catch (e) {
            debugPrint('[GeneratingStage] DslRenderer ERROR: $e');
            return _buildTextFallback(mainNodes);
          }
        }
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(),
                SizedBox(height: 12),
                Text('AI 正在生成文档内容...', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
        );
      }

      // Layer 2（有大纲）：按章节渲染
      final List<Widget> widgets = [];
      int mainChapterIdx = 0;
      int renderedIdx = 0;

      for (int oi = 0; oi < outline.length; oi++) {
        final item = outline[oi];
        final chId = item.id;

        // 章节编号始终递增（保持连续编号）
        final parsed = parseChapterId(chId);
        final isSub = parsed?.sub != null;
        if (!isSub) mainChapterIdx++;

        // 只渲染已开始或已完成的章节，pending 章节不显示
        if (item.status == 'pending') continue;

        final chNum = isSub ? '${parsed!.top}.${parsed.sub}' : toChineseNum(mainChapterIdx);
        final cleanTitle = stripTitleNumber(item.title);
        final titleWidgetText = isSub ? '$chNum $cleanTitle' : '$chNum、$cleanTitle';

        _sectionKeys.putIfAbsent(chId, () => GlobalKey());
        final sectionKey = _sectionKeys[chId]!;

        widgets.add(Padding(
          padding: EdgeInsets.only(top: renderedIdx == 0 ? 0 : 16),
          key: sectionKey,
          child: ChapterSectionView(
            chId: chId,
            titleWidgetText: titleWidgetText,
            isSub: isSub,
            isLastSection: oi == outline.length - 1,
            isGenerating: isGenerating,
            status: item.status,
          ),
        ));
        renderedIdx++;
      }

      // 最后一个正在生成的章节后显示等待提示
      final lastActive = outline.lastWhere(
        (o) => o.status != 'pending',
        orElse: () => DslOutline(id: '', title: '', status: 'pending'),
      );
      if (lastActive.status == 'generating' && outline.any((o) => o.status == 'pending')) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )),
        ));
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
    });
  }

  Widget _buildOutlinePanel(List<DslOutline> outline) {
    return Container(
      color: AppColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: outline.length,
        itemBuilder: (_, i) {
          final item = outline[i];
          final isActive = item.status == 'generating';
          final isDone = item.status == 'completed';
          final isSelected = _activeChapterId == item.id;

          final isPending = item.status == 'pending';

          final parsed = parseChapterId(item.id);
          final chapterNum = parsed != null ? toChineseNum(parsed.top) : '${i + 1}';

          return GestureDetector(
            onTap: isPending ? null : () => _scrollToChapter(item.id),
            child: MouseRegion(
              cursor: isPending ? SystemMouseCursors.basic : SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
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
                          fontWeight: isActive || isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isActive ? AppColors.primary : isDone ? AppColors.text : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _scrollToChapter(String chId) {
    setState(() => _activeChapterId = chId);
    final key = _sectionKeys[chId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ─── 旧版纯文本布局（兼容无 DSL 数据时）───

  Widget _buildLegacyLayout(bool isGenerating) {
    return Consumer(builder: (context, ref, _) {
      final docTitle = ref.watch(generateProvider.select((s) => s.docTitle));
      final progressMsg = ref.watch(generateProvider.select((s) => s.progressMsg));
      final sceneName = ref.watch(generateProvider.select((s) => s.selectedScene?.name ?? '文档'));

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
                      docTitle.isEmpty ? sceneName : docTitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                progressMsg ?? '正在处理...',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text, height: 1.8),
              ),
              if (isGenerating) const _Cursor(),
            ],
          ),
        ),
      );
    });
  }

  // ─── 公共组件 ───

  Widget _buildSteps(bool isGenerating, bool isPlanning, GenerateNotifier notifier) {
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
          if (isGenerating || isPlanning)
            TextButton.icon(
              onPressed: () => _confirmCancel(notifier),
              icon: const Icon(Icons.stop_circle_outlined, size: 18, color: AppColors.textMuted),
              label: const Text('取消', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmCancel(GenerateNotifier notifier) {
    final currentStatus = ref.read(generateProvider).status;
    if (currentStatus == GenerationStatus.complete) return;

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
            child: const Text('确定取消', style: TextStyle(color: AppColors.error)),
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

  Widget _buildProgressBar() {
    return Consumer(builder: (context, ref, _) {
      final outline = ref.watch(generateProvider.select((s) => s.outline));
      final rawProgress = ref.watch(generateProvider.select((s) => s.progress));
      
      final completed = outline.where((o) => o.status == 'completed').length;
      final total = outline.length;
      final progress = total > 0 ? completed / total : rawProgress;
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
    });
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

/// DslRenderer 出错时的纯文本回退渲染
Widget _buildTextFallback(List<DslNode> nodes) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: nodes.map((node) {
      final text = node.text ?? node.title ?? '';
      if (text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, height: 1.8, color: AppColors.text)),
      );
    }).toList(),
  );
}

/// 单章节渲染组件 — 仅在章节内容变化时 rebuild
class ChapterSectionView extends ConsumerWidget {
  final String chId;
  final String titleWidgetText;
  final bool isSub;
  final bool isLastSection;
  final bool isGenerating;
  final String status;

  const ChapterSectionView({
    super.key,
    required this.chId,
    required this.titleWidgetText,
    required this.isSub,
    required this.isLastSection,
    required this.isGenerating,
    required this.status,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // .select 仅在该章节的节点列表引用变化时触发 rebuild
    final sectionNodes = ref.watch(
      generateProvider.select((s) => s.dslNodes[chId]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: isSub
              ? Text(titleWidgetText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text))
              : Text(titleWidgetText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
        ),
        if (sectionNodes != null && sectionNodes.isNotEmpty)
          _buildContent(sectionNodes)
        else if (status == 'generating')
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
      ],
    );
  }

  Widget _buildContent(List<DslNode> sectionNodes) {
    final cleanedNodes = _filterTrailingDeclaration(sectionNodes);
    try {
      return DslRenderer(
        nodes: cleanedNodes,
        isStreaming: isLastSection && isGenerating,
      );
    } catch (e) {
      debugPrint('[ChapterSectionView] DslRenderer ERROR in section $chId: $e');
      return _buildTextFallback(cleanedNodes);
    }
  }

  static final _trailingSummaryPattern = RegExp(
    r'[（(]\s*本?章节?正文?结束[，,]?\s*无?小结[与和]?展望?\s*[）)]\s*$'
    r'|[（(].*?(?:无小结|正文结束|无结语|无展望|本章.*?结束).*?[）)]\s*$',
  );

  List<DslNode> _filterTrailingDeclaration(List<DslNode> nodes) {
    if (nodes.isEmpty || isGenerating) return nodes;
    final last = nodes.last;
    final text = last.text ?? '';
    if (_trailingSummaryPattern.hasMatch(text.trim())) {
      final cleaned = text.replaceAll(_trailingSummaryPattern, '').trim();
      if (cleaned.isEmpty) {
        return nodes.sublist(0, nodes.length - 1);
      }
      return [...nodes.sublist(0, nodes.length - 1), last.copyWith(text: cleaned)];
    }
    return nodes;
  }
}

class _HoverToggle extends StatefulWidget {
  final bool isCollapsed;
  const _HoverToggle({required this.isCollapsed});

  @override
  State<_HoverToggle> createState() => _HoverToggleState();
}

class _HoverToggleState extends State<_HoverToggle> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        width: 12,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _hovering ? AppColors.borderLight : Colors.transparent,
          border: Border(right: widget.isCollapsed ? BorderSide.none : BorderSide(color: AppColors.borderLight, width: 0.5)),
        ),
        child: Icon(
          widget.isCollapsed ? Icons.chevron_right : Icons.chevron_left,
          size: 12,
          color: _hovering ? AppColors.text : AppColors.textMuted,
        ),
      ),
    );
  }
}

