import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// 功能页首访浮动提示气泡，自动记录已展示，同一用户同一 key 仅显示一次。
class FirstVisitTip extends StatefulWidget {
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  const FirstVisitTip({
    super.key,
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  State<FirstVisitTip> createState() => _FirstVisitTipState();
}

class _FirstVisitTipState extends State<FirstVisitTip>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  bool _dismissed = false;
  Timer? _autoDismissTimer;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;

  static const _autoDismissDuration = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && !_dismissed) {
        setState(() => _visible = true);
        _animController.forward();
        _startAutoDismiss();
      }
    });
  }

  void _startAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(_autoDismissDuration, () {
      if (mounted && !_dismissed) _dismiss();
    });
  }

  void _dismiss() {
    _autoDismissTimer?.cancel();
    _dismissed = true;
    _animController.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible)
          Positioned(
            left: 16,
            right: 16,
            top: 8,
            child: SlideTransition(
              position: _slideAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: FadeTransition(
                  opacity: _opacityAnim,
                  child: _buildBubble(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBubble() {
    return MouseRegion(
      onEnter: (_) => _autoDismissTimer?.cancel(),
      onExit: (_) {
        if (!_dismissed) _startAutoDismiss();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: const Color(0xFFE8ECF2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContent(),
            _buildArrow(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(widget.icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _dismiss,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrow() {
    return CustomPaint(
      painter: _ArrowPainter(),
      size: const Size(double.infinity, 8),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final path = Path()
      ..moveTo(cx - 6, 0)
      ..lineTo(cx, 7)
      ..lineTo(cx + 6, 0)
      ..close();

    final paint = Paint()..color = Colors.white;
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = const Color(0xFFE8ECF2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final borderPath = Path()
      ..moveTo(cx - 6.5, -0.5)
      ..lineTo(cx, 7.5)
      ..lineTo(cx + 6.5, -0.5);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
