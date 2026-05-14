import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/shimmer_skeleton.dart';
import '../../../membership/domain/providers/membership_provider.dart';
import '../../data/models/template_models.dart';
import '../../domain/providers/template_provider.dart';

class TemplateGalleryPage extends ConsumerWidget {
  const TemplateGalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(templateProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _buildAppBar(context),
          _buildCategoryTabs(ref, state),
          Expanded(
            child: state.isLoading
                ? _buildShimmerGrid()
                : state.error != null
                    ? _buildError(state.error!, ref)
                    : state.filteredTemplates.isEmpty
                        ? const EmptyState(
                            title: '暂无模板',
                            subtitle: '该分类下暂无模板',
                            icon: Icons.dashboard_customize_outlined,
                          )
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: () => ref.read(templateProvider.notifier).reload(),
                            child: _buildTemplateGrid(ref, state),
                          ),
          ),
        ],
      ),
    );
  }

  void _showProGate(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
                const Icon(Icons.workspace_premium, size: 40, color: AppColors.cta),
                const SizedBox(height: 12),
                const Text('Pro 专属模板', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 8),
                const Text('订阅 Pro 会员即可解锁全部专业模板', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Future.microtask(() {
                        if (context.mounted) context.push('/subscription');
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      elevation: 0,
                    ),
                    child: const Text('了解 Pro 会员', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.text),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              const Text(
                '模板市场',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/search'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(WidgetRef ref, TemplateGalleryState state) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: TemplateCategory.values.map((cat) {
            final isActive = state.activeCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => ref.read(templateProvider.notifier).setCategory(cat),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                splashColor: AppColors.primary.withValues(alpha: 0.1),
                highlightColor: AppColors.primary.withValues(alpha: 0.05),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: isActive ? AppColors.primary : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Center(
                    child: Text(
                      cat.label,
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
      ),
    );
  }

  Widget _buildTemplateGrid(WidgetRef ref, TemplateGalleryState state) {
    final templates = state.filteredTemplates;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final tpl = templates[index];
        return _TemplateCard(
          template: tpl,
          onTap: () {
            if (tpl.requirePro) {
              final isPro = ref.read(membershipProvider).quota?.isPro ?? false;
              if (isPro) {
                context.push('/templates/${tpl.id}');
              } else {
                _showProGate(context);
              }
            } else {
              context.push('/templates/${tpl.id}');
            }
          },
        );
      },
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => const GridCardShimmer(),
    );
  }

  Widget _buildError(String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(error, style: const TextStyle(fontSize: 14, color: AppColors.error)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(templateProvider.notifier).reload(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Template template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail area
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: template.colorScheme.bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
                ),
                child: Stack(
                  children: [
                    // Decorative lines to simulate document
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: template.colorScheme.primary.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(4, (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Container(
                                height: 3,
                                margin: EdgeInsets.only(right: i == 3 ? 30 : 0),
                                decoration: BoxDecoration(
                                  color: template.colorScheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                    // Category icon
                    Positioned(
                      top: 10,
                      right: 10,
                      child: template.requirePro
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.cta,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Pro', style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white,
                              )),
                            )
                          : Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: template.colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                template.category.icon,
                                size: 14,
                                color: template.colorScheme.primary,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            // Info area
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.category.label,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.description_outlined, size: 12, color: AppColors.textMuted.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          '${template.documentCount} 个模板',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
