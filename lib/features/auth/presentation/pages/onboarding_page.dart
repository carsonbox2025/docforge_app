import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/providers/auth_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _stepCtrl;

  static const _slides = [
    _Slide(
      icon: Icons.description_outlined,
      title: '专业文档生成',
      highlights: [
        _Highlight(
          icon: Icons.auto_awesome,
          text: '专业文档生成，支持10万+长文档一次生成',
        ),
        _Highlight(
          icon: Icons.file_download_outlined,
          text: '专业文档格式排版，一键导出 Word',
        ),
      ],
      tags: ['合同', '标书', '方案', '报告'],
      steps: [
        _Step('输入主题', Icons.edit_note),
        _Step('AI 撰写', Icons.auto_awesome),
        _Step('在线预览', Icons.preview),
        _Step('导出 Word', Icons.download),
      ],
      gradient: [Color(0xFF2563EB), Color(0xFF3B82F6), Color(0xFF60A5FA)],
      accent: Color(0xFF2563EB),
    ),
    _Slide(
      icon: Icons.fact_check_outlined,
      title: '专业校审与排版',
      highlights: [
        _Highlight(
          icon: Icons.spellcheck,
          text: 'AI 智能校审，润色措辞、修正语病',
        ),
        _Highlight(
          icon: Icons.check_circle_outline,
          text: '逐条确认修改，专业排版一键导出',
        ),
      ],
      tags: ['润色', '校对', '排版', '导出'],
      steps: [
        _Step('上传草稿', Icons.upload_file),
        _Step('AI 审阅', Icons.fact_check),
        _Step('逐条确认', Icons.checklist),
        _Step('导出文档', Icons.download),
      ],
      gradient: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
      accent: Color(0xFF059669),
    ),
    _Slide(
      icon: Icons.translate_rounded,
      title: '全文翻译，术语统一',
      highlights: [
        _Highlight(
          icon: Icons.translate,
          text: '全文档一键翻译，专业术语全程锁定',
        ),
        _Highlight(
          icon: Icons.language,
          text: '支持中英日韩法德 6 种语言，格式完整保留',
        ),
      ],
      tags: ['6 种语言', '术语锁定', '格式保留'],
      steps: [
        _Step('上传文档', Icons.upload_file),
        _Step('术语匹配', Icons.link),
        _Step('AI 翻译', Icons.translate),
        _Step('双语对照', Icons.compare_arrows),
      ],
      gradient: [Color(0xFF7C3AED), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
      accent: Color(0xFF7C3AED),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _stepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stepCtrl.dispose();
    super.dispose();
  }

  int get _activeStep {
    final t = _stepCtrl.value;
    final stepsPerSlide = _slides[_currentPage].steps.length;
    return (t * stepsPerSlide).floor() % stepsPerSlide;
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      ref.read(authProvider.notifier).completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _buildSlide(_slides[i]),
              ),
            ),
            _buildSteps(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: slide.gradient),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: [
                      BoxShadow(
                        color: slide.accent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _next,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _slides.length - 1
                                ? '开始使用'
                                : '下一步',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _currentPage == _slides.length - 1
                                ? Icons.arrow_forward_rounded
                                : Icons.arrow_forward_ios_rounded,
                            size: _currentPage == _slides.length - 1 ? 20 : 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text('稿搭子',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
            ],
          ),
          TextButton(
            onPressed: () =>
                ref.read(authProvider.notifier).completeOnboarding(),
            child: const Text('跳过',
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(_Slide s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Step flow animation
          AnimatedBuilder(
            animation: _stepCtrl,
            builder: (context, _) => _StepFlowCard(
              slide: s,
              activeStep: _activeStep,
            ),
          ),
          const SizedBox(height: 24),
          // Title
          Text(s.title,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  height: 1.3)),
          const SizedBox(height: 16),
          // Highlights
          ...s.highlights.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HighlightCard(highlight: h, accent: s.accent),
              )),
          const SizedBox(height: 16),
          // Tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: s.tags.map((t) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                      color: s.accent.withValues(alpha: 0.15)),
                ),
                child: Text(t,
                    style: TextStyle(
                        fontSize: 12,
                        color: s.accent,
                        fontWeight: FontWeight.w600)),
              );
            }).toList(),
          ),
        ],
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
                color: done || active
                    ? _slides[i].accent
                    : AppColors.border,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Data models
// ──────────────────────────────────────────────

class _Step {
  final String label;
  final IconData icon;
  const _Step(this.label, this.icon);
}

class _Highlight {
  final IconData icon;
  final String text;
  const _Highlight({required this.icon, required this.text});
}

class _Slide {
  final IconData icon;
  final String title;
  final List<_Highlight> highlights;
  final List<String> tags;
  final List<_Step> steps;
  final List<Color> gradient;
  final Color accent;

  const _Slide({
    required this.icon,
    required this.title,
    required this.highlights,
    required this.tags,
    required this.steps,
    required this.gradient,
    required this.accent,
  });
}

// ──────────────────────────────────────────────
// Step flow card with animated screen mockup
// ──────────────────────────────────────────────

class _StepFlowCard extends StatelessWidget {
  final _Slide slide;
  final int activeStep;

  const _StepFlowCard({
    required this.slide,
    required this.activeStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            slide.gradient[0].withValues(alpha: 0.08),
            slide.gradient[1].withValues(alpha: 0.04),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: slide.accent.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: slide.gradient[0].withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated screen mockup
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: const Color(0xFFE8ECF2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                child: _buildScreenMockup(activeStep),
              ),
            ),
          ),
          // Step indicators
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: List.generate(slide.steps.length, (i) {
                final step = slide.steps[i];
                final isActive = i == activeStep;
                final isDone = i < activeStep;
                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: isActive ? 32 : 26,
                              height: isActive ? 32 : 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? slide.accent
                                    : isDone
                                        ? slide.accent.withValues(alpha: 0.15)
                                        : const Color(0xFFF1F5F9),
                                border: isActive
                                    ? null
                                    : Border.all(
                                        color: isDone
                                            ? slide.accent.withValues(alpha: 0.3)
                                            : const Color(0xFFE2E8F0),
                                      ),
                              ),
                              child: Icon(
                                isDone ? Icons.check_rounded : step.icon,
                                size: isActive ? 16 : 13,
                                color: isActive
                                    ? Colors.white
                                    : isDone
                                        ? slide.accent
                                        : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              step.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    isActive ? FontWeight.w700 : FontWeight.w500,
                                color: isActive
                                    ? slide.accent
                                    : isDone
                                        ? slide.accent.withValues(alpha: 0.6)
                                        : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < slide.steps.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: _StepConnector(
                            done: isDone,
                            color: slide.accent,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenMockup(int step) {
    final idx = slide.steps.indexOf(slide.steps[step]);
    return KeyedSubtree(
      key: ValueKey('${slide.title}_$idx'),
      child: _ScreenMockup(
        type: slide.icon,
        step: idx,
        accent: slide.accent,
        gradient: slide.gradient,
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Step connector line
// ──────────────────────────────────────────────

class _StepConnector extends StatelessWidget {
  final bool done;
  final Color color;

  const _StepConnector({required this.done, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: CustomPaint(
        painter: _ConnectorPainter(done: done, color: color),
        size: const Size(20, 2),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final bool done;
  final Color color;

  _ConnectorPainter({required this.done, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = done ? color : const Color(0xFFE2E8F0)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    if (done) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    } else {
      const dashW = 3.0;
      const gapW = 3.0;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(
            Offset(x, 0), Offset((x + dashW).clamp(0, size.width), 0), paint);
        x += dashW + gapW;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter old) => old.done != done;
}

// ──────────────────────────────────────────────
// Screen mockup for each step
// ──────────────────────────────────────────────

class _ScreenMockup extends StatelessWidget {
  final IconData type;
  final int step;
  final Color accent;
  final List<Color> gradient;

  const _ScreenMockup({
    required this.type,
    required this.step,
    required this.accent,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    // type: description_outlined → generate, fact_check → polish, translate → translate
    final isGenerate = type == Icons.description_outlined;
    final isPolish = type == Icons.fact_check_outlined;
    // isTranslate = type == Icons.translate_rounded

    if (isGenerate) return _buildGenerateMockup();
    if (isPolish) return _buildPolishMockup();
    return _buildTranslateMockup();
  }

  Widget _buildGenerateMockup() {
    switch (step) {
      case 0:
        return _mockupFrame(
          child: Column(
            children: [
              _mockTopBar('文档生成'),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockInput('请输入文档主题或大纲...', active: true),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockChipRow(['合同', '标书', '方案', '报告']),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockButton('开始生成'),
              ),
            ],
          ),
        );
      case 1:
        return _mockupFrame(
          child: Column(
            children: [
              _mockTopBar('正在撰写'),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockProgressBar(0.65, accent),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockTextLines(6, accent: accent, cursorAt: 3),
              ),
            ],
          ),
        );
      case 2:
        return _mockupFrame(
          child: Column(
            children: [
              _mockTopBar('文档预览'),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockTextLines(8),
              ),
            ],
          ),
        );
      case 3:
        return _mockupFrame(
          child: Column(
            children: [
              _mockTopBar('导出完成'),
              const SizedBox(height: 12),
              _mockFileCard('项目方案书.docx', '128,000 字', accent),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockButton('打开文件', done: true),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPolishMockup() {
    switch (step) {
      case 0:
        return _mockupFrame(
          child: Column(
            children: [
              _mockTopBar('文档精修'),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockUploadZone(),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockChipRow(['轻度', '中度', '深度']),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockButton('开始审阅'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      case 1:
        return _mockupFrame(
          child: Column(
            children: [
              _mockTopBar('AI 审阅中'),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockProgressBar(0.45, accent),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockSuggestionItems(3, accent),
              ),
            ],
          ),
        );
      case 2:
        return _mockupFrame(
          child: Column(
            children: [
              _mockTopBar('审阅结果'),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockSuggestionCard(
                  '语病修正',
                  '我们的产品具有...',
                  '我们的产品具备...',
                  accent,
                  accepted: true,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockSuggestionCard(
                  '措辞润色',
                  '通过使用本系统...',
                  '借助本系统...',
                  accent,
                ),
              ),
            ],
          ),
        );
      case 3:
        return _mockupFrame(
          child: Column(
            children: [
              _mockTopBar('导出完成'),
              const SizedBox(height: 12),
              _mockFileCard('精修报告.docx', '12 条修改已采纳', accent),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockButton('打开文件', done: true),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTranslateMockup() {
    switch (step) {
      case 0:
        return _mockupFrame(
          child: Column(
            children: [
              _mockTopBar('文档翻译'),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockUploadZone(),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockLangRow('中文', 'English'),
              ),
            ],
          ),
        );
      case 1:
        return _mockupFrame(
          child: Column(
            children: [
              _mockTopBar('术语匹配'),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockTermTable(4, accent),
              ),
            ],
          ),
        );
      case 2:
        return _mockupFrame(
          child: Column(
            children: [
              _mockTopBar('正在翻译'),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockProgressBar(0.72, accent),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockBilingualPreview(accent),
              ),
            ],
          ),
        );
      case 3:
        return _mockupFrame(
          child: Column(
            children: [
              _mockTopBar('翻译完成'),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockBilingualFull(accent),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _mockButton('导出双语文档', done: true),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Mockup building blocks ──

  Widget _mockupFrame({required Widget child}) {
    return Container(
      color: const Color(0xFFFAFBFC),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: child,
      ),
    );
  }

  Widget _mockTopBar(String title) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _mockInput(String hint, {bool active = false}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active ? accent.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(hint,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF94A3B8))),
          ),
          if (active)
            Container(
              width: 1.5,
              height: 14,
              color: accent,
            ),
        ],
      ),
    );
  }

  Widget _mockChipRow(List<String> labels) {
    return Row(
      children: labels.map((l) {
        final isSelected = labels.indexOf(l) == 0;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected
                    ? accent.withValues(alpha: 0.3)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(l,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? accent : const Color(0xFF94A3B8),
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _mockButton(String text, {bool done = false}) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: done ? const Color(0xFF10B981) : accent,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (done)
            const Icon(Icons.check, size: 12, color: Colors.white),
          if (done) const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _mockProgressBar(double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toInt()}% · 正在处理...',
          style: const TextStyle(
              fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _mockTextLines(int count, {Color? accent, int cursorAt = -1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(count, (i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              height: 8,
              width: double.infinity * 0.6,
              constraints: const BoxConstraints(
                  maxWidth: 160, minWidth: 80),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }
        final isLast = i == cursorAt;
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              if (isLast && accent != null) ...[
                const SizedBox(width: 4),
                Container(
                  width: 1.5,
                  height: 10,
                  color: accent,
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _mockUploadZone() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: accent.withValues(alpha: 0.3), width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload_outlined,
              size: 18, color: accent.withValues(alpha: 0.5)),
          const SizedBox(height: 4),
          Text('上传文档',
              style: TextStyle(
                  fontSize: 9,
                  color: accent.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _mockFileCard(String name, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.description, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 9,
                        color: color,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Icon(Icons.check_circle, size: 18, color: color),
        ],
      ),
    );
  }

  Widget _mockSuggestionItems(int count, Color color) {
    return Column(
      children: List.generate(count, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.spellcheck,
                      size: 10, color: color),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 5,
                        width: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 5,
                        width: 60,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _mockSuggestionCard(
    String category,
    String original,
    String suggested,
    Color color, {
    bool accepted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: accepted ? color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(category,
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
              const Spacer(),
              if (accepted)
                Icon(Icons.check_circle, size: 12, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(original,
              style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFFEF4444),
                  decoration: TextDecoration.lineThrough,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(suggested,
              style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _mockLangRow(String left, String right) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(left,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: accent)),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.swap_horiz, size: 12, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(right,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569))),
          ),
        ),
      ],
    );
  }

  Widget _mockTermTable(int rows, Color color) {
    return Column(
      children: [
        Container(
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 10),
              Expanded(child: Text('原文术语',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8)))),
              Expanded(child: Text('译文术语',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8)))),
            ],
          ),
        ),
        ...List.generate(rows, (i) {
          return Container(
            height: 20,
            decoration: BoxDecoration(
              color: i % 2 == 0 ? Colors.white : const Color(0xFFFAFBFC),
              border: const Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 4,
                    width: 50 + (i % 3) * 10.0,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 4,
                    width: 40 + (i % 2) * 15.0,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _mockBilingualPreview(Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          child: Column(
            children: List.generate(
                4,
                (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 1,
          height: 40,
          color: const Color(0xFFE2E8F0),
        ),
        const SizedBox(width: 8),
        // Right column
        Expanded(
          child: Column(
            children: List.generate(
                4,
                (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? color.withValues(alpha: 0.25)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
          ),
        ),
      ],
    );
  }

  Widget _mockBilingualFull(Color color) {
    return Column(
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 4,
                  width: 100,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ──────────────────────────────────────────────
// Highlight card (bottom selling point)
// ──────────────────────────────────────────────

class _HighlightCard extends StatelessWidget {
  final _Highlight highlight;
  final Color accent;

  const _HighlightCard({
    required this.highlight,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(highlight.icon, size: 16, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              highlight.text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
