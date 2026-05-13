import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/generate/data/models/generate_models.dart';

/// 审校报告卡片 — 生成完成后展示审校结果
class ReviewReportCard extends StatelessWidget {
  final bool passed;
  final List<ReviewFinding> findings;
  final int fixedCount;

  const ReviewReportCard({
    super.key,
    required this.passed,
    required this.findings,
    this.fixedCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (passed && findings.isEmpty) {
      return _buildPassedCard();
    }

    final errors = findings.where((f) => f.level == ReviewLevel.error).toList();
    final warnings = findings.where((f) => f.level == ReviewLevel.warn).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: errors.isNotEmpty ? AppColors.error.withValues(alpha: 0.3) : AppColors.cta.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: errors.isNotEmpty
                  ? AppColors.error.withValues(alpha: 0.05)
                  : AppColors.cta.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
            ),
            child: Row(
              children: [
                Icon(
                  errors.isNotEmpty ? Icons.error_outline : Icons.warning_amber,
                  size: 20,
                  color: errors.isNotEmpty ? AppColors.error : AppColors.cta,
                ),
                const SizedBox(width: 8),
                Text(
                  errors.isNotEmpty
                      ? '审校发现 ${errors.length} 个错误'
                      : '审校发现 ${warnings.length} 个建议',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: errors.isNotEmpty ? AppColors.error : AppColors.cta,
                  ),
                ),
                if (fixedCount > 0) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '已自动修复 $fixedCount 项',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Findings list
          ...findings.take(5).map((f) => _buildFindingItem(f)),
          if (findings.length > 5)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '还有 ${findings.length - 5} 项...',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPassedCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 20, color: AppColors.success),
          const SizedBox(width: 8),
          const Text(
            '审校通过',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success),
          ),
          if (fixedCount > 0) ...[
            const Spacer(),
            Text(
              '自动修复了 $fixedCount 项问题',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFindingItem(ReviewFinding finding) {
    final isError = finding.level == ReviewLevel.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isError ? Icons.error : Icons.warning_amber,
              size: 16,
              color: isError ? AppColors.error : AppColors.cta,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              finding.message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isError ? AppColors.error : AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
