import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/polish_models.dart';
import '../../domain/providers/polish_provider.dart';
import '../../../../shared/widgets/feature_header.dart';

class PolishPage extends ConsumerWidget {
  const PolishPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(polishProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: state.stage == PolishStage.input
          ? const _InputStage(key: ValueKey('input'))
          : const _ResultStage(key: ValueKey('result')),
    );
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
            title: '文档精修，专业排版',
            subtitle: '上传或粘贴文本，智能润色，专业排版并导出',
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input mode tabs
                  _InputModeTabs(
                    activeMode: state.inputMode,
                    onChanged: (mode) => notifier.setInputMode(mode),
                  ),

                  // Upload zone or text input
                  state.inputMode == InputMode.upload
                      ? SizedBox(
                          width: double.infinity,
                          child: _UploadZone(
                            fileName: state.fileName,
                            onFileSelected: (name) => notifier.setFileName(name),
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: _TextInputArea(
                            onChanged: (text) => notifier.setTextContent(text),
                          ),
                        ),

                  // Document type
                  const SizedBox(height: 4),
                  const _SectionLabel('文档类型'),
                  _DocTypePills(
                    selected: state.docType,
                    onChanged: (type) => notifier.setDocType(type),
                  ),

                  // Polish level
                  const SizedBox(height: 4),
                  const _SectionLabel('润色强度'),
                  _LevelSelector(
                    selectedLevel: state.level,
                    onChanged: (level) => notifier.setLevel(level),
                  ),

                  // Mode toggle
                  const SizedBox(height: 4),
                  const _SectionLabel('润色模式'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          _PolishModeChip(
                            label: '快速润色',
                            icon: Icons.bolt,
                            isActive: state.mode == 'quick',
                            onTap: () => notifier.setMode('quick'),
                          ),
                          _PolishModeChip(
                            label: '专业精修',
                            icon: Icons.auto_awesome,
                            isActive: state.mode == 'professional',
                            onTap: () => notifier.setMode('professional'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Action button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                    child: _StartButton(
                      isLoading: state.isProcessing,
                      onPressed: () => notifier.startPolish(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// ── Input mode tabs ──

class _InputModeTabs extends StatelessWidget {
  final InputMode activeMode;
  final ValueChanged<InputMode> onChanged;

  const _InputModeTabs({
    required this.activeMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          _buildTab(
            icon: Icons.upload_outlined,
            label: '上传文档',
            mode: InputMode.upload,
          ),
          _buildTab(
            icon: Icons.description_outlined,
            label: '粘贴文本',
            mode: InputMode.text,
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required InputMode mode,
  }) {
    final isActive = activeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? AppColors.success : AppColors.surface,
            borderRadius: mode == InputMode.upload
                ? const BorderRadius.horizontal(
                    left: Radius.circular(AppRadius.md))
                : const BorderRadius.horizontal(
                    right: Radius.circular(AppRadius.md)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isActive ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Upload zone ──

class _UploadZone extends StatelessWidget {
  final String? fileName;
  final ValueChanged<String?> onFileSelected;

  const _UploadZone({
    this.fileName,
    required this.onFileSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 模拟文件选择，实际项目中使用 file_picker
        onFileSelected('技术开发合同_v1.2.docx');
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: fileName != null ? AppColors.success : AppColors.border,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: fileName != null ? AppColors.successBg : AppColors.surface,
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 36,
              color: fileName != null ? AppColors.success : AppColors.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              fileName ?? '点击上传文档',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fileName != null ? AppColors.success : AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '支持 .docx .pdf .txt .md，最大 20MB',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Text input area ──

class _TextInputArea extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _TextInputArea({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: TextField(
        maxLines: 12,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText: '粘贴需要润色的文本内容...\n\n甲方和乙方经友好协商，甲方需要给乙方付款，就智慧园区管理平台开发项目达成如下协议：',
          hintStyle: const TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
            height: 1.6,
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.success, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ── Section label ──

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Doc type pills ──

class _DocTypePills extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _DocTypePills({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: DocTypePill.defaults.map((pill) {
          final isActive = selected == pill.label;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(pill.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.success : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isActive ? AppColors.success : AppColors.border,
                    width: 1.5,
                  ),
                ),
                constraints: const BoxConstraints(minHeight: 36),
                child: Center(
                  child: Text(
                    pill.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
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

// ── Level selector ──

class _LevelSelector extends StatelessWidget {
  final PolishLevel selectedLevel;
  final ValueChanged<PolishLevel> onChanged;

  const _LevelSelector({
    required this.selectedLevel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: PolishLevel.values.map((level) {
          final isSelected = level == selectedLevel;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.successBg : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected ? AppColors.success : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      level.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.success : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level.description,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
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

// ── Start button ──

class _StartButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _StartButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.success.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note, size: 18),
                  SizedBox(width: 6),
                  Text(
                    '开始润色',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Stage 2: Result
// ═══════════════════════════════════════════════════════

class _ResultStage extends ConsumerWidget {
  const _ResultStage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(polishProvider);
    final notifier = ref.read(polishProvider.notifier);
    final result = state.result;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Green result header
          FeatureHeader(
            color: AppColors.success,
            title: '润色完成',
            subtitle: result != null
                ? '${result.title} · ${result.level.label}润色 · 修改 ${result.changeCount} 处'
                : '',
            showBackButton: true,
            onBack: () => notifier.rePolish(),
          ),

          // Steps indicator
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 32,
                  height: 2,
                  color: AppColors.success,
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, 4, AppSpacing.lg, 0),
            child: Text(
              '修订对比 · 选择导出格式',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compare header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.sm + 4, AppSpacing.lg, AppSpacing.xs),
                    child: Row(
                      children: [
                        const Text(
                          '修订对比',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const Spacer(),
                        if (result != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.successBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${result.acceptedCount} 采纳',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warnBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${result.pendingCount} 待定',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warn,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Compare card
                  _CompareCard(
                    activeTab: state.compareTab,
                    result: result,
                    streamingText: state.streamingText,
                    onTabChanged: (tab) => notifier.setCompareTab(tab),
                  ),

                  // Export section
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
                    child: Text(
                      '选择导出格式',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  _ExportFormatSelector(
                    selectedFormat: state.exportFormat,
                    onChanged: (fmt) => notifier.setExportFormat(fmt),
                  ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () => notifier.rePolish(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                                backgroundColor: AppColors.surface,
                              ),
                              child: const Text(
                                '重新润色',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () => notifier.exportResult(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text(
                                '导出文档',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compare card with tabs ──

class _CompareCard extends StatelessWidget {
  final CompareTab activeTab;
  final PolishResult? result;
  final String streamingText;
  final ValueChanged<CompareTab> onTabChanged;

  const _CompareCard({
    required this.activeTab,
    this.result,
    this.streamingText = '',
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Tabs
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: CompareTab.values.map((tab) {
                final isActive = tab == activeTab;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTabChanged(tab),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.successBg : null,
                        border: isActive
                            ? const Border(
                                bottom: BorderSide(
                                    color: AppColors.success, width: 2))
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (result == null) return const SizedBox.shrink();

    switch (activeTab) {
      case CompareTab.diff:
        return _buildDiffView();
      case CompareTab.polished:
        return _buildPolishedView();
      case CompareTab.original:
        return _buildOriginalView();
    }
  }

  Widget _buildDiffView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: result!.paragraphs.map((para) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildRichText(para.segments, isDiff: true),
        );
      }).toList(),
    );
  }

  Widget _buildPolishedView() {
    // 优先使用 polishedText 整体显示，其次从 diff 段落提取
    if (result!.polishedText != null && result!.polishedText!.isNotEmpty) {
      return Text(
        result!.polishedText!,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.8,
          color: AppColors.text,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: result!.paragraphs.map((para) {
        final text = para.segments
            .where((s) => s.type != 'delete')
            .map((s) => s.text)
            .join();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.8,
              color: AppColors.text,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOriginalView() {
    // 优先使用 originalText 整体显示，其次从 diff 段落提取
    if (result!.originalText != null && result!.originalText!.isNotEmpty) {
      return Text(
        result!.originalText!,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.8,
          color: AppColors.text,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: result!.paragraphs.map((para) {
        final text = para.segments
            .where((s) => s.type != 'insert' && s.type != 'highlight')
            .map((s) => s.text)
            .join();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.8,
              color: AppColors.text,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRichText(List<DiffSegment> segments, {bool isDiff = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.8,
          color: AppColors.text,
        ),
        children: segments.map((seg) {
          switch (seg.type) {
            case 'delete':
              return TextSpan(
                text: seg.text,
                style: TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: AppColors.error.withValues(alpha: 0.6),
                ),
              );
            case 'insert':
              return TextSpan(
                text: seg.text,
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              );
            case 'highlight':
              return TextSpan(
                text: seg.text,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                  backgroundColor: AppColors.primaryBg,
                ),
              );
            default:
              return TextSpan(text: seg.text);
          }
        }).toList(),
      ),
    );
  }
}

// ── Export format selector ──

class _ExportFormatSelector extends StatelessWidget {
  final ExportFormat selectedFormat;
  final ValueChanged<ExportFormat> onChanged;

  const _ExportFormatSelector({
    required this.selectedFormat,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: ExportFormat.values.map((fmt) {
          final isSelected = fmt == selectedFormat;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(fmt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.successBg : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected ? AppColors.success : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    _FormatIcon(format: fmt, isSelected: isSelected),
                    const SizedBox(height: 6),
                    Text(
                      fmt.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      fmt.extension,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
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

class _FormatIcon extends StatelessWidget {
  final ExportFormat format;
  final bool isSelected;
  const _FormatIcon({required this.format, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final config = _iconConfig();
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(config.icon, size: 20, color: config.iconColor),
    );
  }

  _IconConfig _iconConfig() {
    switch (format) {
      case ExportFormat.docx:
        return const _IconConfig(
          icon: Icons.description_outlined,
          bgColor: AppColors.successBg,
          iconColor: AppColors.success,
        );
      case ExportFormat.pdf:
        return const _IconConfig(
          icon: Icons.picture_as_pdf_outlined,
          bgColor: AppColors.errorBg,
          iconColor: AppColors.error,
        );
      case ExportFormat.html:
        return const _IconConfig(
          icon: Icons.code,
          bgColor: AppColors.ctaBg,
          iconColor: AppColors.cta,
        );
    }
  }
}

class _IconConfig {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  const _IconConfig({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });
}

class _PolishModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _PolishModeChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isActive ? AppColors.success : AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
