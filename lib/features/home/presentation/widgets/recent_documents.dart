import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../document/data/models/document_models.dart';
import '../../../document/domain/providers/document_provider.dart';

class RecentDocuments extends ConsumerStatefulWidget {
  const RecentDocuments({super.key});

  @override
  ConsumerState<RecentDocuments> createState() => _RecentDocumentsState();
}

class _RecentDocumentsState extends ConsumerState<RecentDocuments> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(documentListProvider.notifier).load(
          tab: DocCenterTab.all,
          page: 1,
          silentIfHasData: true,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '最近文档',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              if (state.items.isNotEmpty)
                GestureDetector(
                  onTap: () => context.push('/documents'),
                  child: const Text(
                    '全部文档',
                    style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
        if (state.isLoading)
          _buildLoadingState()
        else if (state.error != null)
          _buildErrorState(state.error!)
        else if (state.items.isEmpty)
          _buildWelcomeGuide(context)
        else
          ..._buildDocItems(state.items.take(5).toList()),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(child: Text(error, style: const TextStyle(fontSize: 12, color: AppColors.error))),
            GestureDetector(
              onTap: () => ref.read(documentListProvider.notifier).load(tab: DocCenterTab.all),
              child: const Text('重试', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeGuide(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          const Text('开始你的第一份文档', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 4),
          const Text('AI 帮你写，你来做决定', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          const Row(
            children: [
              _GuideStep(icon: Icons.edit_note, label: '描述需求', color: AppColors.primary),
              _GuideArrow(),
              _GuideStep(icon: Icons.auto_awesome, label: 'AI 生成', color: AppColors.success),
              _GuideArrow(),
              _GuideStep(icon: Icons.download_done, label: '导出文档', color: AppColors.cta),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/generate'),
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('立即体验', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.push('/templates'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.description_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text('或从模板开始', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline, decorationColor: AppColors.textMuted.withValues(alpha: 0.4))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(3, (_) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              SkeletonLoader(width: 40, height: 40, borderRadius: 8),
              SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 160, height: 14, borderRadius: 4),
                  SizedBox(height: 6),
                  SkeletonLoader(width: 80, height: 11, borderRadius: 4),
                ],
              )),
            ],
          ),
        )),
      ),
    );
  }

  List<Widget> _buildDocItems(List<DocForgeDocument> docs) {
    return docs.map((doc) {
      final isRunning = doc.status == DocStatus.running || doc.status == DocStatus.pending;
      return _DocItem(
        docId: doc.id,
        icon: doc.docType.icon,
        iconBgColor: doc.docType.bgColor,
        iconColor: doc.docType.color,
        title: doc.title,
        category: doc.docType.label,
        time: _formatTime(doc.createdAt),
        badge: _StatusBadge(status: doc.status),
        progress: isRunning ? doc.progress : null,
      );
    }).toList();
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
      if (diff.inHours < 24) return '${diff.inHours} 小时前';
      if (diff.inDays < 2) return '昨天';
      if (diff.inDays < 7) return '${diff.inDays} 天前';
      return '${dt.month}月${dt.day}日';
    } catch (_) {
      return '';
    }
  }
}

class _DocItem extends StatelessWidget {
  final int docId;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String category;
  final String time;
  final Widget badge;
  final double? progress;

  const _DocItem({
    required this.docId,
    required this.icon, required this.iconBgColor, required this.iconColor,
    required this.title, required this.category, required this.time,
    required this.badge, this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/documents/$docId'),
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(category, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle)),
                      ),
                      Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            badge,
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DocStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: status.bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status.color)),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _GuideStep({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _GuideArrow extends StatelessWidget {
  const _GuideArrow();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 16),
      child: Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
    );
  }
}
