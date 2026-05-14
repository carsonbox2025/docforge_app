import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  const LoadingOverlay({super.key, required this.child, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  const EmptyState({super.key, required this.title, this.subtitle, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  const SkeletonLoader({super.key, this.width = double.infinity, this.height = 16, this.borderRadius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: AppColors.warnBg,
      child: const Row(
        children: [
          Icon(Icons.wifi_off, size: 16, color: AppColors.warn),
          SizedBox(width: 8),
          Text('网络连接已断开', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warn)),
        ],
      ),
    );
  }
}

class PremiumGate extends StatelessWidget {
  final Widget child;
  final bool isLocked;
  final VoidCallback? onUpgrade;
  const PremiumGate({super.key, required this.child, this.isLocked = false, this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white.withValues(alpha: 0.8)],
              ),
            ),
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: onUpgrade,
              icon: const Icon(Icons.star, size: 16),
              label: const Text('升级 Pro 解锁'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cta,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BadgeWidget extends StatelessWidget {
  final String text;
  final Color color;
  final Color bgColor;
  const BadgeWidget({super.key, required this.text, required this.color, required this.bgColor});

  factory BadgeWidget.success(String text) => BadgeWidget(text: text, color: AppColors.success, bgColor: AppColors.successBg);
  factory BadgeWidget.primary(String text) => BadgeWidget(text: text, color: AppColors.primary, bgColor: AppColors.primaryBg);
  factory BadgeWidget.warn(String text) => BadgeWidget(text: text, color: AppColors.warn, bgColor: AppColors.warnBg);
  factory BadgeWidget.error(String text) => BadgeWidget(text: text, color: AppColors.error, bgColor: AppColors.errorBg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
