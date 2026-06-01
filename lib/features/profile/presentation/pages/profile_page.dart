import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../membership/domain/providers/membership_provider.dart';
import '../../../notification/domain/providers/notification_provider.dart';

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
    final isPro = quotaState.isPro;
    final unreadAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadAsync.maybeWhen(data: (c) => c, orElse: () => 0);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(displayName, isPro, unreadCount),
            _buildUsageCard(quotaState),
            _buildSubscriptionBanner(),
            _buildMenuSection('常用', [
              _MenuItem(
                icon: Icons.history,
                title: '历史文档',
                iconBgColor: AppColors.primaryBg,
                iconColor: AppColors.primary,
                onTap: () => context.push('/documents'),
              ),
              _MenuItem(
                icon: Icons.bookmark_outline,
                title: '收藏模板',
                iconBgColor: const Color(0x0FF59E0B),
                iconColor: AppColors.warn,
                onTap: () => context.push('/templates'),
              ),
              _MenuItem(
                icon: Icons.menu_book_outlined,
                title: '术语表',
                iconBgColor: const Color(0x0F7C3AED),
                iconColor: AppColors.purple,
                onTap: () => context.push('/glossary'),
              ),
              _MenuItem(
                icon: Icons.feedback_outlined,
                title: '问题反馈',
                iconBgColor: AppColors.infoBg,
                iconColor: AppColors.info,
                onTap: () => context.push('/feedback'),
              ),
            ]),
            const SizedBox(height: 8),
            _buildMenuSection('增长', [
              _MenuItem(
                icon: Icons.card_giftcard,
                title: '推荐有礼',
                tag: '即将上线',
                tagColor: AppColors.textMuted,
                tagBgColor: AppColors.surfaceHover,
                iconBgColor: AppColors.ctaBg,
                iconColor: AppColors.cta,
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.share_outlined,
                title: '分享到微信',
                tag: '即将上线',
                tagColor: AppColors.textMuted,
                tagBgColor: AppColors.surfaceHover,
                iconBgColor: AppColors.successBg,
                iconColor: AppColors.success,
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 8),
            _buildMenuSection('设置', [
              _MenuItem(
                icon: Icons.settings_outlined,
                title: '设置',
                iconBgColor: const Color(0x0F7C3AED),
                iconColor: AppColors.purple,
                onTap: () => context.push('/settings'),
              ),
              _MenuItem(
                icon: Icons.info_outline,
                title: '关于${AppConstants.appName}',
                iconBgColor: const Color(0x0F64748B),
                iconColor: const Color(0xFF64748B),
                onTap: () => context.push('/about'),
              ),
            ]),
            const SizedBox(height: 16),
            _buildLogoutButton(),
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              child: Text(
                'v${AppConstants.appVersion}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
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
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
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
                    shape: BoxShape.circle,
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

  // ─── Usage overview card ─────────────────────────────────────────────────

  Widget _buildUsageCard(QuotaState quotaState) {
    if (quotaState.isLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
          ),
        ),
      );
    }

    final quota = quotaState.data;
    if (quota == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: GestureDetector(
            onTap: () => context.go('/generate'),
            child: const Text('开始你的第一篇文档 →',
                style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    final generateTotal = quota.used['scene_generic'] ?? 0;
    final polishTotal = (quota.used['scene_polish'] ?? 0) + (quota.used['scene_polish_long'] ?? 0);
    final translateTotal = (quota.used['scene_translate'] ?? 0) + (quota.used['scene_translate_long'] ?? 0);

    int totalQuota = 0;
    int totalUsed = 0;
    for (final sceneId in quota.quotas.keys) {
      final limit = quota.quotas[sceneId] ?? 0;
      if (limit > 0) {
        totalQuota += limit;
        totalUsed += quota.used[sceneId] ?? 0;
      }
    }
    final hasQuota = totalQuota > 0;
    final progress = hasQuota ? (totalUsed / totalQuota).clamp(0.0, 1.0) : 0.0;
    final remaining = totalQuota - totalUsed;

    return GestureDetector(
      onTap: () => context.push('/usage'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('剩余配额', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          if (hasQuota)
                            Text('$remaining/$totalQuota', style: const TextStyle(fontSize: 15, color: AppColors.text, fontWeight: FontWeight.w700))
                          else
                            const Text('无限', style: TextStyle(fontSize: 15, color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      if (hasQuota) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: AppColors.borderLight,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress > 0.8 ? AppColors.warn : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chevron_right, size: 20, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildUsageStat('$generateTotal', '生成'),
                _buildUsageStat('$polishTotal', '精修'),
                _buildUsageStat('$translateTotal', '翻译'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ─── Subscription banner ───────────────────────────────────────────────────

  Widget _buildSubscriptionBanner() {
    final quotaState = ref.watch(quotaProvider);
    final isPro = quotaState.isPro;
    final title = isPro ? '续费 Pro 会员' : '开通 Pro 会员';
    final subtitle = isPro
        ? '保持无限生成、高级模板与优先客服'
        : '解锁无限生成、高级模板与优先客服';
    final button = isPro ? '立即续费' : '立即开通';

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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
              child: Text(
                button,
                style: const TextStyle(
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
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
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
                      padding: const EdgeInsets.only(left: 52),
                      child: Container(height: 1, color: AppColors.border),
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
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, size: 18, color: item.iconColor),
            ),
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
            backgroundColor: AppColors.errorBg,
            side: const BorderSide(color: AppColors.error, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
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
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        title: const Text(
          '确认退出',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        content: const Text(
          '退出后需要重新登录才能使用',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '取消',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '退出',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
  final Color iconBgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.tag,
    this.tagColor,
    this.tagBgColor,
    this.iconBgColor = AppColors.primaryBg,
    this.iconColor = AppColors.primary,
    required this.onTap,
  });
}
