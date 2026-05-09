import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/generate_models.dart';
import '../../domain/providers/generate_provider.dart';
import '../../../../shared/widgets/feature_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stage 3: 审校/导出页
class ReviewStage extends ConsumerWidget {
  const ReviewStage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(generateProvider);
    final notifier = ref.read(generateProvider.notifier);
    final result = state.result;

    return Column(
      children: [
        // 绿色头部
        FeatureHeader(
          color: AppColors.success,
          title: '生成完成',
          subtitle: '${state.result?.title ?? ''} · 共 ${state.result?.chapterCount ?? 0} 章节 · 约 ${state.result?.wordCount ?? 0} 字',
          showBackButton: true,
          onBack: () => notifier.backToGenerating(),
        ),
        // 步骤指示器
        _buildSteps(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            '第三步 · 校审与导出',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ),
        // 内容区
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 合规校审标题
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    '合规校审',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                ),
                // 审校摘要 badges
                if (result != null) _buildSummaryBadges(result),
                // 审校发现列表
                if (result != null)
                  ...result.findings.map((f) => _buildReviewCard(f)),
                // 导出格式标题
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    '选择导出格式',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                ),
                // 导出格式选择
                _buildFormatGrid(state, notifier),
                // 操作按钮
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      // 重新编辑 (flex:1)
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => notifier.backToInput(),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.text,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
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
                      // 导出文档 (flex:2)
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => notifier.exportDocument(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
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
          _stepDot(StepStatus.done),
          _stepLine(true),
          _stepDot(StepStatus.done),
          _stepLine(true),
          _stepDot(StepStatus.active),
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

  Widget _stepLine(bool done) {
    return Container(
      width: 32,
      height: 2,
      color: done ? AppColors.success : AppColors.border,
    );
  }

  Widget _buildSummaryBadges(GenerateResult result) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 4,
        children: [
          if (result.passCount > 0) _badge('${result.passCount} 通过', AppColors.success, AppColors.successBg),
          if (result.warnCount > 0) _badge('${result.warnCount} 警告', AppColors.warn, AppColors.warnBg),
          if (result.errorCount > 0) _badge('${result.errorCount} 错误', AppColors.error, AppColors.errorBg),
          if (result.infoCount > 0) _badge('${result.infoCount} 建议', AppColors.info, AppColors.infoBg),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildReviewCard(ReviewFinding finding) {
    Color iconBg;
    IconData icon;
    switch (finding.level) {
      case ReviewLevel.pass:
        iconBg = AppColors.success;
        icon = Icons.check;
      case ReviewLevel.warn:
        iconBg = AppColors.warn;
        icon = Icons.priority_high;
      case ReviewLevel.error:
        iconBg = AppColors.error;
        icon = Icons.close;
      case ReviewLevel.info:
        iconBg = AppColors.info;
        icon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图标
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 10),
          // 文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.message,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text, height: 1.5),
                ),
                const SizedBox(height: 2),
                Text(
                  finding.location,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatGrid(GenerateState state, GenerateNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ExportFormat.values.map((fmt) {
          final isSelected = state.selectedFormat == fmt;
          Color iconBgColor;
          Color iconColor;
          switch (fmt) {
            case ExportFormat.docx:
              iconBgColor = AppColors.primaryBg;
              iconColor = AppColors.primary;
            case ExportFormat.pdf:
              iconBgColor = AppColors.errorBg;
              iconColor = AppColors.error;
            case ExportFormat.html:
              iconBgColor = AppColors.ctaBg;
              iconColor = AppColors.cta;
          }
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
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(fmt.icon, size: 20, color: iconColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fmt.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                    Text(
                      fmt.extension,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                    ),
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
