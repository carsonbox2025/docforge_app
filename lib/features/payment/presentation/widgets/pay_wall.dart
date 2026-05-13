import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../scene/data/models/scene_models.dart';
import '../../data/payment_data_source.dart';
import '../../data/models/payment_models.dart';
import '../../domain/providers/payment_provider.dart';

/// 支付墙弹窗 — 付费场景点击"生成"时弹出
class PayWall extends ConsumerStatefulWidget {
  final SceneConfig scene;
  final VoidCallback onPaid;

  const PayWall({super.key, required this.scene, required this.onPaid});

  static Future<void> show(
    BuildContext context, {
    required SceneConfig scene,
    required VoidCallback onPaid,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PayWall(scene: scene, onPaid: onPaid),
    );
  }

  @override
  ConsumerState<PayWall> createState() => _PayWallState();
}

enum _PayStep { idle, paying, waiting, confirming, done }

class _PayWallState extends ConsumerState<PayWall> {
  PaymentChannel _channel = PaymentChannel.alipay;
  _PayStep _step = _PayStep.idle;
  String? _orderNo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽条
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              _buildTitle(),
              const SizedBox(height: 16),
              // 场景 + 定价
              _buildPriceCard(),
              const SizedBox(height: 20),
              // 渠道选择（idle / paying 态显示）
              if (_step == _PayStep.idle || _step == _PayStep.paying)
                _buildChannelSelector(),
              if (_step == _PayStep.idle || _step == _PayStep.paying)
                const SizedBox(height: 20),
              // 主操作按钮
              _buildActionButton(),
              const SizedBox(height: 12),
              // 提示
              if (_step != _PayStep.done)
                Text(
                  _step == _PayStep.waiting || _step == _PayStep.confirming
                      ? '支付完成后点击上方按钮确认'
                      : '支付成功前不扣费 · 满意后再付款 · 支持开发票',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted.withValues(alpha: 0.8)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    if (_step == _PayStep.done) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 22),
          const SizedBox(width: 8),
          Text('支付成功',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.success)),
        ],
      );
    }
    return Text(
      _step == _PayStep.waiting || _step == _PayStep.confirming
          ? '等待支付确认' : '确认支付',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            widget.scene.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
          ),
          const SizedBox(width: 12),
          Text(
            widget.scene.pricing.displayPrice,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          const Text('/篇', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildChannelSelector() {
    return Row(
      children: [
        Expanded(
          child: _ChannelCard(
            label: '支付宝',
            brandIcon: '支',
            brandColor: const Color(0xFF1677FF),
            isActive: _channel == PaymentChannel.alipay,
            enabled: _step == _PayStep.idle,
            onTap: () => setState(() => _channel = PaymentChannel.alipay),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ChannelCard(
            label: '微信支付',
            brandIcon: '微',
            brandColor: const Color(0xFF07C160),
            isActive: _channel == PaymentChannel.wechat,
            enabled: _step == _PayStep.idle,
            onTap: () => setState(() => _channel = PaymentChannel.wechat),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    switch (_step) {
      case _PayStep.idle:
        return _PayButton(
          label: '确认支付 ${widget.scene.pricing.displayPrice}',
          onPressed: _handlePay,
        );
      case _PayStep.paying:
        return const _PayButton(
          label: '正在创建订单...',
          loading: true,
        );
      case _PayStep.waiting:
        return _PayButton(
          label: '我已完成支付',
          onPressed: _handleManualConfirm,
          outlined: true,
        );
      case _PayStep.confirming:
        return const _PayButton(
          label: '正在查询支付状态...',
          loading: true,
        );
      case _PayStep.done:
        return const SizedBox.shrink();
    }
  }

  Future<void> _handlePay() async {
    setState(() => _step = _PayStep.paying);
    try {
      final order = await ref.read(paymentProvider.notifier).createOrder(
            channel: _channel,
            sceneId: widget.scene.sceneId,
            orderType: 'per_doc',
          );
      _orderNo = order.orderNo;

      if (order.payUrl != null && order.payUrl!.isNotEmpty) {
        final launched = await launchUrl(Uri.parse(order.payUrl!));
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('无法打开支付页面，请检查网络'), backgroundColor: AppColors.warn),
          );
        }
      }

      if (mounted) setState(() => _step = _PayStep.waiting);
    } catch (e) {
      if (mounted) {
        setState(() => _step = _PayStep.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('创建订单失败，请重试'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleManualConfirm() async {
    if (_orderNo == null) return;
    setState(() => _step = _PayStep.confirming);
    try {
      final paid = await ref.read(paymentProvider.notifier).pollUntilPaid(_orderNo!, maxAttempts: 5);
      if (paid) {
        widget.onPaid();
        if (mounted) {
          setState(() => _step = _PayStep.done);
          await Future.delayed(const Duration(milliseconds: 600));
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          setState(() => _step = _PayStep.waiting);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('暂未检测到支付成功，请稍后再试'),
              backgroundColor: AppColors.warn,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _step = _PayStep.waiting);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('查询支付状态失败，请重试'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _PayButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool outlined;
  final VoidCallback? onPressed;

  const _PayButton({
    required this.label,
    this.loading = false,
    this.outlined = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));

    if (outlined) {
      return SizedBox(
        width: double.infinity, height: 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          child: child,
        ),
      );
    }
    return SizedBox(
      width: double.infinity, height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final String label;
  final String brandIcon;
  final Color brandColor;
  final bool isActive;
  final bool enabled;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.label,
    required this.brandIcon,
    required this.brandColor,
    required this.isActive,
    this.enabled = true,
    required this.onTap,
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
                child: Text(
                  brandIcon,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
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
    );
  }
}
