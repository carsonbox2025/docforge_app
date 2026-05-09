import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// 4-grid quick action cards that visually float above the header.
///
/// In the HTML prototype: `margin:-18px 16px 12px` (negative top = overlap).
/// Here the parent HomePage sets header bottom-padding to 18px (half of 36px
/// prototype value), and QuickActions uses margin-top 0 so it sits right
/// at the bottom edge of the header. The remaining 18px of blue area
/// below the quick-grid is provided by the header's extra 18px bottom space.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _QuickActionItem(
            icon: Icons.bolt,
            label: '文章撰写',
            iconBgColor: AppColors.primaryBg,
            iconColor: AppColors.primary,
            onTap: () => context.go('/generate'),
          ),
          const SizedBox(width: 8),
          _QuickActionItem(
            icon: Icons.auto_fix_high,
            label: '精修排版',
            iconBgColor: AppColors.successBg,
            iconColor: AppColors.success,
            onTap: () => context.go('/polish'),
          ),
          const SizedBox(width: 8),
          _QuickActionItem(
            icon: Icons.public,
            label: '多语翻译',
            iconBgColor: AppColors.ctaBg,
            iconColor: AppColors.cta,
            onTap: () => context.go('/translate'),
          ),
          const SizedBox(width: 8),
          _QuickActionItem(
            icon: Icons.description_outlined,
            label: '模板库',
            iconBgColor: AppColors.infoBg,
            iconColor: AppColors.info,
            onTap: () => context.push('/templates'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconBgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.iconBgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000), // rgba(0,0,0,0.08)
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
