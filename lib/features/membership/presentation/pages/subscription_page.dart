import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../data/models/membership_models.dart';
import '../../domain/providers/membership_provider.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(membershipProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAppBar(context),
            _buildHeroBanner(state),
            const SizedBox(height: 16),
            _buildCurrentPlanCard(state),
            const SizedBox(height: 16),
            _buildPlanSelector(ref, state),
            const SizedBox(height: 16),
            _buildBenefitsTable(state),
            const SizedBox(height: 16),
            _buildCTAButton(ref, state),
            _buildFooterNote(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, AppSpacing.lg, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: Icon(Icons.arrow_back, size: 20, color: Colors.white.withValues(alpha: 0.7)),
              ),
              const Text(
                'Pro 会员',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(MembershipState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.xxl + 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
        ),
      ),
      child: Column(
        children: [
          // Pro badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium, size: 18, color: Colors.amber[300]),
                const SizedBox(width: 6),
                const Text(
                  'Pro 会员',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '解锁全部专业能力',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '无限生成、专业模板、多语言翻译，满足您的所有文档需求',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(value: '∞', label: '文档生成'),
              _StatItem(value: '50+', label: '专业模板'),
              _StatItem(value: '6', label: '语言翻译'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard(MembershipState state) {
    final status = state.status;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.workspace_premium, size: 24, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      status.currentPlan.label,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    const SizedBox(width: 8),
                    if (status.isPro && !status.isExpired)
                      BadgeWidget.primary('生效中'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  status.expireDate != null ? '到期时间：${status.expireDate}' : '未订阅',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector(WidgetRef ref, MembershipState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: PlanType.values.map((plan) {
          final isSelected = state.selectedPlan == plan;
          final isRecommended = plan == PlanType.yearly;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(membershipProvider.notifier).selectPlan(plan),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryBg : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        Text(
                          plan.price,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? AppColors.primary : AppColors.text,
                          ),
                        ),
                        Text(
                          plan.period.isEmpty ? '买断' : plan.period,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan == PlanType.yearly ? '约¥16.6/月' : (plan == PlanType.lifetime ? '一次付费' : ''),
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    if (isRecommended)
                      Positioned(
                        top: -10,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.cta,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '推荐',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBenefitsTable(MembershipState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text('权益', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Center(child: Text('Free', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)))),
                Expanded(flex: 2, child: Center(child: Text('Pro', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)))),
              ],
            ),
          ),
          // Benefit rows
          ...state.benefits.map((benefit) => Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    benefit.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: benefit.isFreeChecked
                        ? Text(benefit.freeValue, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
                        : Icon(Icons.close, size: 14, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: benefit.isProChecked
                        ? Text(benefit.proValue, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary))
                        : Icon(Icons.close, size: 14, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCTAButton(WidgetRef ref, MembershipState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: state.isLoading ? null : () => ref.read(membershipProvider.notifier).subscribe(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            elevation: 0,
          ),
          child: state.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '立即续费 · ${state.selectedPlan.price}/${state.selectedPlan == PlanType.lifetime ? '永久' : '年'}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Column(
        children: [
          Text(
            '订阅后自动续费，可随时在设置中取消',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 4),
          Text(
            '购买即表示同意《用户协议》和《隐私政策》',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
