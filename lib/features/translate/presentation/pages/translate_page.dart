import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../payment/presentation/widgets/pay_wall.dart';
import '../../../scene/domain/providers/scene_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/translate_models.dart';
import '../../domain/providers/translate_provider.dart';
import '../../../../shared/widgets/feature_header.dart';
import '../widgets/translate_progress.dart';

class TranslatePage extends ConsumerWidget {
  const TranslatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);

    // QUOTA_EXCEEDED 监听放在页面级（始终挂载），避免 AnimatedSwitcher 切换子 widget 时丢失 listener
    ref.listen<TranslateState>(translateProvider, (prev, next) {
      if (next.errorMessage == 'QUOTA_EXCEEDED' &&
          (prev == null || prev.errorMessage != 'QUOTA_EXCEEDED')) {
        _showPayWall(context, ref, next);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(stage: state.stage),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: switch (state.stage) {
                  TranslateStage.input => const _InputStage(key: ValueKey('input')),
                  TranslateStage.translating => const _TranslatingStage(key: ValueKey('translating')),
                  TranslateStage.result => const _ResultStage(key: ValueKey('result')),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPayWall(BuildContext context, WidgetRef ref, TranslateState state) async {
    final sceneId = state.mode == TranslateMode.document ? 'scene_translate_long' : 'scene_translate';
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
          onPaid: () => ref.read(translateProvider.notifier).translate(),
        );
      }
    } catch (e) {
      if (context.mounted) context.push('/subscription');
    }
  }
}

// ==================== Header ====================

class _Header extends StatelessWidget {
  final TranslateStage stage;

  const _Header({required this.stage});

  @override
  Widget build(BuildContext context) {
    return FeatureHeader(
      color: switch (stage) {
        TranslateStage.input => AppColors.cta,
        TranslateStage.translating => AppColors.cta,
        TranslateStage.result => AppColors.success,
      },
      title: switch (stage) {
        TranslateStage.input => '智能翻译',
        TranslateStage.translating => '正在翻译',
        TranslateStage.result => '翻译完成',
      },
      subtitle: switch (stage) {
        TranslateStage.input => '专业翻译 · 术语一致性保障 · 翻译记忆',
        TranslateStage.translating => '多阶段智能翻译中...',
        TranslateStage.result => '双语对照 · 术语高亮 · 一键精修',
      },
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
          const _DocTypeSelector(),
          const _IndustrySelector(),
          const _CustomRequirementsField(),
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
              onTap: () => ref.read(translateProvider.notifier).setMode(TranslateMode.text),
            ),
            _ModeTabItem(
              icon: Icons.upload_file_outlined,
              label: '文档翻译',
              isActive: state.mode == TranslateMode.document,
              onTap: () => ref.read(translateProvider.notifier).setMode(TranslateMode.document),
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.cta),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => notifier.swapLanguages(),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: AppColors.cta, shape: BoxShape.circle),
                child: const Icon(Icons.swap_horiz, color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(width: 8),
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLangPicker(BuildContext context, WidgetRef ref, {required bool isSource}) {
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
                      const Text('选择语言', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...Language.all.map((lang) {
                  final current = isSource ? state.sourceLang : state.targetLang;
                  final isSelected = current.code == lang.code;
                  return ListTile(
                    title: Text(lang.name, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppColors.cta : AppColors.text)),
                    trailing: isSelected ? const Icon(Icons.check, color: AppColors.cta) : null,
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

// ==================== DocType Selector ====================

class _DocTypeSelector extends ConsumerWidget {
  const _DocTypeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);
    final notifier = ref.read(translateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('文档类型', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: DocTypeOption.all.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final opt = DocTypeOption.all[i];
                final isSelected = state.docType == opt.value;
                return GestureDetector(
                  onTap: () => notifier.setDocType(opt.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.ctaBg : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: isSelected ? AppColors.cta : AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.cta : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Industry Selector ====================

class _IndustrySelector extends ConsumerWidget {
  const _IndustrySelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);
    final notifier = ref.read(translateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('行业领域', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: IndustryOption.all.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final opt = IndustryOption.all[i];
                final isSelected = state.industry == opt.value;
                return GestureDetector(
                  onTap: () => notifier.setIndustry(opt.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.ctaBg : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: isSelected ? AppColors.cta : AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.cta : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Custom Requirements ====================

class _CustomRequirementsField extends ConsumerStatefulWidget {
  const _CustomRequirementsField();

  @override
  ConsumerState<_CustomRequirementsField> createState() => _CustomRequirementsFieldState();
}

class _CustomRequirementsFieldState extends ConsumerState<_CustomRequirementsField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(translateProvider).customRequirements);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(translateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('自定义要求（可选）', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _controller,
              onChanged: (v) => notifier.setCustomRequirements(v),
              maxLength: 200,
              maxLines: 2,
              minLines: 1,
              style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.5),
              decoration: const InputDecoration(
                hintText: '例如：保持专业术语不翻译、使用正式语气...',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(10),
                counterStyle: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
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
    _sourceController = TextEditingController(text: ref.read(translateProvider).inputText);
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.public, size: 14, color: AppColors.cta),
                SizedBox(width: 4),
                Text('原文', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.cta)),
              ]),
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
                  style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: '输入或粘贴要翻译的文本...',
                    hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.cta, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
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
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: hasFile ? AppColors.cta : AppColors.border, width: 2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: hasFile ? AppColors.ctaBg : AppColors.surface,
                ),
                child: hasFile
                    ? Column(children: [
                        const Icon(Icons.description_outlined, size: 32, color: AppColors.cta),
                        const SizedBox(height: 8),
                        Text(state.documentFileName ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.cta)),
                        const SizedBox(height: 4),
                        const Text('点击重新选择文件', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ])
                    : const Column(children: [
                        Icon(Icons.upload_file_outlined, size: 32, color: AppColors.textMuted),
                        SizedBox(height: 8),
                        Text('上传文档翻译', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                        SizedBox(height: 4),
                        Text('支持 .docx .pdf .txt .md，最大 50MB\n自动保留原文格式和排版', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ]),
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
              const Text('术语表', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
              GestureDetector(
                onTap: () => context.push('/glossary'),
                child: const Text('编辑', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.cta)),
              ),
            ],
          ),
        ),
        ...state.glossary.map((term) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Expanded(child: Text(term.source, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text))),
              Expanded(child: Text(term.target, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.cta))),
            ]),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 18, color: Colors.white),
              SizedBox(width: 6),
              Text('专业翻译', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== Translating Stage ====================

class _TranslatingStage extends ConsumerWidget {
  const _TranslatingStage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(translateProvider);
    final notifier = ref.read(translateProvider.notifier);

    return TranslateProgressWidget(
      progress: state.progress,
      message: state.progressMessage,
      extractedTerms: state.extractedTerms,
      paragraphProgress: state.paragraphProgress,
      detectedDocType: state.detectedDocType,
      onCancel: () => notifier.cancel(),
    );
  }
}

// ==================== Result Stage ====================

class _ResultStage extends ConsumerStatefulWidget {
  const _ResultStage({super.key});

  @override
  ConsumerState<_ResultStage> createState() => _ResultStageState();
}

class _ResultStageState extends ConsumerState<_ResultStage> {
  _ViewMode _viewMode = _ViewMode.translated;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(translateProvider);
    final notifier = ref.read(translateProvider.notifier);
    final hasBilingual = state.bilingualParagraphs.isNotEmpty;

    return Column(
      children: [
        // 顶部：术语统计
        if (state.extractedTerms.isNotEmpty || state.autoSavedTermCount > 0)
          _TermStatsPanel(
            termsCount: state.extractedTerms.length,
            autoSavedCount: state.autoSavedTermCount,
            terms: state.extractedTerms,
          ),

        // 切换栏：原文 / 译文
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _ViewTab(
                label: '译文',
                isActive: _viewMode == _ViewMode.translated,
                color: AppColors.success,
                onTap: () => setState(() => _viewMode = _ViewMode.translated),
              ),
              const SizedBox(width: 6),
              _ViewTab(
                label: '原文',
                isActive: _viewMode == _ViewMode.source,
                color: AppColors.cta,
                onTap: () => setState(() => _viewMode = _ViewMode.source),
              ),
              if (hasBilingual) ...[
                const SizedBox(width: 6),
                _ViewTab(
                  label: '双语',
                  isActive: _viewMode == _ViewMode.bilingual,
                  color: AppColors.textSecondary,
                  onTap: () => setState(() => _viewMode = _ViewMode.bilingual),
                ),
              ],
            ],
          ),
        ),

        // 主预览区域
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: switch (_viewMode) {
                  _ViewMode.source => _SourceView(
                    paragraphs: state.bilingualParagraphs,
                    plainText: state.inputText,
                  ),
                  _ViewMode.translated => _TranslatedView(
                    paragraphs: state.bilingualParagraphs,
                    plainText: state.translatedText,
                  ),
                  _ViewMode.bilingual => _BilingualFullView(paragraphs: state.bilingualParagraphs),
                },
              ),
            ),
          ),
        ),

        // 底部操作按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => notifier.goToStage(TranslateStage.input),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      backgroundColor: AppColors.surface,
                    ),
                    child: const Text('重新翻译', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: state.isLoading ? null : () => notifier.export(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cta,
                      disabledBackgroundColor: AppColors.cta.withValues(alpha: 0.6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: state.isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text('导出文档', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ViewMode { source, translated, bilingual }

class _ViewTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _ViewTab({required this.label, required this.isActive, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: isActive ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ==================== Content Views ====================

class _SourceView extends StatelessWidget {
  final List<BilingualParagraph> paragraphs;
  final String plainText;
  const _SourceView({required this.paragraphs, required this.plainText});

  @override
  Widget build(BuildContext context) {
    if (paragraphs.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: paragraphs.length,
        separatorBuilder: (_, __) => const Divider(height: 16, color: AppColors.borderLight),
        itemBuilder: (_, i) => Text(
          paragraphs[i].source,
          style: const TextStyle(fontSize: 14, height: 1.8, color: AppColors.text),
        ),
      );
    }
    if (plainText.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Text(plainText, style: const TextStyle(fontSize: 14, height: 1.8, color: AppColors.text)),
      );
    }
    return const Center(child: Text('暂无原文', style: TextStyle(color: AppColors.textMuted)));
  }
}

class _TranslatedView extends StatelessWidget {
  final List<BilingualParagraph> paragraphs;
  final String plainText;
  const _TranslatedView({required this.paragraphs, required this.plainText});

  @override
  Widget build(BuildContext context) {
    if (paragraphs.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: paragraphs.length,
        separatorBuilder: (_, __) => const Divider(height: 16, color: AppColors.borderLight),
        itemBuilder: (_, i) {
          final p = paragraphs[i];
          if (p.highlights.isNotEmpty) return _buildHighlightedParagraph(p);
          return Text(
            p.translated,
            style: const TextStyle(fontSize: 14, height: 1.8, color: AppColors.text),
          );
        },
      );
    }
    // fallback: 纯文本
    if (plainText.isNotEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Text(plainText, style: const TextStyle(fontSize: 14, height: 1.8, color: AppColors.text)),
      );
    }
    return const Center(child: Text('暂无译文', style: TextStyle(color: AppColors.textMuted)));
  }

  Widget _buildHighlightedParagraph(BilingualParagraph p) {
    final spans = <TextSpan>[];
    var lastEnd = 0;
    final sorted = List.of(p.highlights)..sort((a, b) => a.start.compareTo(b.start));
    for (final h in sorted) {
      if (h.start > lastEnd) {
        spans.add(TextSpan(text: p.translated.substring(lastEnd, h.start)));
      }
      spans.add(TextSpan(
        text: p.translated.substring(h.start, h.end),
        style: const TextStyle(color: AppColors.cta, decoration: TextDecoration.underline, decorationColor: AppColors.cta),
      ));
      lastEnd = h.end;
    }
    if (lastEnd < p.translated.length) {
      spans.add(TextSpan(text: p.translated.substring(lastEnd)));
    }
    return RichText(
      text: TextSpan(style: const TextStyle(fontSize: 14, height: 1.8, color: AppColors.text), children: spans),
    );
  }
}

class _BilingualFullView extends StatelessWidget {
  final List<BilingualParagraph> paragraphs;
  const _BilingualFullView({required this.paragraphs});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: paragraphs.length,
      itemBuilder: (_, i) {
        final p = paragraphs[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sm)),
                  ),
                  child: Text('第 ${p.index + 1} 段', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Text(p.source, style: const TextStyle(fontSize: 13, height: 1.7, color: AppColors.textSecondary)),
                ),
                const Divider(height: 1, indent: 10, endIndent: 10, color: AppColors.borderLight),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                  child: Text(p.translated, style: const TextStyle(fontSize: 13, height: 1.7, color: AppColors.text)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== Term Stats Panel ====================

class _TermStatsPanel extends StatelessWidget {
  final int termsCount;
  final int autoSavedCount;
  final List<ExtractedTerm> terms;

  const _TermStatsPanel({
    required this.termsCount,
    required this.autoSavedCount,
    required this.terms,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: const Color(0x3310B981)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  '共 $termsCount 个术语 · 全部一致 ✓',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                ),
              ],
            ),
            if (autoSavedCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '本次自动保存 $autoSavedCount 个新术语到您的术语表',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
            if (terms.isNotEmpty && terms.length <= 8) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: terms.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    '${t.source} → ${t.target}',
                    style: const TextStyle(fontSize: 10, color: AppColors.text),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

