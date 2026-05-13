import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class FeatureCarousel extends StatefulWidget {
  const FeatureCarousel({super.key});

  @override
  State<FeatureCarousel> createState() => _FeatureCarouselState();
}

class _FeatureCarouselState extends State<FeatureCarousel>
    with WidgetsBindingObserver {
  late PageController _pageCtrl;
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  static const _slides = <_CarouselSlide>[
    _CarouselSlide(
      gradientColors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
      icon: Icons.bolt,
      title: '说一句话，8 分钟拿到专业文档',
      description: '租房协议、合作合同、项目方案……描述需求即可生成',
      tags: ['合同', '标书', '公文'],
      decoSize: 160,
      decoTop: -40,
      decoRight: -30,
    ),
    _CarouselSlide(
      gradientColors: [Color(0xFF312E81), Color(0xFF6366F1)],
      icon: Icons.auto_fix_high,
      title: '草稿写完了？一键变正式文档',
      description: '粘贴初稿，AI 帮你润色措辞、修正语病、按模板排版',
      tags: ['润色', '排版', '导出 Word'],
      decoSize: 130,
      decoTop: -30,
      decoRight: -10,
    ),
    _CarouselSlide(
      gradientColors: [Color(0xFF5B21B6), Color(0xFFA78BFA)],
      icon: Icons.public,
      title: '整篇文档翻译，术语不打架',
      description: '上传文档一键翻译，自动锁定术语，支持中英日韩等 6 种语言',
      tags: ['6 种语言', '术语一致', '文档翻译'],
      decoSize: 100,
      decoTop: 10,
      decoRight: -20,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageCtrl = PageController();
    _startAutoPlay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoPlayTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused) {
      _autoPlayTimer?.cancel();
    } else if (lifecycleState == AppLifecycleState.resumed) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (!_pageCtrl.hasClients) return;
      final next = (_currentPage + 1) % _slides.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.ease,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Column(
        children: [
          SizedBox(
            height: 170,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  _startAutoPlay();
                },
                itemCount: _slides.length,
                itemBuilder: (ctx, i) => _buildSlideCard(_slides[i]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildDots(),
        ],
      ),
    );
  }

  Widget _buildSlideCard(_CarouselSlide slide) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: slide.gradientColors,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Positioned(
            top: slide.decoTop.toDouble(),
            right: slide.decoRight.toDouble(),
            child: Container(
              width: slide.decoSize.toDouble(),
              height: slide.decoSize.toDouble(),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(slide.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          slide.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: slide.tags.map((tag) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (index) {
        final isActive = index == _currentPage;
        return GestureDetector(
          onTap: () {
            _pageCtrl.animateToPage(
              index,
              duration: const Duration(milliseconds: 350),
              curve: Curves.ease,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.ease,
            width: isActive ? 20 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: isActive ? AppColors.primary : AppColors.border,
            ),
          ),
        );
      }),
    );
  }
}

class _CarouselSlide {
  final List<Color> gradientColors;
  final IconData icon;
  final String title;
  final String description;
  final List<String> tags;
  final double decoSize;
  final double decoTop;
  final double decoRight;

  const _CarouselSlide({
    required this.gradientColors,
    required this.icon,
    required this.title,
    required this.description,
    required this.tags,
    required this.decoSize,
    required this.decoTop,
    required this.decoRight,
  });
}
