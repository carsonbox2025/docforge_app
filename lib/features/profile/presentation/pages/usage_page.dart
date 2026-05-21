import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../membership/domain/providers/membership_provider.dart';
import '../../../payment/data/models/payment_models.dart';

/// 场景显示配置
class _SceneDisplay {
  final String sceneId;
  final String name;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _SceneDisplay({
    required this.sceneId,
    required this.name,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

const _scenes = [
  _SceneDisplay(sceneId: 'scene_generic', name: '通用文档', icon: Icons.article_outlined, color: AppColors.primary, bgColor: AppColors.primaryBg),
  _SceneDisplay(sceneId: 'scene_resume', name: 'AI简历', icon: Icons.person_outline, color: Color(0xFF2563EB), bgColor: Color(0x0F2563EB)),
  _SceneDisplay(sceneId: 'scene_official', name: '公文写作', icon: Icons.account_balance_outlined, color: Color(0xFFD97706), bgColor: Color(0x0FD97706)),
  _SceneDisplay(sceneId: 'scene_contract', name: '合同协议', icon: Icons.description_outlined, color: Color(0xFF059669), bgColor: Color(0x0F059669)),
  _SceneDisplay(sceneId: 'scene_litigation', name: '诉讼文书', icon: Icons.gavel_outlined, color: Color(0xFFDC2626), bgColor: Color(0x0FDC2626)),
  _SceneDisplay(sceneId: 'scene_paper', name: '毕业论文', icon: Icons.menu_book_outlined, color: Color(0xFF7C3AED), bgColor: Color(0x0F7C3AED)),
  _SceneDisplay(sceneId: 'scene_proposal', name: '技术方案', icon: Icons.computer_outlined, color: Color(0xFF0891B2), bgColor: Color(0x0F0891B2)),
  _SceneDisplay(sceneId: 'scene_polish', name: '文档精修', icon: Icons.auto_fix_high, color: AppColors.success, bgColor: AppColors.successBg),
  _SceneDisplay(sceneId: 'scene_polish_long', name: '长文档精修', icon: Icons.auto_fix_high, color: AppColors.success, bgColor: AppColors.successBg),
  _SceneDisplay(sceneId: 'scene_translate', name: '文本翻译', icon: Icons.translate, color: AppColors.purple, bgColor: Color(0x0F7C3AED)),
  _SceneDisplay(sceneId: 'scene_translate_long', name: '文档翻译', icon: Icons.translate, color: AppColors.purple, bgColor: Color(0x0F7C3AED)),
];

class UsagePage extends ConsumerWidget {
  const UsagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotaState = ref.watch(quotaProvider);

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
          '用量统计',
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
      body: quotaState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : quotaState.error != null
              ? _buildErrorState(ref, quotaState.error!)
              : quotaState.data != null
                  ? _buildContent(quotaState.data!)
                  : const SizedBox.shrink(),
    );
  }

  Widget _buildErrorState(WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            const Text('加载用量数据失败', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 4),
            Text(error, style: const TextStyle(fontSize: 12, color: AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.read(quotaProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(QuotaInfo quota) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPlanCard(quota),
          const SizedBox(height: 16),
          _buildSceneBreakdown(quota),
        ],
      ),
    );
  }

  /// 顶部套餐卡片
  Widget _buildPlanCard(QuotaInfo quota) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('当前套餐', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  quota.planLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
          if (quota.expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '到期：${quota.expiresAt}',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ],
      ),
    );
  }

  /// 按场景分组展示
  Widget _buildSceneBreakdown(QuotaInfo quota) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('场景配额', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 16),
          ..._scenes.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _SceneQuotaRow(scene: s, quota: quota),
          )),
        ],
      ),
    );
  }
}

class _SceneQuotaRow extends StatelessWidget {
  final _SceneDisplay scene;
  final QuotaInfo quota;

  const _SceneQuotaRow({required this.scene, required this.quota});

  @override
  Widget build(BuildContext context) {
    final monthlyUsed = quota.used[scene.sceneId] ?? 0;
    final monthlyLimit = quota.quotas[scene.sceneId] ?? 0;
    final dailyUsed = quota.dailyUsed[scene.sceneId] ?? 0;
    final dailyLimit = quota.dailyQuotas[scene.sceneId];

    final isUnlimitedMonthly = monthlyLimit == -1;
    final hasDailyLimit = dailyLimit != null && dailyLimit > 0;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: scene.bgColor, borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Icon(scene.icon, size: 16, color: scene.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(scene.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                  Text(
                    isUnlimitedMonthly ? '$monthlyUsed / ∞' : '$monthlyUsed / $monthlyLimit',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: isUnlimitedMonthly
                      ? 0.0
                      : (monthlyLimit > 0 ? (monthlyUsed / monthlyLimit).clamp(0.0, 1.0) : 0.0),
                  backgroundColor: AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(scene.color),
                  minHeight: 4,
                ),
              ),
              if (hasDailyLimit) ...[
                const SizedBox(height: 4),
                Text(
                  '今日：$dailyUsed / $dailyLimit',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted.withValues(alpha: 0.8)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
