import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/generate_models.dart';
import '../../domain/providers/generate_provider.dart';
import '../../../../shared/widgets/feature_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Stage 1: 输入页
class InputStage extends ConsumerStatefulWidget {
  const InputStage({super.key});

  @override
  ConsumerState<InputStage> createState() => _InputStageState();
}

class _InputStageState extends ConsumerState<InputStage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generateProvider);
    final notifier = ref.read(generateProvider.notifier);

    return Column(
      children: [
        // 蓝色头部
        FeatureHeader(
          color: AppColors.primary,
          title: '专业长文档编写',
          subtitle: '描述需求，AI 为你生成专业文档',
          showBackButton: true,
          onBack: () => context.go('/'),
        ),
        // 文档类型选择提示行
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '选择文档类型',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  '查看全部',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        // 横滑文档类型 chips
        _buildTypeChips(state, notifier),
        // 分隔线
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, thickness: 1, color: AppColors.borderLight),
        ),
        // "描述你的需求"
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '描述你的需求',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
          ),
        ),
        // 大 textarea
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
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.6),
              decoration: InputDecoration(
                hintText: '请描述你需要生成的文档内容，例如：\n\n生成一份技术开发合同，甲方为XX科技有限公司，乙方为YY数据科技有限公司，项目为智慧园区管理平台开发，合同金额120万元，工期6个月...',
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
              onChanged: (v) => notifier.updateContent(v),
            ),
          ),
        ),
        // 语言 pills
        Padding(
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
        ),
        // 双按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              // 快速撰写 (flex:2)
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => notifier.startGenerate(outlineOnly: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
                          '快速撰写',
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
              // 撰写大纲 (flex:1)
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => notifier.startGenerate(outlineOnly: true),
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
        ),
        // 底部提示
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            '快速生成将使用模板默认结构，跳过大纲确认步骤',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildTypeChips(GenerateState state, GenerateNotifier notifier) {
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
                boxShadow: isActive
                    ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type.icon,
                    size: 15,
                    color: isActive ? Colors.white : AppColors.textMuted,
                  ),
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
}
