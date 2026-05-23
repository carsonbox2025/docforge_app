import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/translate_models.dart';

class TranslateProgressWidget extends StatelessWidget {
  final double progress;
  final String message;
  final List<ExtractedTerm> extractedTerms;
  final List<ParagraphProgress> paragraphProgress;
  final String? detectedDocType;
  final Future<void> Function() onCancel;

  const TranslateProgressWidget({
    super.key,
    required this.progress,
    required this.message,
    this.extractedTerms = const [],
    this.paragraphProgress = const [],
    this.detectedDocType,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TranslationProgressBar(
            progress: progress,
            message: message,
          ),
          const SizedBox(height: 12),
          if (detectedDocType != null)
            _DocTypeIndicator(detectedDocType: detectedDocType!),
          if (extractedTerms.isNotEmpty) ...[
            const SizedBox(height: 8),
            _TermExtractionIndicator(terms: extractedTerms),
          ],
          const SizedBox(height: 12),
          if (paragraphProgress.isNotEmpty)
            _ParagraphProgressList(progressList: paragraphProgress),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text(
                  '取消翻译',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TranslationProgressBar extends StatelessWidget {
  final double progress;
  final String message;

  const _TranslationProgressBar({required this.progress, required this.message});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              message.isNotEmpty ? message : '准备中...',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.cta,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.borderLight,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cta),
          ),
        ),
      ],
    );
  }
}

class _DocTypeIndicator extends StatelessWidget {
  final String detectedDocType;

  const _DocTypeIndicator({required this.detectedDocType});

  @override
  Widget build(BuildContext context) {
    const labelMap = {
      'contract': '合同',
      'official': '公文',
      'thesis': '论文',
      'generic': '通用',
    };
    final label = labelMap[detectedDocType] ?? '通用';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.ctaBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.article_outlined, size: 14, color: AppColors.cta),
          const SizedBox(width: 4),
          Text(
            '检测为：$label',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.cta,
            ),
          ),
        ],
      ),
    );
  }
}

class _TermExtractionIndicator extends StatelessWidget {
  final List<ExtractedTerm> terms;

  const _TermExtractionIndicator({required this.terms});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: const Color(0x3310B981)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_outlined, size: 14, color: AppColors.success),
              const SizedBox(width: 4),
              Text(
                '已识别 ${terms.length} 个专业术语',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          if (terms.length <= 5) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: terms.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  '${t.source} → ${t.target}',
                  style: const TextStyle(fontSize: 11, color: AppColors.text),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParagraphProgressList extends StatelessWidget {
  final List<ParagraphProgress> progressList;

  const _ParagraphProgressList({required this.progressList});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '段落翻译进度',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...progressList.map((p) => _ParagraphItem(progress: p)),
      ],
    );
  }
}

class _ParagraphItem extends StatelessWidget {
  final ParagraphProgress progress;

  const _ParagraphItem({required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress.isComplete) {
      return _completedItem();
    } else if (progress.translated.isNotEmpty) {
      return _activeItem();
    } else {
      return _pendingItem();
    }
  }

  Widget _completedItem() {
    final preview = progress.translated.length > 60
        ? '${progress.translated.substring(0, 60)}...'
        : progress.translated;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 ${progress.index + 1} 段',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.text, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeItem() {
    final preview = progress.translated.length > 80
        ? '${progress.translated.substring(0, 80)}...'
        : progress.translated;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.ctaBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: const Color(0x33F97316)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.cta),
                ),
                const SizedBox(width: 6),
                Text(
                  '正在翻译第 ${progress.index + 1}/${progress.total} 段',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cta,
                  ),
                ),
                const Spacer(),
                Text(
                  '${progress.translated.length} 字',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$preview▎',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.text, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingItem() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '${progress.index + 1}',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              progress.preview.isNotEmpty
                  ? '${progress.preview.substring(0, progress.preview.length > 40 ? 40 : progress.preview.length)}...'
                  : '等待翻译...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
