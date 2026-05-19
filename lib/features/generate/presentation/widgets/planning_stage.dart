import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/providers/generate_provider.dart';

class PlanningStage extends StatelessWidget {
  final List<String> thoughts;
  final String phase;
  final String title;

  const PlanningStage({
    super.key,
    required this.thoughts,
    required this.phase,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final phaseInfo = kPlanningPhases.cast<PlanningPhaseDef?>().firstWhere(
          (p) => p?.key == phase,
          orElse: () => kPlanningPhases.first,
        )!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                _BrandHeader(title: title, phaseInfo: phaseInfo),
                const SizedBox(height: AppSpacing.xl),
                _PhaseStepper(currentPhase: phase),
                const SizedBox(height: AppSpacing.xl),
                _ProgressBar(thoughts: thoughts, currentPhase: phase),
                const SizedBox(height: AppSpacing.lg),
                _ThoughtsContainer(thoughts: thoughts),
                const SizedBox(height: AppSpacing.md),
                _HintText(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 品牌标题 ───

class _BrandHeader extends StatelessWidget {
  final String title;
  final PlanningPhaseDef phaseInfo;
  const _BrandHeader({required this.title, required this.phaseInfo});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: _SpinningIcon(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          style: AppTypography.h1.copyWith(color: AppColors.text),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          phaseInfo.description,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SpinningIcon extends StatefulWidget {
  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: const Icon(Icons.refresh, color: Colors.white, size: 28),
    );
  }
}

// ─── 阶段步骤条 ───

class _PhaseStepper extends StatelessWidget {
  final String currentPhase;
  const _PhaseStepper({required this.currentPhase});

  @override
  Widget build(BuildContext context) {
    final currentIndex = kPlanningPhases.indexWhere((p) => p.key == currentPhase);

    return Row(
      children: List.generate(kPlanningPhases.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineIdx = i ~/ 2;
          final filled = lineIdx < currentIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: filled ? AppColors.primary : AppColors.border,
            ),
          );
        }
        final phaseIdx = i ~/ 2;
        final isActive = phaseIdx == currentIndex;
        final isDone = phaseIdx < currentIndex;
        return _PhaseDot(
          label: kPlanningPhases[phaseIdx].label,
          isActive: isActive,
          isDone: isDone,
        );
      }),
    );
  }
}

class _PhaseDot extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDone;
  const _PhaseDot({required this.label, required this.isActive, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isActive ? 14 : 12,
          height: isActive ? 14 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppColors.primary
                : isActive
                    ? AppColors.primaryLight
                    : AppColors.border,
          ),
          child: isDone
              ? const Icon(Icons.check, size: 10, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.micro.copyWith(
            color: isActive
                ? AppColors.text
                : isDone
                    ? AppColors.textSecondary
                    : AppColors.textMuted,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── 进度条 ───

class _ProgressBar extends StatelessWidget {
  final List<String> thoughts;
  final String currentPhase;
  const _ProgressBar({required this.thoughts, required this.currentPhase});

  @override
  Widget build(BuildContext context) {
    final percent = _calcProgress();
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 32,
          child: Text(
            '$percent%',
            style: AppTypography.micro.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  int _calcProgress() {
    if (currentPhase == 'complete') return 100;
    final idx = kPlanningPhases.indexWhere((p) => p.key == currentPhase);
    if (idx < 0) return 5;
    final thresholds = [500, 1500, 3000, 5000];
    final charLen = thoughts.join('').length;
    final prevThreshold = idx > 0 ? thresholds[idx - 1] : 0;
    final threshold = thresholds[idx];
    final base = (idx / kPlanningPhases.length) * 100;
    final phaseProgress = charLen <= prevThreshold
        ? 0.0
        : min((charLen - prevThreshold) / (threshold - prevThreshold), 1.0);
    return min((base + phaseProgress * (100 / kPlanningPhases.length)).round(), 99);
  }
}

// ─── 思考内容容器 ───

class _ThoughtsContainer extends StatefulWidget {
  final List<String> thoughts;
  const _ThoughtsContainer({required this.thoughts});

  @override
  State<_ThoughtsContainer> createState() => _ThoughtsContainerState();
}

class _ThoughtsContainerState extends State<_ThoughtsContainer> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _ThoughtsContainer old) {
    super.didUpdateWidget(old);
    if (widget.thoughts.length != old.thoughts.length ||
        (widget.thoughts.isNotEmpty && old.thoughts.isNotEmpty &&
            widget.thoughts.last != old.thoughts.last)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: widget.thoughts.isEmpty
          ? _buildEmpty()
          : _buildThoughtsList(),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _PulseDots(),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '正在建立连接...',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildThoughtsList() {
    // 只展示最近 30 条
    final visible = widget.thoughts.length > 30
        ? widget.thoughts.sublist(widget.thoughts.length - 30)
        : widget.thoughts;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: visible.length + 1, // +1 for waiting hint
      itemBuilder: (context, index) {
        if (index == visible.length) {
          return _buildWaitingHint();
        }
        final isLast = index == visible.length - 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            visible[index],
            style: AppTypography.small.copyWith(
              color: isLast ? AppColors.text : AppColors.textSecondary,
              fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
              height: 1.6,
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaitingHint() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          const _PulseDots(),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '正在规划更多内容...',
            style: AppTypography.micro.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── 底部提示 ───

class _HintText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      '正在分析需求并规划文档结构，通常需要 1-3 分钟',
      style: AppTypography.micro.copyWith(color: AppColors.textMuted),
      textAlign: TextAlign.center,
    );
  }
}

// ─── 脉冲点动画 ───

class _PulseDots extends StatefulWidget {
  const _PulseDots();

  @override
  State<_PulseDots> createState() => _PulseDotsState();
}

class _PulseDotsState extends State<_PulseDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final delay = i * 0.2;
        final t = (_ctrl.value - delay) % 1.0;
        final opacity = t < 0 ? 0.3 : (0.3 + 0.7 * sin(t * pi));
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textMuted.withOpacity(opacity.clamp(0.2, 1.0)),
          ),
        );
      }),
    );
  }
}
