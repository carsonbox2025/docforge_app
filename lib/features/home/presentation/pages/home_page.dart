import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../notification/domain/providers/notification_provider.dart';
import '../../../membership/domain/providers/membership_provider.dart';
import '../widgets/quick_actions.dart';
import '../widgets/feature_carousel.dart';
import '../widgets/recent_documents.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
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
    final unreadAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadAsync.maybeWhen(data: (c) => c, orElse: () => 0);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await ref.read(quotaProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // ── Blue header ──
            _buildHeader(unreadCount),
            // ── Quick actions (overlaps header by 18px) ──
            const QuickActions(),
            // ── Feature carousel ──
            const SizedBox(height: 4),
            const FeatureCarousel(),
            // ── Recent documents ──
            const RecentDocuments(),
            // ── Quota hint ──
            _buildQuotaHint(),
            const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int unreadCount) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 18),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        // Extend the blue 18px below the content so QuickActions
        // visually sits "on" the header (total blue padding-bottom = 18+18=36px)
      ),
      child: Stack(
        children: [
          // Decorative circle (prototype: 240px, top:-80px, right:-60px)
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // Brand + action buttons
          SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Brand name + subtitle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppConstants.appSlogan,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Search + notification
                Row(
                  children: [
                    _HeaderIconButton(
                      icon: Icons.task_outlined,
                      onTap: () => context.push('/documents'),
                    ),
                    const SizedBox(width: 6),
                    _HeaderIconButton(
                      icon: Icons.search,
                      onTap: () => context.push('/search'),
                    ),
                    const SizedBox(width: 6),
                    _NotificationBadgeButton(
                      unreadCount: unreadCount,
                      onTap: () {
                        context.push('/notifications');
                        Future.delayed(const Duration(milliseconds: 500), () {
                          ref.invalidate(unreadCountProvider);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaHint() {
    final quotaState = ref.watch(quotaProvider);
    if (quotaState.isLoading) return const SizedBox.shrink();
    final quota = quotaState.data;
    if (quota == null) {
      return _buildQuotaBanner(
        icon: Icons.info_outline,
        text: '配额信息加载失败，下拉刷新重试',
        color: AppColors.textMuted,
      );
    }
    if (quota.isYearly) {
      return _buildQuotaBanner(
        icon: Icons.workspace_premium,
        text: '年度会员 · 全场景无限使用',
        color: AppColors.primary,
      );
    }
    if (quota.isPro) {
      return _buildQuotaBanner(
        icon: Icons.workspace_premium,
        text: '${quota.planLabel} · 享受更多权益',
        color: AppColors.primary,
        onTap: () => context.push('/subscription'),
      );
    }
    return _buildQuotaBanner(
      icon: Icons.shield_outlined,
      text: '部分场景限免体验，升级 Pro 解锁无限次',
      color: AppColors.cta,
      onTap: () => context.push('/subscription'),
    );
  }

  Widget _buildQuotaBanner({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color == AppColors.primary ? AppColors.primaryBg : AppColors.ctaBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.7)),
      ),
    );
  }
}

class _NotificationBadgeButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBadgeButton({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              child: Icon(Icons.notifications_none, size: 18,
                  color: Colors.white.withValues(alpha: 0.7)),
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
    );
  }
}
