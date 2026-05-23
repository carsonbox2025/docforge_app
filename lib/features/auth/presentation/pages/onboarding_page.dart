import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/providers/auth_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _slides = [
    _Slide(
      icon: Icons.description_outlined,
      accent: Color(0xFF2563EB),
      accentBg: Color(0xFFEFF6FF),
      stat: '10万+',
      statLabel: '单篇字数',
      title: '长文档智能生成',
      desc: '输入主题或大纲，AI 自动完成全文撰写。\n支持合同、标书、方案、报告等 8 大专业场景。',
      tags: ['合同', '标书', '方案', '报告'],
      preview: _PreviewType.document,
    ),
    _Slide(
      icon: Icons.fact_check_outlined,
      accent: Color(0xFF059669),
      accentBg: Color(0xFFECFDF5),
      stat: 'Word',
      statLabel: '一键导出',
      title: '专业校审与排版',
      desc: '上传草稿，AI 润色措辞、修正语病、校对事实。\n自动按规范排版，导出即可提交。',
      tags: ['润色', '校对', '排版', '导出'],
      preview: _PreviewType.edit,
    ),
    _Slide(
      icon: Icons.translate_rounded,
      accent: Color(0xFF7C3AED),
      accentBg: Color(0xFFF5F3FF),
      stat: '98%',
      statLabel: '术语一致性',
      title: '全文翻译，术语统一',
      desc: '整篇文档一键翻译，专业术语全程锁定。\n支持中、英、日、韩、法、德 6 种语言。',
      tags: ['6 种语言', '术语锁定', '格式保留'],
      preview: _PreviewType.translate,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      ref.read(authProvider.notifier).completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildPageView()),
            _buildSteps(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPage == _slides.length - 1 ? '开始使用' : '下一步',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _currentPage == _slides.length - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.arrow_forward_ios_rounded,
                        size: _currentPage == _slides.length - 1 ? 20 : 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text('稿搭子',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
            ],
          ),
          TextButton(
            onPressed: () => ref.read(authProvider.notifier).completeOnboarding(),
            child: Text('跳过',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _controller,
      itemCount: _slides.length,
      onPageChanged: (i) => setState(() => _currentPage = i),
      itemBuilder: (_, i) => _buildSlide(_slides[i]),
    );
  }

  Widget _buildSlide(_Slide s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildPreview(s),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: s.accentBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text('${s.stat}  ${s.statLabel}',
                style: TextStyle(fontSize: 12, color: s.accent, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          Text(s.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text, height: 1.3)),
          const SizedBox(height: 12),
          Text(s.desc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w400, height: 1.7)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: s.tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(t, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(_Slide s) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: CustomPaint(
        painter: _PreviewPainter(s),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildSteps() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_slides.length, (i) {
          final active = i == _currentPage;
          final done = i < _currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: done
                    ? AppColors.primary
                    : active
                        ? AppColors.primary
                        : AppColors.border,
              ),
            ),
          );
        }),
      ),
    );
  }
}

enum _PreviewType { document, edit, translate }

class _Slide {
  final IconData icon;
  final Color accent;
  final Color accentBg;
  final String stat;
  final String statLabel;
  final String title;
  final String desc;
  final List<String> tags;
  final _PreviewType preview;

  const _Slide({
    required this.icon,
    required this.accent,
    required this.accentBg,
    required this.stat,
    required this.statLabel,
    required this.title,
    required this.desc,
    required this.tags,
    required this.preview,
  });
}

class _PreviewPainter extends CustomPainter {
  final _Slide slide;
  _PreviewPainter(this.slide);

  @override
  void paint(Canvas canvas, Size size) {
    final px = 24.0;
    final py = 20.0;
    final contentW = size.width - px * 2;
    final contentH = size.height - py * 2;

    // Top bar
    final barPaint = Paint()..color = const Color(0xFFF8FAFC);
    final barRrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(px, py, contentW, 28),
      const Radius.circular(6),
    );
    canvas.drawRRect(barRrect, barPaint);

    // Dots
    for (int i = 0; i < 3; i++) {
      final dotPaint = Paint()
        ..color = i == 0
            ? slide.accent
            : const Color(0xFFE2E8F0);
      canvas.drawCircle(Offset(px + 14 + i * 14, py + 14), 4, dotPaint);
    }

    // Title text placeholder in bar
    final titlePaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(px + 56, py + 10, contentW * 0.35, 8),
        const Radius.circular(4),
      ),
      titlePaint,
    );

    final bodyTop = py + 36;
    final bodyH = contentH - 36;

    switch (slide.preview) {
      case _PreviewType.document:
        _drawDocPreview(canvas, px, bodyTop, contentW, bodyH);
        break;
      case _PreviewType.edit:
        _drawEditPreview(canvas, px, bodyTop, contentW, bodyH);
        break;
      case _PreviewType.translate:
        _DrawTranslatePreview(canvas, px, bodyTop, contentW, bodyH);
        break;
    }
  }

  void _drawDocPreview(Canvas canvas, double px, double top, double w, double h) {
    final linePaint = Paint()..color = const Color(0xFFE2E8F0);
    final headingPaint = Paint()..color = const Color(0xFFCBD5E1);

    // Heading line
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(px, top, w * 0.6, 10), const Radius.circular(5)),
      headingPaint,
    );

    // Body lines
    double y = top + 22;
    for (int i = 0; i < 5; i++) {
      final lw = i == 4 ? w * 0.4 : w * (0.7 + (i % 3) * 0.1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(px, y, lw, 6), const Radius.circular(3)),
        linePaint,
      );
      y += 14;
    }

    // Paragraph 2
    y += 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(px, y, w * 0.5, 10), const Radius.circular(5)),
      headingPaint,
    );
    y += 20;
    for (int i = 0; i < 3; i++) {
      final lw = i == 2 ? w * 0.3 : w * (0.65 + (i % 2) * 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(px, y, lw, 6), const Radius.circular(3)),
        linePaint,
      );
      y += 14;
    }

    // Cursor blink
    final cursorPaint = Paint()..color = slide.accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(px + 2, y + 2, 2, 14), const Radius.circular(1)),
      cursorPaint,
    );
  }

  void _drawEditPreview(Canvas canvas, double px, double top, double w, double h) {
    final oldPaint = Paint()..color = const Color(0xFFFEE2E2);
    final newPaint = Paint()..color = const Color(0xFFDCFCE7);
    final linePaint = Paint()..color = const Color(0xFFE2E8F0);

    // Old text (strikethrough-like red bg)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(px, top, w * 0.65, 10), const Radius.circular(5)),
      oldPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(px, top + 16, w * 0.5, 8), const Radius.circular(4)),
      oldPaint,
    );

    // Arrow indicator
    final arrowPaint = Paint()..color = slide.accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(px + w * 0.35, top + 32, w * 0.3, 18), const Radius.circular(9)),
      arrowPaint,
    );

    // New text (green bg)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(px, top + 58, w * 0.72, 10), const Radius.circular(5)),
      newPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(px, top + 74, w * 0.55, 8), const Radius.circular(4)),
      newPaint,
    );

    // Remaining lines
    double y = top + 94;
    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(px, y, w * (0.6 + i * 0.1), 6), const Radius.circular(3)),
        linePaint,
      );
      y += 14;
    }
  }

  void _DrawTranslatePreview(Canvas canvas, double px, double top, double w, double h) {
    final linePaint = Paint()..color = const Color(0xFFE2E8F0);
    final dividerPaint = Paint()..color = const Color(0xFFE2E8F0);

    // Left column (CN)
    final halfW = (w - 16) / 2;
    for (int i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(px, top + i * 16, halfW * (0.7 + (i % 2) * 0.2), 8),
          const Radius.circular(4),
        ),
        linePaint,
      );
    }

    // Divider
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(px + halfW + 8, top - 4, 1, h * 0.7),
        const Radius.circular(0.5),
      ),
      dividerPaint,
    );

    // Right column (EN)
    final enPaint = Paint()..color = const Color(0xFFDCFCE7);
    for (int i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(px + halfW + 18, top + i * 16, halfW * (0.65 + (i % 3) * 0.12), 8),
          const Radius.circular(4),
        ),
        enPaint,
      );
    }

    // Term lock indicator
    final lockPaint = Paint()..color = slide.accent;
    final lockX = px + halfW + 18 + halfW * 0.3;
    final lockY = top + h * 0.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(lockX, lockY, halfW * 0.45, 16),
        const Radius.circular(8),
      ),
      lockPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
