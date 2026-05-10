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

class ReviewStage extends ConsumerWidget {
  const ReviewStage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(generateProvider);
    final notifier = ref.read(generateProvider.notifier);
    final docResult = state.documentResult;

    final title = docResult?.documentTitle ?? state.selectedType.label;
    final totalWords = docResult?.chapters.fold(0, (sum, ch) => sum + ch.wordCount) ?? 0;
    final chapterCount = docResult?.chapters.length ?? state.outline.length;

    return Column(
      children: [
        FeatureHeader(
          color: AppColors.success,
          title: '生成完成',
          subtitle: '$title · 共 $chapterCount 章节 · 约 $totalWords 字',
          showBackButton: true,
          onBack: () => notifier.backToGenerating(),
        ),
        _buildSteps(),
        // 内容区
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文档预览
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text('文档预览', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                ),
                _buildDocumentPreview(state),
                // 导出格式
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text('选择导出格式', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                ),
                _buildFormatGrid(state, notifier),
                // 操作按钮
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => notifier.backToInput(),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.text,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_note, size: 16, color: AppColors.text),
                                SizedBox(width: 4),
                                Text('重新编辑', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => notifier.exportDocument(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.download, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text('导出文档', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSteps() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepDot(StepStatus.done), _stepLine(true),
          _stepDot(StepStatus.done), _stepLine(true),
          _stepDot(StepStatus.active),
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

  Widget _buildDocumentPreview(GenerateState state) {
    final docResult = state.documentResult;

    // 优先用 docResult（agent 模式完整结果）
    if (docResult != null && docResult.chapters.isNotEmpty) {
      return _buildFromDocResult(docResult);
    }

    // fallback：从 currentBlocks（流式阶段累积）
    if (state.currentBlocks.isNotEmpty) {
      return _buildFromCurrentBlocks(state);
    }

    // 旧版纯文本 fallback
    if (state.generatedContent.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          state.generatedContent,
          style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.8),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFromDocResult(DocumentResult result) {
    final List<Widget> widgets = [];

    if (result.documentTitle.isNotEmpty) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          result.documentTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text),
        ),
      ));
    }

    int mainIdx = 0;
    for (final chapter in result.chapters) {
      final parsed = parseChapterId(chapter.chapterId);
      final isSub = parsed?.sub != null;
      if (!isSub) mainIdx++;
      final chNum = isSub ? '${parsed!.top}.${parsed.sub}' : toChineseNum(mainIdx);
      final cleanTitle = stripTitleNumber(chapter.title);

      widgets.add(Padding(
        padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 16, bottom: 8),
        child: isSub
            ? Text('$chNum $cleanTitle', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text))
            : Text('$chNum、$cleanTitle', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
      ));

      int h3Counter = 0;
      int h4Counter = 0;

      for (final block in chapter.blocks) {
        if (block.type == BlockType.heading) {
          final level = block.level ?? 2;
          if (level == 3) { h3Counter++; h4Counter = 0; }
          if (level == 4) h4Counter++;
        }
        // 跳过与章节标题匹配的 heading
        if (block.type == BlockType.heading) {
          final headingText = block.text ?? '';
          if (stripHeadingNumber(headingText).trim() == cleanTitle) continue;
        }

        widgets.add(BlockRenderer(
          block: block,
          chapterIndex: mainIdx,
          h3Counter: h3Counter,
          h4Counter: h4Counter,
        ));
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets),
    );
  }

  Widget _buildFromCurrentBlocks(GenerateState state) {
    final List<Widget> widgets = [];
    int mainIdx = 0;

    for (int oi = 0; oi < state.outline.length; oi++) {
      final item = state.outline[oi];
      final blocks = state.currentBlocks[item.chapterId] ?? [];

      final parsed = parseChapterId(item.chapterId);
      final isSub = parsed?.sub != null;
      if (!isSub) mainIdx++;
      final chNum = isSub ? '${parsed!.top}.${parsed.sub}' : toChineseNum(mainIdx);
      final cleanTitle = stripTitleNumber(item.title);

      widgets.add(Padding(
        padding: EdgeInsets.only(top: oi == 0 ? 0 : 16, bottom: 8),
        child: Text('$chNum、$cleanTitle', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
      ));

      for (final block in blocks) {
        if (block.type == BlockType.heading) {
          final headingText = block.text ?? '';
          if (stripHeadingNumber(headingText).trim() == cleanTitle) continue;
        }
        widgets.add(BlockRenderer(block: block, chapterIndex: mainIdx));
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets),
    );
  }

  Widget _buildFormatGrid(GenerateState state, GenerateNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ExportFormat.values.map((fmt) {
          final isSelected = state.selectedFormat == fmt;
          final (iconBgColor, iconColor) = switch (fmt) {
            ExportFormat.docx => (AppColors.primaryBg, AppColors.primary),
            ExportFormat.pdf => (AppColors.errorBg, AppColors.error),
            ExportFormat.html => (AppColors.ctaBg, AppColors.cta),
          };
          return Expanded(
            child: GestureDetector(
              onTap: () => notifier.selectExportFormat(fmt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryBg : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: 1.5),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Icon(fmt.icon, size: 20, color: iconColor),
                    ),
                    const SizedBox(height: 6),
                    Text(fmt.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
                    Text(fmt.extension, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
