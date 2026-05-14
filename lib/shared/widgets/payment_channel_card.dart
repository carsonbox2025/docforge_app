import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart' show AppRadius;

class PaymentChannelCard extends StatelessWidget {
  final String label;
  final String svgIcon;
  final Color brandColor;
  final bool isActive;
  final bool enabled;
  final VoidCallback? onTap;

  const PaymentChannelCard({
    super.key,
    required this.label,
    required this.svgIcon,
    required this.brandColor,
    required this.isActive,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? brandColor.withValues(alpha: 0.08) : AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isActive ? brandColor : AppColors.border,
            width: isActive ? 2.0 : 1.0,
          ),
        ),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: brandColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    svgIcon,
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? brandColor : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
