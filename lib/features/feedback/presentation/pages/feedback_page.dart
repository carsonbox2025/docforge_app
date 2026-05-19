import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/feedback_models.dart';
import '../../domain/providers/feedback_provider.dart';

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  FeedbackType _selectedType = FeedbackType.suggestion;
  final _contentController = TextEditingController();
  final _contactController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabCtrl.index == 1 && !_tabCtrl.indexIsChanging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(feedbackProvider.notifier).loadHistory();
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _contentController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedbackProvider);

    ref.listen<FeedbackState>(feedbackProvider, (prev, next) {
      if (next.submitSuccess && !(prev?.submitSuccess ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('反馈提交成功，感谢您的建议！'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        _contentController.clear();
        _contactController.clear();
        ref.read(feedbackProvider.notifier).resetSubmit();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('问题反馈'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.text,
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          tabs: const [Tab(text: '提交反馈'), Tab(text: '反馈历史')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildSubmitTab(state),
          _buildHistoryTab(state),
        ],
      ),
    );
  }

  // ─── 提交反馈 ───

  Widget _buildSubmitTab(FeedbackState state) {
    final contentLen = _contentController.text.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 类型选择
          const Text('反馈类型',
              style:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: feedbackTypeOptions.map((opt) {
              final isSelected = _selectedType == opt.type;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = opt.type),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryBg
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(opt.icon,
                            size: 16,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(opt.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // 反馈内容
          const Text('反馈内容',
              style:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _contentController,
              maxLines: 6,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '请详细描述您遇到的问题或建议...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
                counterStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 联系方式
          const Text('联系方式（可选）',
              style:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _contactController,
            decoration: InputDecoration(
              hintText: '手机号或邮箱，方便我们联系您',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 错误提示
          if (state.submitError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(state.submitError!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error)),
            ),

          const SizedBox(height: 8),

          // 提交按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (state.isSubmitting || contentLen == 0)
                  ? null
                  : () {
                      ref.read(feedbackProvider.notifier).submit(
                            type: _selectedType,
                            content: _contentController.text.trim(),
                            contact: _contactController.text.trim().isNotEmpty
                                ? _contactController.text.trim()
                                : null,
                          );
                    },
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('提交反馈'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 反馈历史 ───

  Widget _buildHistoryTab(FeedbackState state) {
    if (state.isLoadingHistory) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (state.history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('暂无反馈记录',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _FeedbackCard(record: state.history[i]),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackRecord record;
  const _FeedbackCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: record.statusBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(record.statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: record.statusColor)),
              ),
              const Spacer(),
              if (record.createdAt != null)
                Text(record.createdAt!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(record.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.5)),
          if (record.adminReply != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('回复',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  const SizedBox(height: 4),
                  Text(record.adminReply!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
