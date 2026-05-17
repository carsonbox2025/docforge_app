import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/translate_models.dart';
import '../../domain/providers/translate_provider.dart';
import '../../../../shared/widgets/feature_header.dart';

class TranslatePage extends ConsumerWidget {
  const TranslatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(stage: state.stage),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: state.stage == TranslateStage.input
                    ? const _InputStage(key: ValueKey('input'))
                    : const _ResultStage(key: ValueKey('result')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Header ====================

class _Header extends StatelessWidget {
  final TranslateStage stage;

  const _Header({required this.stage});

  @override
  Widget build(BuildContext context) {
    final isInput = stage == TranslateStage.input;

    return FeatureHeader(
      color: isInput ? AppColors.cta : AppColors.success,
      title: isInput ? '智能翻译' : '翻译完成',
      subtitle: isInput
          ? '文本翻译与整篇文档翻译，术语一致性保障'
          : '技术开发合同 · 中文 → English · 12 页',
    );
  }
}

// ==================== Input Stage ====================

class _InputStage extends ConsumerWidget {
  const _InputStage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const _ModeTabs(),
          const SizedBox(height: 12),
          if (state.mode == TranslateMode.text)
            const _TextInputMode()
          else
            const _DocumentInputMode(),
          const _TranslateModeSelector(),
          const _GlossarySection(),
          const SizedBox(height: 12),
          const _TranslateButton(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ==================== Mode Tabs ====================

class _ModeTabs extends ConsumerWidget {
  const _ModeTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            _ModeTabItem(
              icon: Icons.description_outlined,
              label: '文本翻译',
              isActive: state.mode == TranslateMode.text,
              onTap: () => ref
                  .read(translateProvider.notifier)
                  .setMode(TranslateMode.text),
            ),
            _ModeTabItem(
              icon: Icons.upload_file_outlined,
              label: '文档翻译',
              isActive: state.mode == TranslateMode.document,
              onTap: () => ref
                  .read(translateProvider.notifier)
                  .setMode(TranslateMode.document),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeTabItem({
    required this.icon,
    required this.label,
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.cta : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: isActive ? Colors.white : AppColors.textSecondary),
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

// ==================== Language Selector ====================

class _LangSelector extends ConsumerWidget {
  const _LangSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);
    final notifier = ref.read(translateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Source language (active)
            Expanded(
              child: GestureDetector(
                onTap: () => _showLangPicker(context, ref, isSource: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.ctaBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    state.sourceLang.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cta,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Swap button (orange circle)
            GestureDetector(
              onTap: () => notifier.swapLanguages(),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.cta,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.swap_horiz,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Target language
            Expanded(
              child: GestureDetector(
                onTap: () => _showLangPicker(context, ref, isSource: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    state.targetLang.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLangPicker(BuildContext context, WidgetRef ref,
      {required bool isSource}) {
    final notifier = ref.read(translateProvider.notifier);
    final state = ref.read(translateProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '选择语言',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...Language.all.map((lang) {
                  final current =
                      isSource ? state.sourceLang : state.targetLang;
                  final isSelected = current.code == lang.code;
                  return ListTile(
                    title: Text(
                      lang.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.cta : AppColors.text,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.cta)
                        : null,
                    onTap: () {
                      if (isSource) {
                        notifier.setSourceLang(lang);
                      } else {
                        notifier.setTargetLang(lang);
                      }
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== Text Input Mode ====================

class _TextInputMode extends ConsumerStatefulWidget {
  const _TextInputMode();

  @override
  ConsumerState<_TextInputMode> createState() => _TextInputModeState();
}

class _TextInputModeState extends ConsumerState<_TextInputMode> {
  late TextEditingController _sourceController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(translateProvider);
    _sourceController = TextEditingController(text: state.inputText);
  }

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(translateProvider);
    final notifier = ref.read(translateProvider.notifier);

    return Column(
      children: [
        const _LangSelector(),
        // Source input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.public, size: 14, color: AppColors.cta),
                  SizedBox(width: 4),
                  Text(
                    '原文',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: TextField(
                  controller: _sourceController,
                  onChanged: (v) => notifier.setInputText(v),
                  maxLines: 5,
                  minLines: 4,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.text,
                  ),
                  decoration: InputDecoration(
                    hintText: '输入或粘贴要翻译的文本...',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(
                          color: AppColors.cta, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Target output
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.code, size: 14, color: AppColors.success),
                  SizedBox(width: 4),
                  Text(
                    '译文',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 100),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: const Color(0x3310B981),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  state.translatedText.isNotEmpty
                      ? state.translatedText
                      : '翻译结果将在此处显示',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: state.translatedText.isNotEmpty
                        ? AppColors.text
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ==================== Document Input Mode ====================

class _DocumentInputMode extends ConsumerWidget {
  const _DocumentInputMode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);
    final notifier = ref.read(translateProvider.notifier);
    final hasFile = state.documentFilePath != null;

    return Column(
      children: [
        const _LangSelector(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['docx', 'pdf', 'txt', 'md'],
                );
                if (result != null && result.files.single.path != null) {
                  final file = result.files.single;
                  notifier.setDocumentFile(file.path!, file.name);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: hasFile ? AppColors.cta : AppColors.border,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: hasFile ? AppColors.ctaBg : AppColors.surface,
                ),
                child: hasFile
                    ? Column(
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 32, color: AppColors.cta),
                          const SizedBox(height: 8),
                          Text(
                            state.documentFileName ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.cta,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '点击重新选择文件',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      )
                    : const Column(
                        children: [
                          Icon(Icons.upload_file_outlined,
                              size: 32, color: AppColors.textMuted),
                          SizedBox(height: 8),
                          Text(
                            '上传文档翻译',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '支持 .docx .pdf .txt .md，最大 50MB\n自动保留原文格式和排版',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== Glossary Section ====================

class _GlossarySection extends ConsumerWidget {
  const _GlossarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '术语表',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: navigate to glossary editor
                },
                child: const Text(
                  '编辑',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.cta,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...state.glossary.map((term) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        term.source,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        term.target,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cta,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

// ==================== Translate Button ====================

class _TranslateButton extends ConsumerWidget {
  const _TranslateButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);
    final notifier = ref.read(translateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: state.isLoading ? null : () => notifier.translate(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cta,
            disabledBackgroundColor: AppColors.cta.withValues(alpha: 0.6),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: state.isLoading
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
                    Icon(Icons.public, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      '翻译并导出',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ==================== Result Stage ====================

class _ResultStage extends ConsumerWidget {
  const _ResultStage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);
    final notifier = ref.read(translateProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepIndicator(),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '预览确认 · 选择导出格式',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ),
          // Preview header
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '翻译预览',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 14, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      '术语一致 ✓',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Preview content card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < state.previewResults.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(
                            height: 1,
                            color: AppColors.borderLight,
                          ),
                        ),
                      _PreviewParagraph(result: state.previewResults[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Export format title
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '选择导出格式',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.success, width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined, size: 20, color: AppColors.success),
                  SizedBox(width: 8),
                  Text('Word 文档 (.docx)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () =>
                          notifier.goToStage(TranslateStage.input),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        backgroundColor: AppColors.surface,
                      ),
                      child: const Text(
                        '重新翻译',
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
                    child: ElevatedButton(
                      onPressed:
                          state.isLoading ? null : () => notifier.export(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cta,
                        disabledBackgroundColor:
                            AppColors.cta.withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: state.isLoading
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
                                Icon(Icons.download,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  '导出文档',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
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
    );
  }
}

// ==================== Step Indicator ====================

class _StepIndicator extends StatelessWidget {
  const _StepIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
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
              color: AppColors.cta,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Preview Paragraph ====================

class _PreviewParagraph extends StatelessWidget {
  final TranslateResult result;

  const _PreviewParagraph({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.paragraphTitle ?? '',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.cta,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          result.translatedText,
          style: const TextStyle(
            fontSize: 13,
            height: 1.7,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

// ==================== Export Format Grid ====================

class _ExportFormatGrid extends ConsumerWidget {
  const _ExportFormatGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);
    final notifier = ref.read(translateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ExportFormatOption.all.map((opt) {
          final isSelected = state.selectedFormat == opt.format;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => notifier.setExportFormat(opt.format),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.ctaBg : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isSelected ? AppColors.cta : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _iconBg(opt.format),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          _iconData(opt.format),
                          size: 20,
                          color: _iconColor(opt.format),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        opt.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        opt.extension,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _iconBg(ExportFormat format) {
    switch (format) {
      case ExportFormat.docx:
        return AppColors.successBg;
      case ExportFormat.pdf:
        return AppColors.errorBg;
      case ExportFormat.html:
        return AppColors.ctaBg;
    }
  }

  Color _iconColor(ExportFormat format) {
    switch (format) {
      case ExportFormat.docx:
        return AppColors.success;
      case ExportFormat.pdf:
        return AppColors.error;
      case ExportFormat.html:
        return AppColors.cta;
    }
  }

  IconData _iconData(ExportFormat format) {
    switch (format) {
      case ExportFormat.docx:
        return Icons.description_outlined;
      case ExportFormat.pdf:
        return Icons.picture_as_pdf_outlined;
      case ExportFormat.html:
        return Icons.code;
    }
  }
}

// ==================== Translate Mode Selector ====================

class _TranslateModeSelector extends ConsumerWidget {
  const _TranslateModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);
    final notifier = ref.read(translateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const Text(
            '翻译模式',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceHover,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _TranslateModeChip(
                    label: '快速翻译',
                    icon: Icons.bolt,
                    isActive: state.genMode == 'quick',
                    onTap: () => notifier.setGenMode('quick'),
                  ),
                  _TranslateModeChip(
                    label: '专业翻译',
                    icon: Icons.auto_awesome,
                    isActive: state.genMode == 'professional',
                    onTap: () => notifier.setGenMode('professional'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslateModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TranslateModeChip({
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
              Icon(icon, size: 14, color: isActive ? AppColors.cta : AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.cta : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
