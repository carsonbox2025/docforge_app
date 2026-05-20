import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/feature_header.dart';
import '../../data/models/polish_models.dart';
import '../../domain/providers/polish_provider.dart';

class PolishPage extends ConsumerWidget {
  const PolishPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(polishProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _stageWidget(state.stage),
    );
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

class _InputStage extends ConsumerWidget {
  const _InputStage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class _ReviewingStage extends ConsumerWidget {
  const _ReviewingStage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(polishProvider);

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

class _ReviewStage extends ConsumerWidget {
  const _ReviewStage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(polishProvider);
    final notifier = ref.read(polishProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          FeatureHeader(
            color: AppColors.success,
            title: '审阅结果',
            subtitle: '共 ${state.totalSuggestions} 条建议 | '
                '已采纳 ${state.acceptedCount} | '
                '已拒绝 ${state.rejectedCount} | '
                '待审阅 ${state.pendingCount}',
            showBackButton: true,
            onBack: () => notifier.goBackToInput(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                if (totalWidth < 600) {
                  return _buildNarrowLayout(state, notifier, context);
                }
                return _buildWideLayout(state, notifier, context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(PolishState state, PolishNotifier notifier, BuildContext context) {
    final filtered = state.filteredSuggestions;
    return Row(
      children: [
        // 左侧 — 文档预览（60%）
        Expanded(
          flex: 6,
          child: _DocumentPreview(
            paragraphs: state.originalParagraphs,
            suggestions: state.suggestions,
            currentSuggestionIndex: state.currentSuggestionIndex >= 0
                ? state.currentSuggestionIndex
                : null,
          ),
        ),
        // 右侧 — 建议列表面板（40%）
        Expanded(
          flex: 4,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(left: BorderSide(color: AppColors.border)),
            ),
            child: _buildSuggestionPanel(state, notifier, context, filtered),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(PolishState state, PolishNotifier notifier, BuildContext context) {
    final filtered = state.filteredSuggestions;
    return Column(
      children: [
        // 上方 — 建议列表（主区域）
        Expanded(
          flex: 5,
          child: _buildSuggestionPanel(state, notifier, context, filtered),
        ),
        // 下方 — 文档预览（折叠预览）
        Expanded(
          flex: 3,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: _DocumentPreview(
              paragraphs: state.originalParagraphs,
              suggestions: state.suggestions,
              currentSuggestionIndex: state.currentSuggestionIndex >= 0
                  ? state.currentSuggestionIndex
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionPanel(
    PolishState state,
    PolishNotifier notifier,
    BuildContext context,
    List<PolishSuggestion> filtered,
  ) {
    return Column(
      children: [
        _StatsBar(
          total: state.totalSuggestions,
          accepted: state.acceptedCount,
          rejected: state.rejectedCount,
          pending: state.pendingCount,
        ),
        _FilterBar(
          filterCategory: state.filterCategory,
          filterSeverity: state.filterSeverity,
          onCategoryChanged: (c) => notifier.setFilterCategory(c),
          onSeverityChanged: (s) => notifier.setFilterSeverity(s),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('暂无匹配建议', style: AppTypography.caption))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final suggestion = filtered[i];
                    return _SuggestionCard(
                      suggestion: suggestion,
                      onAccept: () => notifier.acceptSuggestion(suggestion.id),
                      onReject: () => notifier.rejectSuggestion(suggestion.id),
                      onTap: () => notifier.setCurrentSuggestionIndex(
                        state.suggestions.indexOf(suggestion),
                      ),
                    );
                  },
                ),
        ),
        _BottomActionBar(
          canUndo: state.canUndo,
          canRedo: state.canRedo,
          hasSourceFile: state.sourceFileUrl != null,
          onUndo: () => notifier.undo(),
          onRedo: () => notifier.redo(),
          onAcceptAll: () => notifier.acceptAll(),
          onRejectAll: () => notifier.rejectAll(),
          onExport: (mode) => _doExport(context, notifier, mode),
          onBack: () => notifier.goBackToInput(),
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
      const SnackBar(
        content: Text('正在导出...'),
        duration: Duration(seconds: 1),
      ),
    );
    try {
      await notifier.exportDocument(mode);
      if (context.mounted) {
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(
          const SnackBar(
            content: Text('导出成功'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: AppColors.error),
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
  const _DocumentPreview({
    required this.paragraphs,
    required this.suggestions,
    this.currentSuggestionIndex,
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: paragraphs.length,
        itemBuilder: (_, i) {
          final para = paragraphs[i];
          final isCurrentFocus = currentSuggestion?.paragraphIndex == i;
          final hasPending = pendingMap.containsKey(i);

          Color bgColor = Colors.transparent;
          if (isCurrentFocus) {
            bgColor = AppColors.infoBg;
          } else if (hasPending) {
            bgColor = const Color(0x0A2563EB);
          }

          // 构建富文本：已采纳→替换文本绿色、已拒绝→原文删除线灰色、待审阅→原文蓝色
          final acceptedInThisPara = acceptedMap[i] ?? [];
          final rejectedInThisPara = rejectedMap[i] ?? [];
          final pendingInThisPara = pendingMap[i] ?? [];

          String text = para.text;
          // 先应用已采纳替换
          for (final s in acceptedInThisPara) {
            text = text.replaceFirst(s.original, s.suggested);
          }

          // 构建 TextSpan 标记 rejected 和 pending 区域
          final spans = _buildParagraphSpans(
            text,
            pendingInThisPara,
            rejectedInThisPara,
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
  ) {
    if (pending.isEmpty && rejected.isEmpty) {
      return [TextSpan(text: text)];
    }

    // 标记所有需要特殊渲染的区间
    final marks = <_TextMark>[];
    for (final s in rejected) {
      final idx = text.indexOf(s.original);
      if (idx >= 0) marks.add(_TextMark(idx, idx + s.original.length, 'rejected'));
    }
    for (final s in pending) {
      final idx = text.indexOf(s.original);
      if (idx >= 0) marks.add(_TextMark(idx, idx + s.original.length, 'pending'));
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

class _StatsBar extends StatelessWidget {
  final int total, accepted, rejected, pending;
  const _StatsBar({
    required this.total,
    required this.accepted,
    required this.rejected,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: '共 $total 条', color: AppColors.primary),
          _StatChip(label: '采纳 $accepted', color: AppColors.success),
          _StatChip(label: '拒绝 $rejected', color: AppColors.error),
          _StatChip(label: '待审 $pending', color: AppColors.warn),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.micro.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? filterCategory;
  final String? filterSeverity;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSeverityChanged;

  const _FilterBar({
    this.filterCategory,
    this.filterSeverity,
    required this.onCategoryChanged,
    required this.onSeverityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = ['grammar', 'style', 'terminology', 'logic', 'format'];
    final categoryLabels = {
      'grammar': '语法',
      'style': '风格',
      'terminology': '术语',
      'logic': '逻辑',
      'format': '格式',
    };
    final severities = ['error', 'warning', 'suggestion'];
    final severityLabels = {
      'error': '错误',
      'warning': '警告',
      'suggestion': '建议',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分类筛选
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: '全部',
                  selected: filterCategory == null,
                  onTap: () => onCategoryChanged(null),
                ),
                ...categories.map((c) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _FilterChip(
                    label: categoryLabels[c] ?? c,
                    selected: filterCategory == c,
                    onTap: () => onCategoryChanged(filterCategory == c ? null : c),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 严重程度筛选
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: '全部',
                  selected: filterSeverity == null,
                  onTap: () => onSeverityChanged(null),
                ),
                ...severities.map((s) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _FilterChip(
                    label: severityLabels[s] ?? s,
                    selected: filterSeverity == s,
                    onTap: () => onSeverityChanged(filterSeverity == s ? null : s),
                  ),
                )),
              ],
            ),
          ),
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
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.suggestion,
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor, width: isPending ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标签行
            Row(
              children: [
                _CategoryIcon(category: suggestion.category),
                const SizedBox(width: 6),
                _SeverityBadge(severity: suggestion.severity),
                const Spacer(),
                if (isAccepted)
                  const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                if (isRejected)
                  const Icon(Icons.cancel, size: 16, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

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
            const SizedBox(height: 4),

            // 建议
            Text(
              '建议: ${suggestion.suggested}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: AppColors.success),
            ),
            const SizedBox(height: 4),

            // 原因
            if (suggestion.reason.isNotEmpty)
              Text(
                suggestion.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.small.copyWith(color: AppColors.textMuted),
              ),

            // 操作按钮（仅 pending 时显示）
            if (isPending) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionButton(
                    label: '拒绝',
                    icon: Icons.close,
                    color: AppColors.textMuted,
                    onPressed: onReject,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _ActionButton(
                    label: '采纳',
                    icon: Icons.check,
                    color: AppColors.success,
                    onPressed: onAccept,
                  ),
                ],
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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.small.copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final bool hasSourceFile;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onAcceptAll;
  final VoidCallback onRejectAll;
  final void Function(ExportMode) onExport;
  final VoidCallback onBack;

  const _BottomActionBar({
    required this.canUndo,
    required this.canRedo,
    required this.hasSourceFile,
    required this.onUndo,
    required this.onRedo,
    required this.onAcceptAll,
    required this.onRejectAll,
    required this.onExport,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: AppColors.surface,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 批量操作
          Row(
            children: [
              _SmallButton(label: '全部采纳', onTap: onAcceptAll, color: AppColors.success),
              const SizedBox(width: 6),
              _SmallButton(label: '全部拒绝', onTap: onRejectAll, color: AppColors.error),
              const Spacer(),
              _SmallButton(label: '撤销', onTap: canUndo ? onUndo : null, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              _SmallButton(label: '重做', onTap: canRedo ? onRedo : null, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 导出按钮
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ExportButton(
                label: '专业排版导出',
                icon: Icons.auto_fix_high,
                onTap: () => onExport(ExportMode.professional),
                primary: true,
              ),
              if (hasSourceFile) ...[
                _ExportButton(
                  label: '原格式',
                  icon: Icons.description,
                  onTap: () => onExport(ExportMode.original),
                  primary: false,
                ),
                _ExportButton(
                  label: '修订模式(Beta)',
                  icon: Icons.track_changes,
                  onTap: () => onExport(ExportMode.trackChanges),
                  primary: false,
                ),
              ],
              _ExportButton(
                label: '审阅报告',
                icon: Icons.assessment,
                onTap: () => onExport(ExportMode.report),
                primary: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 返回
          Center(
            child: TextButton(
              onPressed: onBack,
              child: Text('返回输入', style: AppTypography.small.copyWith(color: AppColors.textMuted)),
            ),
          ),
        ],
      ),
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
