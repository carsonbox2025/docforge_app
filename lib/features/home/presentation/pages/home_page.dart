import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/quick_actions.dart';
import '../widgets/feature_carousel.dart';
import '../widgets/recent_documents.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Blue header ──
            // Prototype: padding 20px top / 36px bottom
            // We use bottom: 18px here and let QuickActions overlay
            // the remaining 18px via negative Transform to match
            // prototype's margin:-18px effect.
            _buildHeader(),
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
    );
  }

  Widget _buildHeader() {
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
                    Text(
                      AppConstants.appName,
                      style: const TextStyle(
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
                      icon: Icons.search,
                      onTap: () => context.push('/search'),
                    ),
                    const SizedBox(width: 6),
                    _HeaderIconButton(
                      icon: Icons.notifications_none,
                      onTap: () => context.push('/notifications'),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.ctaBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.cta.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: AppColors.cta),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '每月 3 次免费生成额度，升级 Pro 解锁无限次',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.cta,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
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
