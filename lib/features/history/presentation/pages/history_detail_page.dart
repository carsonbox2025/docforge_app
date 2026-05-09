import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/history_data_source.dart';
import '../../data/models/history_models.dart';

class HistoryDetailPage extends StatefulWidget {
  final int documentId;

  const HistoryDetailPage({super.key, required this.documentId});

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  final HistoryDataSource _dataSource = HistoryDataSource();

  HistoryDocument? _document;
  String _content = '';
  ReviewResult? _review;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _dataSource.getDocumentDetail(widget.documentId),
      _dataSource.getDocumentContent(widget.documentId),
      _dataSource.getReviewResult(widget.documentId),
    ]);

    if (!mounted) return;
    setState(() {
      _document = results[0] as HistoryDocument?;
      _content = results[1] as String;
      _review = results[2] as ReviewResult?;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDocInfoCard(),
                        if (_review != null) _buildReviewCard(),
                        _buildContentPreview(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                _buildBottomActions(),
              ],
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
              Expanded(
                child: Text(
                  _document?.title ?? '文档详情',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocInfoCard() {
    if (_document == null) return const SizedBox.shrink();
    final doc = _document!;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: doc.docType.bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(doc.docType.icon, size: 22, color: doc.docType.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _InfoChip(label: doc.docType.label),
                        const SizedBox(width: 6),
                        _InfoChip(label: doc.category.label),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.borderLight),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoItem(label: '文档类型', value: doc.docType.label),
              const SizedBox(width: 24),
              _InfoItem(label: '字数', value: '${doc.wordCount} 字'),
              const SizedBox(width: 24),
              Expanded(child: _InfoItem(label: '创建时间', value: doc.createdAt)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    if (_review == null) return const SizedBox.shrink();
    final review = _review!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '审校结果',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ReviewStat(count: review.passCount, label: '通过', color: AppColors.success),
              const SizedBox(width: 16),
              _ReviewStat(count: review.warnCount, label: '警告', color: AppColors.warn),
              const SizedBox(width: 16),
              _ReviewStat(count: review.errorCount, label: '错误', color: AppColors.error),
            ],
          ),
          if (review.issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.borderLight),
            const SizedBox(height: 8),
            ...review.issues.map((issue) => _buildReviewIssue(issue)),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewIssue(ReviewIssue issue) {
    final Color color;
    final IconData icon;
    switch (issue.level) {
      case 'pass':
        color = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case 'warn':
        color = AppColors.warn;
        icon = Icons.warning_amber;
        break;
      case 'error':
        color = AppColors.error;
        icon = Icons.error_outline;
        break;
      default:
        color = AppColors.primary;
        icon = Icons.info_outline;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.message,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
                ),
                Text(
                  issue.location,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '内容预览',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              const Spacer(),
              Text(
                '${_document?.wordCount ?? 0} 字',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _content.isEmpty ? '暂无内容' : _content,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.8,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/generate'),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('重新编辑'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    backgroundColor: AppColors.surface,
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
                  onPressed: () {},
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('导出 Word'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
      ],
    );
  }
}

class _ReviewStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _ReviewStat({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
