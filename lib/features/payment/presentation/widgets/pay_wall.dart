import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_cache.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/iap/iap_receipt_queue.dart';
import '../../../../core/iap/channel_detector.dart';
import '../../../../core/iap/iap_service.dart';
import '../../../../core/iap/payment_logger.dart';
import '../../../membership/data/models/membership_models.dart';
import '../../../scene/data/models/scene_models.dart';
import '../../data/models/payment_models.dart';
import '../../domain/providers/payment_provider.dart';
import '../../../membership/domain/providers/membership_provider.dart';
import '../../../../shared/widgets/payment_channel_card.dart';

/// 支付墙弹窗 — 月额度耗尽时弹出，提供单次购买或升级会员
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

enum _PayStep { idle, paying, verifying, waiting, confirming, done }

class _PayWallState extends ConsumerState<PayWall>
    with WidgetsBindingObserver {
  PaymentChannel _channel = PaymentChannel.alipay;
  _PayStep _step = _PayStep.idle;
  String? _orderNo;
  bool _showLogPanel = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    IapReceiptQueue.instance.processPendingQueue();
    PaymentLogger.instance.addListener(_onLogUpdate);
    // 打开时记录关键状态
    final log = PaymentLogger.instance;
    log.log('PayWall', '支付墙打开');
    final channel = ChannelDetector.detect();
    log.log('PayWall', '检测渠道: $channel, isIap=${channel != IapChannel.official}');
    log.log('PayWall', 'apiOrigin: ${AppConstants.apiOrigin}');
    log.log('PayWall', 'sceneId: ${widget.scene.sceneId}, sceneName: ${widget.scene.name}');
  }

  void _onLogUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PaymentLogger.instance.removeListener(_onLogUpdate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 支付宝：用户从支付宝 App 返回时自动查询订单状态
    if (state == AppLifecycleState.resumed &&
        _orderNo != null &&
        _step == _PayStep.waiting &&
        _channel == PaymentChannel.alipay) {
      _handleManualConfirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIap = ref.watch(isIapProvider);
    final channel = ref.watch(currentChannelProvider);
    final productsAsync = ref.watch(productsProvider(channel.name));

    // 如果是IAP渠道，将选中的渠道强制设为当前的系统检测渠道
    if (isIap && _channel != channel) {
      setState(() {
        _channel = channel;
      });
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽条
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // 顶部工具栏
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showHelpDialog(context),
                      icon: const Icon(Icons.help_outline, size: 14, color: AppColors.textMuted),
                      label: const Text('常见问题', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ),
                    if (isIap)
                      TextButton.icon(
                        onPressed: () => _handleRestore(context),
                        icon: const Icon(Icons.restore_page_outlined, size: 14, color: AppColors.primary),
                        label: const Text(
                          '恢复购买',
                          style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // 标题
                _buildTitle(),
                const SizedBox(height: 16),

                // 会员尊享金色流光特权卡片
                _buildPremiumFeatureCard(),
                const SizedBox(height: 16),

                // 动态商品展示区 (骨架屏与卡片融合)
                productsAsync.when(
                  data: (products) => _buildPriceCard(products),
                  loading: () => _buildProductSkeleton(),
                  error: (err, _) => _buildLocalFallbackPriceCard(),
                ),
                const SizedBox(height: 16),

                // 渠道选择（仅在线支付渠道显示）
                if (!isIap && (_step == _PayStep.idle || _step == _PayStep.paying))
                  _buildChannelSelector(),
                if (!isIap && (_step == _PayStep.idle || _step == _PayStep.paying))
                  const SizedBox(height: 20),

                // 主操作按钮
                _buildActionButton(),
                const SizedBox(height: 12),

                // 提示
                if (_step != _PayStep.done)
                  Text(
                    _step == _PayStep.waiting || _step == _PayStep.confirming
                        ? '支付完成后点击上方按钮确认'
                        : '支付安全保障 · 满意后再付款 · 支持开具增值税发票',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted.withOpacity(0.8)),
                  ),

                // 日志面板切换按钮
                if (_step != _PayStep.done) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _showLogPanel = !_showLogPanel),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showLogPanel ? Icons.expand_less : Icons.bug_report,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showLogPanel ? '收起日志' : '调试日志 (${PaymentLogger.instance.entries.length})',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],

                // 日志面板
                if (_showLogPanel) ...[
                  const SizedBox(height: 8),
                  _buildLogPanel(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    if (_step == _PayStep.done) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 22),
          SizedBox(width: 8),
          Text('支付成功',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.success)),
        ],
      );
    }
    if (_step == _PayStep.verifying) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          SizedBox(width: 8),
          Text('支付成功，正在安全确认...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      );
    }
    return Text(
      _step == _PayStep.waiting || _step == _PayStep.confirming
          ? '等待支付确认' : '额度已用尽',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
    );
  }

  Widget _buildPremiumFeatureCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF6D365), Color(0xFFFDA085)], // 尊贵流金渐变
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFDA085).withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, size: 24, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                '升级 Pro 会员 · 全面释放生产力',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/subscription');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '查看 ${PlanType.monthly.price}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE56C00)),
                      ),
                      const Icon(Icons.chevron_right, size: 12, color: Color(0xFFE56C00)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildFeatureRow('✨ 高端精美文档渲染，支持专业双语翻译排版'),
          _buildFeatureRow('🚀 专属 GPU 优先生成通道，快达 3 秒响应'),
          _buildFeatureRow('📁 独享 10GB 云端文档存储及全格式一键导出'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          const Icon(Icons.check, size: 12, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(List<Product> products) {
    // 尝试寻找匹配当前场景的商品
    Product? matched;
    for (final p in products) {
      if (p.productId == widget.scene.sceneId) {
        matched = p;
        break;
      }
    }

    // IAP 渠道：如果没有精确匹配，使用第一个可用商品（如月度会员）
    final isIap = ref.watch(isIapProvider);
    if (matched == null && isIap && products.isNotEmpty) {
      matched = products.first;
    }

    final displayPrice = matched?.displayPrice ?? widget.scene.pricing.displayPrice;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryBg.withOpacity(0.4),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.description_outlined, size: 22, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            widget.scene.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
          const SizedBox(width: 12),
          Text(
            displayPrice,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
          ),
          const Text('/篇', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildLocalFallbackPriceCard() {
    return _buildPriceCard(const []);
  }

  Widget _buildProductSkeleton() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Container(
            width: 80,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Spacer(),
          Container(
            width: 60,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelSelector() {
    return Row(
      children: [
        Expanded(
          child: PaymentChannelCard(
            label: '支付宝',
            svgIcon: 'assets/icons/alipay.svg',
            brandColor: const Color(0xFF1677FF),
            isActive: _channel == PaymentChannel.alipay,
            enabled: _step == _PayStep.idle,
            onTap: () => setState(() => _channel = PaymentChannel.alipay),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PaymentChannelCard(
            label: '微信支付',
            svgIcon: 'assets/icons/wechat_pay.svg',
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
          label: '确认支付',
          onPressed: _handlePay,
        );
      case _PayStep.paying:
        return const _PayButton(
          label: '正在安全创建订单...',
          loading: true,
        );
      case _PayStep.verifying:
        return const _PayButton(
          label: '正在安全确认支付结果...',
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
          label: '正在安全验证支付状态...',
          loading: true,
        );
      case _PayStep.done:
        return const SizedBox.shrink();
    }
  }

  Future<void> _handlePay() async {
    setState(() => _step = _PayStep.paying);
    final isIap = ref.read(isIapProvider);

    try {
      if (isIap) {
        // IAP 渠道：从后台商品列表获取实际商品 ID（可能与场景 ID 不同）
        final channel = ref.read(currentChannelProvider);
        final productsAsync = ref.read(productsProvider(channel.name));
        String iapProductId = widget.scene.sceneId; // 默认用场景 ID
        productsAsync.whenData((products) {
          if (products.isNotEmpty) {
            // 优先匹配场景 ID，否则用第一个商品（如月度会员）
            final matched = products.where((p) => p.productId == widget.scene.sceneId);
            iapProductId = matched.isNotEmpty ? matched.first.productId : products.first.productId;
          }
        });

        debugPrint('[PayWall] IAP 支付: sceneId=${widget.scene.sceneId}, iapProductId=$iapProductId');
        final success = await ref.read(paymentProvider.notifier).iapPurchase(
          productId: iapProductId,
          channel: _channel,
          onVerifying: () {
            if (mounted) setState(() => _step = _PayStep.verifying);
          },
        );
        if (success) {
          await LocalCache.instance.delete('user_quota');
          ref.invalidate(quotaProvider);
          widget.onPaid();
          if (mounted) {
            setState(() => _step = _PayStep.done);
            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) Navigator.of(context).pop();
          }
        } else {
          final err = ref.read(paymentProvider).error;
          debugPrint('[PayWall] IAP 支付失败: $err');
          if (mounted) {
            setState(() => _step = _PayStep.idle);
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: SingleChildScrollView(
                  child: Text(err ?? '支付失败，请重试'),
                ),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 8),
              ),
            );
          }
        }
      } else {
        // 在线支付链路
        final order = await ref.read(paymentProvider.notifier).createOrder(
          channel: _channel,
          productId: widget.scene.sceneId,
        );
        _orderNo = order.orderNo;

        if (_channel == PaymentChannel.wechat && order.payParams != null) {
          await _launchWechatPay(order.payParams!);
        } else if (order.payUrl != null && order.payUrl!.isNotEmpty) {
          final uri = Uri.parse(order.payUrl!);
          if (!uri.scheme.startsWith('https') && !uri.scheme.startsWith('alipays')) {
            throw ArgumentError('不安全的支付链接');
          }
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!launched && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('无法打开外部支付页面，请确保安装了相应支付应用'), backgroundColor: AppColors.warn),
            );
          }
        }

        if (mounted) setState(() => _step = _PayStep.waiting);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _step = _PayStep.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下单失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _launchWechatPay(Map<String, String> params) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('微信支付暂不可用，请选择支付宝支付'), backgroundColor: AppColors.warn),
      );
      setState(() => _step = _PayStep.idle);
    }
  }

  Future<void> _handleManualConfirm() async {
    if (_orderNo == null) return;
    setState(() => _step = _PayStep.confirming);
    try {
      final paid = await ref.read(paymentProvider.notifier).pollUntilPaid(_orderNo!, maxAttempts: 25);
      if (paid) {
        await LocalCache.instance.delete('user_quota');
        ref.invalidate(quotaProvider);
        widget.onPaid();
        if (mounted) {
          setState(() => _step = _PayStep.done);
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          setState(() => _step = _PayStep.waiting);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('暂未检测到微信/支付宝确认消息，请稍后再试'),
              backgroundColor: AppColors.warn,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _step = _PayStep.waiting);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('查询支付状态超时，请点击“我已完成支付”重试'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    // 商店上架要求强校验的”恢复购买”
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      // 1. 处理本地未发送成功的掉单队列
      await IapReceiptQueue.instance.processPendingQueue();
      // 2. 从服务端检索已购买的非消耗品和有效订阅
      await ref.read(paymentProvider.notifier).restorePurchases();
      // 3. 刷新配额状态
      await LocalCache.instance.delete('user_quota');
      ref.invalidate(quotaProvider);

      // 4. [调试] 查询 HMS 已购记录并显示
      if (ChannelDetector.isIap) {
        try {
          final iap = IapService();
          final log = PaymentLogger.instance;
          final allRecords = <Map<String, dynamic>>[];
          for (final type in ['consumable', 'non_consumable', 'subscription']) {
            try {
              final pending = await iap.queryPendingPurchases(productType: type);
              allRecords.addAll(pending.map((r) => {...r, '_source': '未确认($type)'}));
            } catch (_) {}
            try {
              final records = await iap.restorePurchases(productType: type);
              allRecords.addAll(records.map((r) => {...r, '_source': '已购($type)'}));
            } catch (_) {}
          }
          if (mounted) {
            Navigator.of(context).pop();
            if (allRecords.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('HMS 无已购记录'), backgroundColor: Colors.orange),
              );
            } else {
              final lines = allRecords.map((r) {
                final source = r.remove('_source');
                return '[$source]\n${r.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}';
              }).join('\n\n');
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('HMS 已购记录', style: TextStyle(fontSize: 14)),
                  content: Text(lines, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('关闭'))],
                ),
              );
            }
          }
          return;
        } catch (e) {
          PaymentLogger.instance.log('Restore', 'HMS 查询异常: $e');
        }
      }

      if (mounted) {
        Navigator.of(context).pop(); // 关闭 loading 框
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('购买状态恢复成功！已同步最新配额'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭 loading 框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('恢复购买失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildLogPanel() {
    final entries = PaymentLogger.instance.entries;
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('支付流程日志', style: TextStyle(fontSize: 11, color: Color(0xFF00FF00), fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                GestureDetector(
                  onTap: () {
                    PaymentLogger.instance.clear();
                  },
                  child: const Text('清空', style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF333333)),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('暂无日志', style: TextStyle(fontSize: 11, color: Color(0xFF666666))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      Color tagColor;
                      switch (e.tag) {
                        case 'Channel': tagColor = const Color(0xFF61AFEF); break;
                        case 'IAP': tagColor = const Color(0xFFE5C07B); break;
                        case 'Pay': tagColor = const Color(0xFF98C379); break;
                        case 'Order': tagColor = const Color(0xFFC678DD); break;
                        default: tagColor = const Color(0xFFABB2BF);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFFABB2BF)),
                            children: [
                              TextSpan(text: '${e.time.toIso8601String().substring(11, 19)} ', style: const TextStyle(color: Color(0xFF666666))),
                              TextSpan(text: '[${e.tag}]', style: TextStyle(color: tagColor, fontWeight: FontWeight.bold)),
                              TextSpan(text: ' ${e.message}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于付费的常见问题', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Q: 购买单篇后多久有效？', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('A: 购买属于非消耗品模式，本篇文档在生成和后续无限次修改导出中均不会再次收费。', style: TextStyle(fontSize: 12)),
              SizedBox(height: 10),
              Text('Q: 充值扣款成功，但是页面没有变化？', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('A: 可能因当前网络较慢导致服务器响应延迟，您可尝试点击右上角【恢复购买】按钮，系统将立即重新对账并恢复您的会员权益。', style: TextStyle(fontSize: 12)),
              SizedBox(height: 10),
              Text('Q: 支持开具发票吗？', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('A: 支持。在“个人中心 - 我的账单 - 申请开票”中可自助申请电子增值税发票，财务将在3个工作日内开具。', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
          disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          elevation: 0,
        ),
        child: child,
      ),
    );
  }
}
