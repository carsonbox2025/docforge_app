import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/common_widgets.dart';

class DraftsPage extends StatefulWidget {
  const DraftsPage({super.key});

  @override
  State<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage> {
  // Placeholder draft data
  final List<_DraftItem> _drafts = const [
    _DraftItem(
      title: '技术服务合同 - 修订版',
      docType: '合同',
      lastEdited: '5 分钟前',
      progress: 0.8,
    ),
    _DraftItem(
      title: '2026年Q2采购招标文件',
      docType: '招标文件',
      lastEdited: '2 小时前',
      progress: 0.6,
    ),
    _DraftItem(
      title: '项目可行性研究报告',
      docType: '报告',
      lastEdited: '昨天',
      progress: 0.4,
    ),
    _DraftItem(
      title: '张三-高级产品经理-简历',
      docType: '简历',
      lastEdited: '3 天前',
      progress: 0.9,
    ),
    _DraftItem(
      title: '产品需求评审会议纪要',
      docType: '会议纪要',
      lastEdited: '1 周前',
      progress: 0.3,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.text,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '草稿箱',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppColors.borderLight, height: 0.5),
        ),
      ),
      body: _drafts.isEmpty
          ? const EmptyState(
              title: '暂无草稿',
              subtitle: '创建文档时未完成的内容会自动保存在这里',
              icon: Icons.drafts_outlined,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _drafts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _buildDraftCard(_drafts[index]),
            ),
    );
  }

  Widget _buildDraftCard(_DraftItem draft) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Expanded(
                child: Text(
                  draft.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _DocTypeBadge(docType: draft.docType),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: draft.progress,
              backgroundColor: AppColors.borderLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 10),
          // Bottom row: time + action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    draft.lastEdited,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to continue editing
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: const Text(
                    '继续编辑',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Draft data model ──────────────────────────────────────────────────────────

class _DraftItem {
  final String title;
  final String docType;
  final String lastEdited;
  final double progress;

  const _DraftItem({
    required this.title,
    required this.docType,
    required this.lastEdited,
    required this.progress,
  });
}

// ─── Document type badge ───────────────────────────────────────────────────────

class _DocTypeBadge extends StatelessWidget {
  final String docType;

  const _DocTypeBadge({required this.docType});

  Color _getColor() {
    switch (docType) {
      case '合同':
        return AppColors.primary;
      case '招标文件':
        return AppColors.cta;
      case '报告':
        return AppColors.success;
      case '简历':
        return AppColors.purple;
      case '会议纪要':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        docType,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
