import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/shimmer_skeleton.dart';
import '../../data/models/document_models.dart';
import '../../domain/providers/document_provider.dart';

class DocumentCenterPage extends ConsumerStatefulWidget {
  const DocumentCenterPage({super.key});

  @override
  ConsumerState<DocumentCenterPage> createState() => _DocumentCenterPageState();
}

class _DocumentCenterPageState extends ConsumerState<DocumentCenterPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    final savedTab = ref.read(documentListProvider).tab;
    final initialIndex = DocCenterTab.values.indexOf(savedTab).clamp(0, DocCenterTab.values.length - 1);
    _tabCtrl = TabController(
      length: DocCenterTab.values.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabCtrl.addListener(_onTabChange);
    _scrollController.addListener(_onScroll);
    Future.microtask(() => ref.read(documentListProvider.notifier).load(
          tab: DocCenterTab.values[initialIndex],
        ));
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChange);
    _scrollController.removeListener(_onScroll);
    _tabCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    if (max - current < 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    await ref.read(documentListProvider.notifier).loadMore();
    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _onTabChange() {
    if (!_tabCtrl.indexIsChanging) {
      ref.read(documentListProvider.notifier).load(
            tab: DocCenterTab.values[_tabCtrl.index],
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentListProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('文档中心', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: DocCenterTab.values.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: state.isLoading
          ? ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, __) => const CardShimmer(),
            )
          : state.error != null
              ? _buildError(state.error!)
              : state.items.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: () => ref.read(documentListProvider.notifier).load(),
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.items.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          if (i == state.items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          return _DocCard(doc: state.items[i]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    final tab = DocCenterTab.values[_tabCtrl.index.clamp(0, DocCenterTab.values.length - 1)];
    final text = switch (tab) {
      DocCenterTab.running => '没有正在进行的任务',
      DocCenterTab.completed => '还没有生成完成的文档',
      DocCenterTab.all => '暂无文档，立即创建第一篇',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/generate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: const Text('创建文档'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(error, style: const TextStyle(fontSize: 14, color: AppColors.error)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(documentListProvider.notifier).load(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final DocForgeDocument doc;
  const _DocCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final isRunning = doc.status == DocStatus.running || doc.status == DocStatus.pending;

    return GestureDetector(
      onTap: () => context.push('/documents/${doc.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
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
                Icon(doc.docCategory.icon, size: 18, color: doc.docCategory.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    doc.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                _StatusBadge(status: doc.status),
              ],
            ),
            if (isRunning) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: doc.progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.borderLight,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(doc.progress.clamp(0.0, 1.0) * 100).round()}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
            ],
            if (doc.errorMsg != null && doc.status == DocStatus.failed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(doc.errorMsg!,
                    style: const TextStyle(fontSize: 12, color: AppColors.error),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(doc.docCategory.label,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                if (doc.wordCount != null)
                  Text('${doc.wordCount}字',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                Text(_formatTime(doc.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
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
      return '${dt.month}月${dt.day}日';
    } catch (_) {
      return createdAt;
    }
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
      child: Text(status.label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status.color)),
    );
  }
}
