import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/feature_header.dart';
import '../../../payment/presentation/widgets/pay_wall.dart';
import '../../../scene/domain/providers/scene_provider.dart';
import '../../data/models/polish_models.dart';
import '../../domain/providers/polish_provider.dart';

class PolishPage extends ConsumerWidget {
  const PolishPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(polishProvider);

    // QUOTA_EXCEEDED 监听放在页面级（始终挂载），避免 AnimatedSwitcher 切换子 widget 时丢失 listener
    ref.listen<PolishState>(polishProvider, (prev, next) {
      if (next.errorMessage == 'QUOTA_EXCEEDED' &&
          (prev == null || prev.errorMessage != 'QUOTA_EXCEEDED')) {
        _showPayWall(context, ref, next);
      }
    });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _stageWidget(state.stage),
    );
  }

  Future<void> _showPayWall(BuildContext context, WidgetRef ref, PolishState state) async {
    final sceneId = state.inputMode == InputMode.upload ? 'scene_polish_long' : 'scene_polish';
    try {
      final scenes = await ref.read(sceneListProvider.future);
      final scene = scenes.firstWhere(
        (s) => s.sceneId == sceneId,
        orElse: () => scenes.first,
      );
      if (context.mounted) {
        PayWall.show(
          context,
          scene: scene,
          onPaid: () => ref.read(polishProvider.notifier).startPolish(),
        );
      }
    } catch (e) {
      // 场景加载失败时回退到订阅页
      if (context.mounted) context.push('/subscription');
    }
  }

  Widget _stageWidget(PolishStage stage) {
    switch (stage) {
      case PolishStage.input:
        return const _InputStage(key: ValueKey('input'));
      case PolishStage.reviewing:
        return const _ReviewingStage(key: ValueKey('reviewing'));
      case PolishStage.review:
        return const _ReviewStage(key: ValueKey('review'));
    }
  }
}

// ═══════════════════════════════════════════════════════
// Stage 1: Input
// ═══════════════════════════════════════════════════════

class _InputStage extends ConsumerStatefulWidget {
  const _InputStage({super.key});

  @override
  ConsumerState<_InputStage> createState() => _InputStageState();
}

class _InputStageState extends ConsumerState<_InputStage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(polishProvider);
    final notifier = ref.read(polishProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const FeatureHeader(
            color: AppColors.success,
            title: '文档精修',
            subtitle: 'AI 校审建议，逐条确认，专业排版导出',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 输入模式切换
                  _InputModeTabs(
                    mode: state.inputMode,
                    onChanged: (m) => notifier.setInputMode(m),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 输入区域
                  if (state.inputMode == InputMode.upload)
                    _UploadZone(
                      fileName: state.fileName,
                      fileSize: state.fileSize,
                      onPick: () => _pickFile(context, notifier),
                    )
                  else
                    _TextInputArea(
                      text: state.textContent ?? '',
                      onChanged: (t) => notifier.setTextContent(t),
                    ),
                  const SizedBox(height: AppSpacing.xl),

                  // 文档类型
                  _SectionLabel('文档类型'),
                  const SizedBox(height: AppSpacing.sm),
                  _DocTypePills(
                    selected: state.docType,
                    onChanged: (t) => notifier.setDocType(t),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 润色强度
                  _SectionLabel('润色强度'),
                  const SizedBox(height: AppSpacing.sm),
                  _LevelSelector(
                    selected: state.level,
                    onChanged: (l) => notifier.setLevel(l),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  // 开始按钮
                  _StartButton(
                    enabled: !state.isProcessing,
                    onPressed: () => notifier.startPolish(),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ErrorMessage(message: state.errorMessage!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile(BuildContext context, PolishNotifier notifier) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'txt', 'md'],
    );
    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      notifier.setFile(file.name, file.path, file.size);
    }
  }
}

// ═══════════════════════════════════════════════════════
// Stage 2: Reviewing (进度)
// ═══════════════════════════════════════════════════════

class _ReviewingStage extends ConsumerStatefulWidget {
  const _ReviewingStage({super.key});

  @override
  ConsumerState<_ReviewingStage> createState() => _ReviewingStageState();
}

class _ReviewingStageState extends ConsumerState<_ReviewingStage> {
  final ScrollController _outputScrollController = ScrollController();

  @override
  void dispose() {
    _outputScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(polishProvider);

    // agentOutput 变化时自动滚动到底部
    ref.listen<PolishState>(polishProvider, (prev, next) {
      if (prev?.agentOutput != next.agentOutput && next.agentOutput.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_outputScrollController.hasClients) {
            _outputScrollController.animateTo(
              _outputScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const FeatureHeader(
            color: AppColors.success,
            title: '正在审阅',
            subtitle: 'AI 正在分析您的文档，请稍候...',
            showBackButton: true,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  // 进度条
                  _ProgressIndicator(
                    progress: state.progress,
                    message: state.progressMsg,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // AI 审阅过程
                  if (state.agentOutput.isNotEmpty) ...[
                    _SectionLabel('AI 审阅过程'),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Builder(builder: (context) {
                        final lines = state.agentOutput.split('\n');
                        return ListView.builder(
                          controller: _outputScrollController,
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: lines.length,
                          itemBuilder: (_, i) {
                            final line = lines[i];
                            final isLatest = i == lines.length - 1;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '> ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: AppColors.success.withValues(alpha: 0.6),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: isLatest
                                          ? AppColors.success
                                          : AppColors.textMuted.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                                if (isLatest) ...[
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 8,
                                    height: 8,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: AppColors.success.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // 章节大纲（大文档）
                  if (state.outline.isNotEmpty) ...[
                    _SectionLabel('章节进度'),
                    const SizedBox(height: AppSpacing.sm),
                    _OutlineList(outline: state.outline),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // 已收集的建议
                  if (state.suggestions.isNotEmpty) ...[
                    Row(
                      children: [
                        _SectionLabel('已发现 ${state.suggestions.length} 条建议'),
                        const Spacer(),
                        Text(
                          '实时更新中...',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: _SuggestionPreviewList(
                        suggestions: state.suggestions.take(10).toList(),
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Stage 3: Review (核心审阅)
// ═══════════════════════════════════════════════════════

class _ReviewStage extends ConsumerStatefulWidget {
  const _ReviewStage({super.key});

  @override
  ConsumerState<_ReviewStage> createState() => _ReviewStageState();
}

class _ReviewStageState extends ConsumerState<_ReviewStage> {
  final ScrollController _previewScrollController = ScrollController();
  static const double _wideBreakpoint = 600;

  @override
  void dispose() {
    _previewScrollController.dispose();
    super.dispose();
  }

  void _scrollToSuggestionParagraph(int? paragraphIndex) {
    if (paragraphIndex == null || !_previewScrollController.hasClients) return;
    final targetOffset = paragraphIndex * 60.0;
    final viewport = _previewScrollController.position.viewportDimension;
    // 将目标段落定位到视口中央
    final centered = targetOffset - (viewport / 2) + 30;
    _previewScrollController.animateTo(
      centered.clamp(0.0, _previewScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPreview = ref.watch(polishProvider.select((s) => s.currentSuggestionIndex >= 0));
    final stats = ref.watch(polishProvider.select((s) => (
      s.totalSuggestions, s.acceptedCount, s.rejectedCount, s.pendingCount,
    )));
    final notifier = ref.read(polishProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          FeatureHeader(
            color: AppColors.success,
            title: '审阅结果',
            subtitle: '共 ${stats.$1} 条建议 | '
                '已采纳 ${stats.$2} | '
                '已拒绝 ${stats.$3} | '
                '待审阅 ${stats.$4}',
            showBackButton: true,
            onBack: () => notifier.goBackToInput(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= _wideBreakpoint;
                return isWide
                    ? _buildWideLayout(showPreview)
                    : _buildNarrowLayout(showPreview);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(bool showPreview) {
    return Row(
      children: [
        // 左：文档预览（始终占位，无选中时显示提示）
        Expanded(
          flex: 6,
          child: showPreview
              ? _buildPreviewWithClose()
              : Center(
                  child: Text(
                    '点击右侧建议条目预览文档',
                    style: AppTypography.body.copyWith(color: AppColors.textMuted),
                  ),
                ),
        ),
        // 右：建议面板（始终存在，不重建）
        Expanded(
          flex: 4,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(left: BorderSide(color: AppColors.border)),
            ),
            child: _ReviewSuggestionPanel(scrollToParagraph: _scrollToSuggestionParagraph),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(bool showPreview) {
    return Column(
      children: [
        // 建议面板 — 始终是同一个实例，不因预览开关重建
        Expanded(
          flex: showPreview ? 45 : 1,
          child: _ReviewSuggestionPanel(scrollToParagraph: _scrollToSuggestionParagraph),
        ),
        if (showPreview)
          Expanded(
            flex: 55,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: _buildPreviewWithClose(),
            ),
          ),
      ],
    );
  }

  Widget _buildHintBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        children: [
          Icon(Icons.touch_app, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Text(
            '点击建议条目可预览文档中对应位置',
            style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewWithClose() {
    final notifier = ref.read(polishProvider.notifier);
    // 仅订阅预览所需数据
    final currentIndex = ref.watch(polishProvider.select((s) => s.currentSuggestionIndex));
    final previewData = ref.watch(polishProvider.select((s) => (
      s.originalParagraphs,
      s.suggestions,
    )));

    return Column(
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.find_in_page, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('文档定位', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
              GestureDetector(
                onTap: () => notifier.setCurrentSuggestionIndex(-1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 12, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text('关闭预览', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _DocumentPreview(
            scrollController: _previewScrollController,
            paragraphs: previewData.$1,
            suggestions: previewData.$2,
            currentSuggestionIndex: currentIndex >= 0 ? currentIndex : null,
          ),
        ),
      ],
    );
  }
}

/// 独立的建议面板组件 — 精细订阅，避免整体重建
class _ReviewSuggestionPanel extends ConsumerStatefulWidget {
  final void Function(int? paragraphIndex) scrollToParagraph;
  const _ReviewSuggestionPanel({required this.scrollToParagraph});

  @override
  ConsumerState<_ReviewSuggestionPanel> createState() => _ReviewSuggestionPanelState();
}

class _ReviewSuggestionPanelState extends ConsumerState<_ReviewSuggestionPanel> {
  final ScrollController _scrollController = ScrollController(keepScrollOffset: true);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterState = ref.watch(polishProvider.select((s) => s.filterStatus));
    final filtered = ref.watch(polishProvider.select((s) => s.filteredSuggestions));
    final allProcessed = ref.watch(polishProvider.select((s) => s.pendingCount == 0 && s.totalSuggestions > 0));
    final currentIdx = ref.watch(polishProvider.select((s) => s.currentSuggestionIndex));
    final notifier = ref.read(polishProvider.notifier);

    return Column(
      children: [
        _FilterBar(
          filterStatus: filterState,
          onStatusChanged: (s) => notifier.setFilterStatus(s),
          onAcceptAll: () => notifier.acceptAll(),
          onRejectAll: () => notifier.rejectAll(),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('暂无匹配建议', style: AppTypography.caption))
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final suggestion = filtered[i];
                    final suggestionIdx = ref.read(polishProvider).suggestions.indexOf(suggestion);
                    return _SuggestionCard(
                      suggestion: suggestion,
                      isSelected: suggestionIdx == currentIdx,
                      onAccept: () => notifier.acceptSuggestion(suggestion.id),
                      onReject: () => notifier.rejectSuggestion(suggestion.id),
                      onTap: () {
                        notifier.setCurrentSuggestionIndex(suggestionIdx);
                        widget.scrollToParagraph(suggestion.paragraphIndex);
                      },
                    );
                  },
                ),
        ),
        _BottomBar(
          allProcessed: allProcessed,
          onExport: (mode) => _doExport(context, notifier, mode),
        ),
      ],
    );
  }

  Future<void> _doExport(
    BuildContext context,
    PolishNotifier notifier,
    ExportMode mode,
  ) async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(content: Text('正在导出...'), duration: Duration(seconds: 1)),
    );
    try {
      await notifier.exportDocument(mode);
      if (context.mounted) {
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(
          const SnackBar(
            content: Text('文档已导出并打开'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════
// 组件: Input Stage
// ═══════════════════════════════════════════════════════

class _InputModeTabs extends StatelessWidget {
  final InputMode mode;
  final ValueChanged<InputMode> onChanged;
  const _InputModeTabs({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeChip(label: '粘贴文本', selected: mode == InputMode.text, onTap: () => onChanged(InputMode.text)),
        const SizedBox(width: AppSpacing.sm),
        _ModeChip(label: '上传文件', selected: mode == InputMode.upload, onTap: () => onChanged(InputMode.upload)),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.successBg : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.success : AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.success : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _UploadZone extends StatelessWidget {
  final String? fileName;
  final int? fileSize;
  final VoidCallback onPick;
  const _UploadZone({this.fileName, this.fileSize, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Center(
          child: fileName != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined, size: 36, color: AppColors.success),
                    const SizedBox(height: AppSpacing.sm),
                    Text(fileName!, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                    if (fileSize != null)
                      Text(
                        '${(fileSize! / 1024).toStringAsFixed(1)} KB',
                        style: AppTypography.small.copyWith(color: AppColors.textMuted),
                      ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 36, color: AppColors.textMuted),
                    const SizedBox(height: AppSpacing.sm),
                    Text('点击上传 .docx / .txt / .md 文件', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TextInputArea extends StatelessWidget {
  final String text;
  final ValueChanged<String> onChanged;
  const _TextInputArea({required this.text, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        maxLines: 12,
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: '请粘贴需要审阅的文本内容...',
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(AppSpacing.lg),
        ),
      ),
    );
  }
}

class _DocTypePills extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _DocTypePills({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: DocTypePill.defaults.map((pill) {
          final isSelected = selected == pill.label;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => onChanged(pill.label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryBg : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                ),
                child: Text(
                  pill.label,
                  style: AppTypography.small.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LevelSelector extends StatelessWidget {
  final PolishLevel selected;
  final ValueChanged<PolishLevel> onChanged;
  const _LevelSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: PolishLevel.values.map((level) {
        final isSelected = selected == level;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(level),
            child: Container(
              margin: const EdgeInsets.only(right: AppSpacing.md),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.successBg : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: isSelected ? AppColors.success : AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    level.label,
                    style: AppTypography.body.copyWith(
                      color: isSelected ? AppColors.success : AppColors.text,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level.description,
                    style: AppTypography.micro.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StartButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _StartButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          disabledBackgroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        child: Text(
          '开始审阅',
          style: AppTypography.button.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 组件: Reviewing Stage
// ═══════════════════════════════════════════════════════

class _ProgressIndicator extends StatelessWidget {
  final double progress;
  final String message;
  const _ProgressIndicator({required this.progress, required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.borderLight,
                  color: AppColors.success,
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${(progress * 100).toInt()}%',
              style: AppTypography.caption.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(message, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _OutlineList extends StatelessWidget {
  final List<OutlineItem> outline;
  const _OutlineList({required this.outline});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: outline.map((item) {
        final statusIcon = item.status == 'reviewed'
            ? const Icon(Icons.check_circle, size: 18, color: AppColors.success)
            : item.status == 'reviewing'
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success),
                  )
                : const Icon(Icons.circle_outlined, size: 18, color: AppColors.textMuted);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              statusIcon,
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.title,
                  style: AppTypography.caption.copyWith(
                    color: item.status == 'reviewed' ? AppColors.text : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SuggestionPreviewList extends StatelessWidget {
  final List<PolishSuggestion> suggestions;
  const _SuggestionPreviewList({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (_, i) {
        final s = suggestions[i];
        return ListTile(
          dense: true,
          leading: _CategoryIcon(category: s.category),
          title: Text(
            s.original,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption,
          ),
          subtitle: Text(
            s.suggested,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.small.copyWith(color: AppColors.success),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// 组件: Review Stage
// ═══════════════════════════════════════════════════════

class _DocumentPreview extends StatelessWidget {
  final List<SourceParagraph> paragraphs;
  final List<PolishSuggestion> suggestions;
  final int? currentSuggestionIndex;
  final ScrollController? scrollController;
  const _DocumentPreview({
    required this.paragraphs,
    required this.suggestions,
    this.currentSuggestionIndex,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (paragraphs.isEmpty) {
      return const Center(
        child: Text('暂无文档预览', style: AppTypography.body),
      );
    }

    final acceptedMap = <int, List<PolishSuggestion>>{};
    final pendingMap = <int, List<PolishSuggestion>>{};
    final rejectedMap = <int, List<PolishSuggestion>>{};

    for (final s in suggestions) {
      if (s.status == 'accepted') {
        acceptedMap.putIfAbsent(s.paragraphIndex, () => []).add(s);
      } else if (s.status == 'pending') {
        pendingMap.putIfAbsent(s.paragraphIndex, () => []).add(s);
      } else if (s.status == 'rejected') {
        rejectedMap.putIfAbsent(s.paragraphIndex, () => []).add(s);
      }
    }

    final currentSuggestion =
        currentSuggestionIndex != null && currentSuggestionIndex! < suggestions.length
            ? suggestions[currentSuggestionIndex!]
            : null;

    return Container(
      color: AppColors.surface,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: paragraphs.length,
        itemBuilder: (_, i) {
          final para = paragraphs[i];
          final isCurrentFocus = currentSuggestion?.paragraphIndex == i;
          final hasPending = pendingMap.containsKey(i);

          Color bgColor = Colors.transparent;
          if (isCurrentFocus) {
            bgColor = const Color(0x1A2563EB);
          } else if (hasPending) {
            bgColor = const Color(0x0A2563EB);
          }

          final acceptedInThisPara = acceptedMap[i] ?? [];
          final rejectedInThisPara = rejectedMap[i] ?? [];
          final pendingInThisPara = pendingMap[i] ?? [];

          String text = para.text;
          for (final s in acceptedInThisPara) {
            text = text.replaceFirst(s.original, s.suggested);
          }

          final spans = _buildParagraphSpans(
            text,
            pendingInThisPara,
            rejectedInThisPara,
            isCurrentFocus ? currentSuggestion : null,
          );

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: RichText(
              text: TextSpan(
                style: AppTypography.body.copyWith(height: 1.7, color: AppColors.text),
                children: spans,
              ),
            ),
          );
        },
      ),
    );
  }

  List<TextSpan> _buildParagraphSpans(
    String text,
    List<PolishSuggestion> pending,
    List<PolishSuggestion> rejected,
    PolishSuggestion? activeSuggestion,
  ) {
    if (pending.isEmpty && rejected.isEmpty) {
      return [TextSpan(text: text)];
    }

    final marks = <_TextMark>[];
    for (final s in rejected) {
      final idx = text.indexOf(s.original);
      if (idx >= 0) marks.add(_TextMark(idx, idx + s.original.length, 'rejected'));
    }
    for (final s in pending) {
      final idx = text.indexOf(s.original);
      if (idx >= 0) {
        final isActive = activeSuggestion != null && s.id == activeSuggestion.id;
        marks.add(_TextMark(idx, idx + s.original.length, isActive ? 'active' : 'pending'));
      }
    }
    if (marks.isEmpty) return [TextSpan(text: text)];

    marks.sort((a, b) => a.start.compareTo(b.start));

    final spans = <TextSpan>[];
    int pos = 0;
    for (final m in marks) {
      if (m.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, m.start)));
      }
      final segment = text.substring(m.start, m.end);
      if (m.type == 'rejected') {
        spans.add(TextSpan(
          text: segment,
          style: const TextStyle(
            decoration: TextDecoration.lineThrough,
            color: AppColors.textMuted,
          ),
        ));
      } else if (m.type == 'active') {
        spans.add(TextSpan(
          text: segment,
          style: const TextStyle(
            backgroundColor: Color(0x55FF6B00),
            color: Color(0xFFD45500),
            fontWeight: FontWeight.w600,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: segment,
          style: const TextStyle(
            backgroundColor: Color(0x332563EB),
            color: AppColors.primary,
          ),
        ));
      }
      pos = m.end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos)));
    }
    return spans;
  }
}

class _TextMark {
  final int start;
  final int end;
  final String type;
  const _TextMark(this.start, this.end, this.type);
}

class _BottomBar extends StatelessWidget {
  final bool allProcessed;
  final void Function(ExportMode) onExport;

  const _BottomBar({
    required this.allProcessed,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    if (!allProcessed) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ExportButton(
              label: '导出文档',
              icon: Icons.auto_fix_high,
              onTap: () => onExport(ExportMode.professional),
              primary: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ExportButton(
              label: '审阅报告',
              icon: Icons.assessment,
              onTap: () => onExport(ExportMode.report),
              primary: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String filterStatus;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onAcceptAll;
  final VoidCallback onRejectAll;

  const _FilterBar({
    required this.filterStatus,
    required this.onStatusChanged,
    required this.onAcceptAll,
    required this.onRejectAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _FilterChip(
            label: '待处理',
            selected: filterStatus == 'pending',
            onTap: () => onStatusChanged('pending'),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: '已处理',
            selected: filterStatus == 'processed',
            onTap: () => onStatusChanged('processed'),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: '全部',
            selected: filterStatus == 'all',
            onTap: () => onStatusChanged('all'),
          ),
          const Spacer(),
          _SmallButton(label: '全部采纳', onTap: onAcceptAll, color: AppColors.success),
          const SizedBox(width: 6),
          _SmallButton(label: '全部拒绝', onTap: onRejectAll, color: AppColors.error),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.micro.copyWith(
            color: selected ? AppColors.primary : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final PolishSuggestion suggestion;
  final bool isSelected;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.suggestion,
    this.isSelected = false,
    required this.onAccept,
    required this.onReject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = suggestion.status == 'pending';
    final isAccepted = suggestion.status == 'accepted';
    final isRejected = suggestion.status == 'rejected';

    Color borderColor = AppColors.border;
    if (isAccepted) borderColor = AppColors.success;
    if (isRejected) borderColor = AppColors.textMuted;
    if (suggestion.status == 'conflict') borderColor = AppColors.warn;

    final bgColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.06)
        : AppColors.surface;
    final effectiveBorder = isSelected
        ? Border.all(color: AppColors.primary, width: 2)
        : Border.all(color: borderColor, width: isPending ? 1.5 : 1);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: effectiveBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标签行：类型 + 严重程度 + 操作按钮
            Row(
              children: [
                _CategoryIcon(category: suggestion.category),
                const SizedBox(width: 6),
                _SeverityBadge(severity: suggestion.severity),
                const Spacer(),
                if (isPending) ...[
                  GestureDetector(
                    onTap: onReject,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text('拒绝', style: AppTypography.micro.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onAccept,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 12, color: AppColors.success),
                          const SizedBox(width: 3),
                          Text('采纳', style: AppTypography.micro.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
                if (isAccepted)
                  const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                if (isRejected)
                  const Icon(Icons.cancel, size: 16, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: 6),

            // 原文
            Text(
              '原文: ${suggestion.original}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                decoration: isRejected ? TextDecoration.lineThrough : null,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 3),

            // 建议
            Text(
              '建议: ${suggestion.suggested}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: AppColors.success),
            ),

            // 原因
            if (suggestion.reason.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                suggestion.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.small.copyWith(color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final String category;
  const _CategoryIcon({required this.category});

  @override
  Widget build(BuildContext context) {
    final config = {
      'grammar': (Icons.spellcheck, AppColors.error),
      'style': (Icons.brush, AppColors.purple),
      'terminology': (Icons.menu_book, AppColors.cta),
      'logic': (Icons.psychology, AppColors.primary),
      'format': (Icons.format_align_left, AppColors.info),
    };
    final (icon, color) = config[category] ?? (Icons.edit_note, AppColors.textMuted);
    return Icon(icon, size: 14, color: color);
  }
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final config = {
      'error': ('错误', AppColors.error),
      'warning': ('警告', AppColors.warn),
      'suggestion': ('建议', AppColors.info),
    };
    final (label, color) = config[severity] ?? ('建议', AppColors.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: AppTypography.micro.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  const _SmallButton({required this.label, this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppTypography.small.copyWith(
          color: onTap != null ? color : AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  const _ExportButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: primary ? AppColors.success : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: primary ? AppColors.success : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: primary ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.small.copyWith(
                  color: primary ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// 共享组件
// ═══════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.h3);
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;
  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: AppTypography.caption.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
