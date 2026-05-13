import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../scene/data/models/scene_models.dart';
import '../../../scene/domain/providers/scene_provider.dart';
import '../../../payment/domain/providers/payment_provider.dart';
import '../../../payment/presentation/widgets/pay_wall.dart';
import '../../data/models/generate_models.dart';
import '../../domain/providers/generate_provider.dart';
import '../../../../shared/widgets/feature_header.dart';
import 'scene_form.dart';
import 'cover_fields_form.dart';

/// Stage 1: 输入页 — 场景驱动 + 动态表单
class InputStage extends ConsumerStatefulWidget {
  const InputStage({super.key});

  @override
  ConsumerState<InputStage> createState() => _InputStageState();
}

class _InputStageState extends ConsumerState<InputStage> {
  final _contentController = TextEditingController();
  final Map<String, String> _fieldValues = {};
  final Map<String, String> _coverValues = {};

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generateProvider);
    final notifier = ref.read(generateProvider.notifier);
    final scenesAsync = ref.watch(sceneListProvider);

    return Column(
      children: [
        FeatureHeader(
          color: AppColors.primary,
          title: '专业文档编写',
          subtitle: '描述需求，AI 为你生成专业文档',
          showBackButton: true,
          onBack: () => context.go('/'),
        ),
        // 场景列表
        scenesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => _buildFallbackChips(state, notifier),
          data: (scenes) => _buildSceneChips(scenes, state, notifier),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, thickness: 1, color: AppColors.borderLight),
        ),
        // 动态表单区域
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildFormArea(state, notifier),
                _buildModeSelector(state, notifier),
                _buildLanguagePills(state, notifier),
                _buildErrorBanner(state),
                _buildActionButtons(state, notifier),
                _buildFooterHint(state),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 场景横滑 Chips
  Widget _buildSceneChips(
    List<SceneConfig> scenes,
    GenerateState state,
    GenerateNotifier notifier,
  ) {
    final selected = state.selectedScene;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: scenes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final scene = scenes[index];
          final isActive = selected?.sceneId == scene.sceneId;
          return GestureDetector(
            onTap: () => _confirmAndSwitchScene(scene, notifier),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForScene(scene),
                    size: 15,
                    color: isActive ? Colors.white : AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    scene.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  if (!scene.pricing.isFree) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white.withValues(alpha: 0.25) : AppColors.ctaBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        scene.pricing.displayPrice,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : AppColors.cta,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 降级方案：场景 API 加载失败时显示硬编码 DocType
  Widget _buildFallbackChips(GenerateState state, GenerateNotifier notifier) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: DocType.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final type = DocType.values[index];
          final isActive = state.selectedType == type;
          return GestureDetector(
            onTap: () => notifier.selectDocType(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(type.icon, size: 15, color: isActive ? Colors.white : AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 表单区域：有场景配置时显示动态表单，否则显示固定 textarea
  Widget _buildFormArea(GenerateState state, GenerateNotifier notifier) {
    final scene = state.selectedScene;

    if (scene != null && scene.formFields.isNotEmpty) {
      return Column(
        children: [
          // Layer 2 封面字段
          if (scene.isLayer2)
            CoverFieldsForm(
              fieldRegions: _extractCoverRegions(scene),
              fieldValues: _coverValues,
              onChanged: (k, v) {
                setState(() => _coverValues[k] = v);
                notifier.updateFieldsData({..._coverValues});
                notifier.clearError();
              },
            ),
          // 场景动态表单
          SceneDynamicForm(
            scene: scene,
            fieldValues: _fieldValues,
            onChanged: (k, v) {
              setState(() => _fieldValues[k] = v);
              // 将表单值合并到 content
              notifier.updateContent(_fieldValues['content'] ?? '');
              notifier.updateFormFields({..._fieldValues});
              notifier.clearError();
            },
          ),
        ],
      );
    }

    // 降级：固定 textarea
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            '描述你的需求',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            height: 250,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.6),
              decoration: InputDecoration(
                hintText: '请描述你需要生成的文档内容...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: (v) { notifier.updateContent(v); notifier.clearError(); },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector(GenerateState state, GenerateNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          const Text(
            '生成模式',
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
                  _ModeChip(
                    label: '快速撰写',
                    icon: Icons.bolt,
                    isActive: state.mode == 'quick',
                    onTap: () => notifier.selectMode('quick'),
                  ),
                  _ModeChip(
                    label: '专业长文',
                    icon: Icons.auto_awesome,
                    isActive: state.mode == 'professional',
                    onTap: () => notifier.selectMode('professional'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagePills(GenerateState state, GenerateNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: DocLanguage.values.map((lang) {
          final isActive = state.selectedLanguage == lang;
          return GestureDetector(
            onTap: () => notifier.selectLanguage(lang),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Text(
                lang.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons(GenerateState state, GenerateNotifier notifier) {
    final scene = state.selectedScene;
    final priceLabel = scene != null ? scene.pricing.displayPrice : '';
    final canGenerate = _canGenerate(state);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: canGenerate ? () => _handleGenerate(scene, notifier, outlineOnly: false) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canGenerate ? AppColors.primary : AppColors.border,
                  disabledBackgroundColor: AppColors.border,
                  disabledForegroundColor: AppColors.textMuted,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt, size: 20, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      priceLabel.isNotEmpty && priceLabel != '免费'
                          ? '一键生成 $priceLabel'
                          : '快速撰写',
                      style: TextStyle(
                        fontSize: state.selectedLanguage == DocLanguage.zhCN ? 15 : 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: canGenerate ? () => _handleGenerate(scene, notifier, outlineOnly: true) : null,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.edit_note, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    const Text(
                      '撰写大纲',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 生成按钮回调 — 增加支付拦截
  Future<void> _handleGenerate(
    SceneConfig? scene,
    GenerateNotifier notifier, {
    required bool outlineOnly,
  }) async {
    if (scene != null && !scene.pricing.isFree) {
      try {
        final quota = await ref.read(quotaProvider.future);
        if (!quota.isYearly && quota.remaining(scene.sceneId) <= 0) {
          if (mounted) {
            PayWall.show(
              context,
              scene: scene,
              onPaid: () => notifier.startGenerate(outlineOnly: outlineOnly),
            );
          }
          return;
        }
      } catch (_) {
        // 配额查询失败，允许继续（后端会做最终检查）
      }
    }
    notifier.startGenerate(outlineOnly: outlineOnly);
  }

  Widget _buildFooterHint(GenerateState state) {
    final scene = state.selectedScene;
    final hint = scene != null && !scene.pricing.isFree
        ? '${scene.name} · ${scene.pricing.displayPrice}/篇，生成不满意全额退款'
        : '快速生成将使用模板默认结构，跳过大纲确认步骤';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        hint,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
      ),
    );
  }

  /// 前端校验必填字段
  bool _canGenerate(GenerateState state) {
    final scene = state.selectedScene;
    if (scene == null) {
      // 无场景时，降级 textarea 需要有内容
      return _contentController.text.trim().isNotEmpty;
    }

    // 检查必填表单字段
    for (final field in scene.formFields) {
      if (field.required) {
        final value = _fieldValues[field.name]?.trim();
        if (value == null || value.isEmpty) return false;
      }
    }

    // Layer 2 检查必填封面字段
    if (scene.isLayer2) {
      final coverRegions = _extractCoverRegions(scene);
      for (final r in coverRegions) {
        if (r.required && (_coverValues[r.regionId]?.trim().isEmpty ?? true)) {
          return false;
        }
      }
    }

    return true;
  }

  /// 错误信息 Banner
  Widget _buildErrorBanner(GenerateState state) {
    if (state.error == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.error!,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// 场景切换确认（有未提交内容时弹窗）
  void _confirmAndSwitchScene(SceneConfig scene, GenerateNotifier notifier) {
    final hasContent = _fieldValues.values.any((v) => v.trim().isNotEmpty) ||
        _coverValues.values.any((v) => v.trim().isNotEmpty);

    if (hasContent) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('切换场景'),
          content: const Text('切换后当前填写的内容将被清空，确定要切换吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('继续填写'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _doSwitchScene(scene, notifier);
              },
              child: Text('确定切换', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
    } else {
      _doSwitchScene(scene, notifier);
    }
  }

  void _doSwitchScene(SceneConfig scene, GenerateNotifier notifier) {
    ref.read(selectedSceneProvider.notifier).state = scene;
    notifier.selectScene(scene);
    _fieldValues.clear();
    _coverValues.clear();
  }

  /// 从场景配置动态提取 Layer 2 封面字段
  List<FieldRegion> _extractCoverRegions(SceneConfig scene) {
    return scene.coverFieldRegions;
  }

  IconData _iconForScene(SceneConfig scene) => switch (scene.docType) {
        'official' => Icons.account_balance_outlined,
        'contract' => Icons.description_outlined,
        'resume' => Icons.person_outline,
        'litigation' => Icons.gavel_outlined,
        'thesis' => Icons.menu_book_outlined,
        'tech_proposal' => Icons.computer_outlined,
        _ => Icons.article_outlined,
      };
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeChip({
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
              Icon(icon, size: 14, color: isActive ? AppColors.primary : AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
