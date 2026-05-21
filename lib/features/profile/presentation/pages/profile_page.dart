import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../payment/domain/providers/payment_provider.dart' as payment;
import '../../../notification/domain/providers/notification_provider.dart';
import '../../domain/providers/quota_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ref.invalidate(unreadCountProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final displayName = user?.username ?? user?.phone ?? '用户';
    final quotaState = ref.watch(quotaProvider);
    final isPro = ref.watch(payment.quotaProvider).maybeWhen(
      data: (quota) => quota.isPro, orElse: () => false,
    );
    final unreadAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadAsync.maybeWhen(data: (c) => c, orElse: () => 0);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(displayName, isPro, unreadCount),
            _buildStatsRow(quotaState),
            _buildQuotaCard(quotaState),
            _buildSubscriptionBanner(),
            _buildMenuSection('常用', [
              _MenuItem(
                icon: Icons.history,
                title: '历史文档',
                onTap: () => context.push('/documents'),
              ),
              _MenuItem(
                icon: Icons.drafts_outlined,
                title: '草稿箱',
                onTap: () => context.push('/drafts'),
              ),
              _MenuItem(
                icon: Icons.bookmark_outline,
                title: '收藏模板',
                onTap: () => context.push('/templates'),
              ),
              _MenuItem(
                icon: Icons.feedback_outlined,
                title: '问题反馈',
                onTap: () => context.push('/feedback'),
              ),
            ]),
            const SizedBox(height: 8),
            _buildMenuSection('增长', [
              _MenuItem(
                icon: Icons.card_giftcard,
                title: '推荐有礼',
                tag: '得5次额度',
                tagColor: AppColors.cta,
                tagBgColor: AppColors.ctaBg,
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.share_outlined,
                title: '分享到微信',
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 8),
            _buildMenuSection('设置', [
              _MenuItem(
                icon: Icons.settings_outlined,
                title: '设置',
                onTap: () => context.push('/settings'),
              ),
              _MenuItem(
                icon: Icons.info_outline,
                title: '关于${AppConstants.appName}',
                onTap: () => context.push('/about'),
              ),
            ]),
            const SizedBox(height: 16),
            _buildLogoutButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Blue header with avatar ───────────────────────────────────────────────

  Widget _buildHeader(String displayName, bool isPro, int unreadCount) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 40),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      displayName.substring(0, 1),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Name + badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isPro)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF97316), Color(0xFFFB923C)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Pro 会员',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        Text(
                          '免费版',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                // Notification button
                GestureDetector(
                  onTap: () {
                    context.push('/notifications');
                    Future.delayed(const Duration(milliseconds: 500), () {
                      ref.invalidate(unreadCountProvider);
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Icon(
                            Icons.notifications_none,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: unreadCount > 9 ? 4 : 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Center(
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(QuotaState quotaState) {
    if (quotaState.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(children: [
          Expanded(child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted)))),
          _buildStatDivider(),
          Expanded(child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted)))),
          _buildStatDivider(),
          Expanded(child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted)))),
        ]),
      );
    }

    final quota = quotaState.data;
    if (quota == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: GestureDetector(
            onTap: () => context.go('/generate'),
            child: Text('开始你的第一篇文档 →',
              style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    // 从配额数据聚合统计
    final generateTotal = quota.used['scene_generic'] ?? 0;
    final polishTotal = (quota.used['scene_polish'] ?? 0) + (quota.used['scene_polish_long'] ?? 0);
    final hasData = generateTotal > 0 || polishTotal > 0;
    if (!hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: GestureDetector(
            onTap: () => context.go('/generate'),
            child: Text('开始你的第一篇文档 →',
              style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          _buildStatItem('$generateTotal', '生成文档'),
          _buildStatDivider(),
          _buildStatItem('$polishTotal', '精修次数'),
          _buildStatDivider(),
          _buildStatItem(quota.planLabel, '当前套餐'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 28, color: AppColors.border);
  }

  // ─── Quota card (floating) ─────────────────────────────────────────────────

  Widget _buildQuotaCard(QuotaState quotaState) {
    final quota = quotaState.data;

    // 计算月度总剩余配额（不混入日限）
    int totalRemaining = 0;
    if (quota != null) {
      for (final sceneId in quota.quotas.keys) {
        final mr = quota.monthlyRemaining(sceneId);
        if (mr > 0) totalRemaining += mr;
      }
    }

    return Transform.translate(
      offset: const Offset(0, -14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: quotaState.isLoading
            ? Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted)))
            : GestureDetector(
                onTap: () => context.push('/usage'),
                child: Row(
                  children: [
                    _buildQuotaItem('$totalRemaining', '剩余配额', AppColors.success, AppColors.successBg),
                    _buildQuotaItem('—', '模板收藏', AppColors.primary, AppColors.primaryBg),
                    _buildQuotaItem('—', '术语表', AppColors.cta, AppColors.ctaBg),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildQuotaItem(String value, String label, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Subscription banner ───────────────────────────────────────────────────

  Widget _buildSubscriptionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '续费 Pro 会员',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '解锁无限生成、高级模板与优先客服',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.push('/subscription'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Text(
                '立即续费',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Menu section ──────────────────────────────────────────────────────────

  Widget _buildMenuSection(String title, List<_MenuItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Container(
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
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  _buildMenuItem(items[i]),
                  if (i < items.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: Container(height: 0.5, color: AppColors.borderLight),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
            ),
            if (item.tag != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: item.tagBgColor ?? AppColors.ctaBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.tag!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: item.tagColor ?? AppColors.cta,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ─── Logout button ─────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: () {
            _showLogoutDialog();
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.error, width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: const Text(
            '退出登录',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Logout confirmation dialog ────────────────────────────────────────────

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          '确认退出',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        content: const Text(
          '退出后需要重新登录才能使用',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: const Text(
                '取消',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ref.read(authProvider.notifier).logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: const Text(
                '退出',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menu item data model ──────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String title;
  final String? tag;
  final Color? tagColor;
  final Color? tagBgColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.tag,
    this.tagColor,
    this.tagBgColor,
    required this.onTap,
  });
}
