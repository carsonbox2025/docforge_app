import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/iap/channel_detector.dart';
import '../../../../core/iap/iap_receipt_queue.dart';
import '../../../../core/iap/iap_service.dart';
import '../../../../core/iap/payment_logger.dart';
import '../../data/models/membership_models.dart';
import '../../../payment/data/payment_data_source.dart';
import '../../../payment/data/models/payment_models.dart';
import '../../../payment/domain/providers/payment_provider.dart';
import '../../../scene/data/models/scene_models.dart';
import '../../../scene/domain/providers/scene_provider.dart';

/// 订阅下单结果：包含支付宝 URL 或微信 APP 调起参数
class PaymentLaunchResult {
  final String? payUrl;
  final Map<String, String>? payParams;
  const PaymentLaunchResult({this.payUrl, this.payParams});
}

class MembershipState {
  final QuotaInfo? quota;
  final List<Product> subscriptionProducts;
  final int selectedProductIndex;
  final PaymentChannel channel;
  final bool isLoading;
  final int totalScenes;
  final String? successMessage;
  final String? errorMessage;

  const MembershipState({
    this.quota,
    this.subscriptionProducts = const [],
    this.selectedProductIndex = 0,
    this.channel = PaymentChannel.alipay,
    this.isLoading = false,
    this.totalScenes = 0,
    this.successMessage,
    this.errorMessage,
  });

  Product? get selectedProduct =>
      subscriptionProducts.isNotEmpty ? subscriptionProducts[selectedProductIndex.clamp(0, subscriptionProducts.length - 1)] : null;

  List<BenefitItem> buildBenefits(List<SceneConfig> scenes) {
    final items = <BenefitItem>[];
    for (final scene in scenes) {
      items.add(BenefitItem(
        name: scene.name,
        freeValue: scene.pricing.isFree ? '免费' : '1次体验',
        proValue: '不限',
        isFreeChecked: true,
        isProChecked: true,
      ));
    }
    items.addAll([
      const BenefitItem(name: '文档精修', freeValue: '—', proValue: '∞', isFreeChecked: false),
      const BenefitItem(name: '多语言翻译', freeValue: '—', proValue: '6种语言', isFreeChecked: false),
      const BenefitItem(name: '导出格式', freeValue: 'Word', proValue: 'Word/PDF/HTML', isFreeChecked: true),
      const BenefitItem(name: 'AI响应速度', freeValue: '标准', proValue: '优先', isFreeChecked: true),
    ]);
    return items;
  }

  bool get isIap => ChannelDetector.isIap;

  MembershipState copyWith({
    QuotaInfo? quota,
    List<Product>? subscriptionProducts,
    int? selectedProductIndex,
    PaymentChannel? channel,
    bool? isLoading,
    int? totalScenes,
    String? successMessage,
    bool clearSuccess = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MembershipState(
      quota: quota ?? this.quota,
      subscriptionProducts: subscriptionProducts ?? this.subscriptionProducts,
      selectedProductIndex: selectedProductIndex ?? this.selectedProductIndex,
      channel: channel ?? this.channel,
      isLoading: isLoading ?? this.isLoading,
      totalScenes: totalScenes ?? this.totalScenes,
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MembershipNotifier extends StateNotifier<MembershipState> {
  final PaymentDataSource _paymentDs;
  final Ref _ref;
  bool _cancelled = false;
  bool _initialized = false;

  MembershipNotifier(this._ref, this._paymentDs) : super(const MembershipState());

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    // IAP 渠道自动检测并设置
    final iapChannel = ChannelDetector.detect();
    if (iapChannel != IapChannel.official) {
      final mapped = PaymentChannel.values.firstWhere(
        (c) => c.name == iapChannel.name,
        orElse: () => PaymentChannel.alipay,
      );
      state = state.copyWith(channel: mapped);
    }

    await Future.wait([
      _loadSceneStats().catchError((e) => debugPrint('[Membership] _loadSceneStats failed: $e')),
      loadQuota().catchError((e) => debugPrint('[Membership] loadQuota failed: $e')),
      _loadSubscriptionProducts().catchError((e) => debugPrint('[Membership] _loadSubscriptionProducts failed: $e')),
    ]);
  }

  Future<void> _loadSubscriptionProducts() async {
    try {
      final channel = state.channel.name;
      List<Product> products;
      if (state.isIap) {
        // IAP 渠道：查全类型（华为等渠道的商品可能是 consumable/non_consumable）
        final consumables = await _paymentDs.getProducts(channel, productType: 'consumable');
        final nonConsumables = await _paymentDs.getProducts(channel, productType: 'non_consumable');
        final subscriptions = await _paymentDs.getProducts(channel, productType: 'subscription');
        products = [...consumables, ...nonConsumables, ...subscriptions];
      } else {
        products = await _paymentDs.getProducts(channel, productType: 'subscription');
      }
      if (!mounted) return;
      state = state.copyWith(subscriptionProducts: products);
      debugPrint('[Membership] 加载商品: ${products.length} 个, channel=$channel, isIap=${state.isIap}');
      for (final p in products) {
        debugPrint('[Membership]   ${p.productId} | ${p.productType} | ${p.name} | ${p.priceCents}分');
      }
    } catch (e) {
      debugPrint('[Membership] 加载商品失败: $e');
    }
  }

  Future<void> _loadSceneStats() async {
    try {
      final scenes = await _ref.read(sceneListProvider.future);
      if (!mounted) return;
      state = state.copyWith(totalScenes: scenes.length);
    } catch (e) {
      debugPrint('[Membership] _loadSceneStats error: $e');
    }
  }

  Future<void> loadQuota() async {
    try {
      final quota = await _paymentDs.getMyQuota();
      state = state.copyWith(quota: quota);
    } catch (e) {
      debugPrint('[Membership] loadQuota error: $e');
    }
  }

  void selectProduct(int index) {
    state = state.copyWith(selectedProductIndex: index, clearError: true, clearSuccess: true);
  }

  void selectChannel(PaymentChannel ch) {
    state = state.copyWith(channel: ch, clearError: true, clearSuccess: true);
  }

  void cancelSubscribe() {
    _cancelled = true;
    state = state.copyWith(isLoading: false);
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  /// 订阅 — 自动分流 IAP / 在线支付
  Future<PaymentLaunchResult?> subscribe() async {
    _cancelled = false;
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      if (state.isIap) {
        return await _subscribeIap();
      } else {
        return await _subscribeOnline();
      }
    } catch (e) {
      debugPrint('[Membership] subscribe error: $e');
      if (mounted) state = state.copyWith(isLoading: false, errorMessage: '下单失败，请重试');
      return null;
    }
  }

  /// IAP 支付流程 — 直接用配置表的商品参数
  Future<PaymentLaunchResult?> _subscribeIap() async {
    final notifier = _ref.read(paymentProvider.notifier);
    final channel = state.channel;
    final product = state.selectedProduct;

    if (product == null) {
      state = state.copyWith(isLoading: false, errorMessage: '无可用订阅商品，请检查商品配置');
      return null;
    }

    debugPrint('[Membership] IAP 支付: productId=${product.productId}, productType=${product.productType}, name=${product.name}');

    final success = await notifier.iapPurchase(
      productId: product.productId,
      channel: channel,
      productType: product.productType,
      onVerifying: () {
        state = state.copyWith(
          isLoading: false,
          successMessage: '支付成功，正在安全确认...',
        );
      },
    );
    if (!mounted) return null;

    if (success) {
      await loadQuota();
      _invalidateGlobalQuota();
      state = state.copyWith(
        isLoading: false,
        successMessage: '订阅成功！已激活${product.name}',
      );
    } else {
      final error = _ref.read(paymentProvider).error ?? '';
      if (error.contains('已购买') || error.contains('ALREADY_OWNED') || error.contains('恢复购买')) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '您已购买过此商品，请点击"恢复购买"完成激活',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.isNotEmpty ? error : '支付未完成',
        );
      }
    }
    return null;
  }

  /// 在线支付流程
  Future<PaymentLaunchResult?> _subscribeOnline() async {
    final product = state.selectedProduct;
    if (product == null) {
      state = state.copyWith(isLoading: false, errorMessage: '无可用订阅商品');
      return null;
    }
    final notifier = _ref.read(paymentProvider.notifier);
    final order = await notifier.createOrder(
      channel: state.channel,
      productId: product.productId,
    );

    _pollOrder(order.orderNo);

    return PaymentLaunchResult(
      payUrl: order.payUrl,
      payParams: order.payParams,
    );
  }

  /// 后台轮询订单状态
  Future<void> _pollOrder(String orderNo) async {
    for (var i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || _cancelled) return;
      try {
        final updated = await _paymentDs.getOrder(orderNo);
        if (updated.isPaid) {
          await loadQuota();
          _invalidateGlobalQuota();
          state = state.copyWith(
            isLoading: false,
            successMessage: '订阅成功！已激活Pro会员',
          );
          return;
        }
        if (!updated.isPending) return;
      } catch (e) {
        debugPrint('[Membership] poll order error: $e');
        if (i >= 5) break;
      }
    }
    if (mounted) state = state.copyWith(isLoading: false, errorMessage: '支付确认超时，请稍后查看会员状态');
  }

  /// 恢复购买：先查后端数据库，查不到再从 HMS 服务器拉已购记录
  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      int restored = 0;
      int verifying = 0;

      // 1. 先处理本地防掉单队列
      await IapReceiptQueue.instance.processPendingQueue();

      // 2. 查后端数据库已有订单
      final notifier = _ref.read(paymentProvider.notifier);
      final serverOrders = await notifier.restorePurchases();
      restored += serverOrders.where((o) => o.isPaid).length;
      verifying += serverOrders.where((o) => o.isVerifying).length;

      // 3. 数据库没找到 → 从 HMS 服务器拉已购记录（按实际商品类型查询）
      if (restored == 0 && verifying == 0 && state.isIap) {
        final iap = IapService();
        final log = PaymentLogger.instance;
        List<Map<String, dynamic>> purchases = [];
        String? hmsError;

        // 3a. 优先用 queryPendingPurchases 查询未确认订单
        try {
          for (final type in ['consumable', 'non_consumable', 'subscription']) {
            try {
              log.log('Restore', '查询未确认订单: type=$type');
              final pending = await iap.queryPendingPurchases(productType: type);
              log.log('Restore', '未确认订单 $type: ${pending.length} 条');
              purchases.addAll(pending);
            } on PlatformException catch (e) {
              log.log('Restore', '未确认订单查询 $type 失败: code=${e.code}, msg=${e.message}');
            } catch (e) {
              log.log('Restore', '未确认订单查询 $type 异常: $e');
            }
          }
          debugPrint('[Membership] 未确认订单: ${purchases.length} 条');
        } catch (e) {
          log.log('Restore', '查询未确认订单失败: $e');
        }

        // 3b. 如果未确认订单也没找到，再用 obtainOwnedPurchaseRecord 查已完成记录
        if (purchases.isEmpty) {
          try {
            for (final type in ['consumable', 'non_consumable', 'subscription']) {
              try {
                log.log('Restore', '查询 HMS 已购: type=$type');
                final records = await iap.restorePurchases(productType: type);
                log.log('Restore', 'HMS 返回 $type: ${records.length} 条');
                purchases.addAll(records);
              } on PlatformException catch (e) {
                log.log('Restore', 'HMS 查询 $type 失败: code=${e.code}, msg=${e.message}');
              } catch (e) {
                log.log('Restore', 'HMS 查询 $type 异常: $e');
              }
            }
            debugPrint('[Membership] HMS 已购记录: ${purchases.length} 条');
          } catch (e) {
            hmsError = e.toString();
            debugPrint('[Membership] HMS 查询失败: $e');
          }
        }

        if (purchases.isEmpty && hmsError != null) {
          // HMS 查询本身就失败了
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'HMS 查询失败: $hmsError',
          );
          return;
        }

        for (final purchase in purchases) {
          final purchaseToken = purchase['purchaseToken'] as String? ?? '';
          final productId = purchase['productId'] as String? ?? '';
          if (purchaseToken.isEmpty) continue;

          try {
            debugPrint('[Membership] HMS 恢复验票: productId=$productId');
            final order = await _paymentDs.createOrder(CreateOrderRequest(
              appKey: AppConstants.appKey,
              channel: state.channel.name,
              productId: productId,
              sandbox: !kReleaseMode,
            ));
            await _paymentDs.confirmOrder(order.orderNo, purchaseToken);
            final verified = await _paymentDs.verifyOrder(order.orderNo, purchaseToken);
            if (verified.isPaid) {
              restored++;
              // 消耗品需要 consume 闭环，否则华为侧保持"已拥有"
              try {
                final iap = IapService();
                if (verified.productType == 'consumable') {
                  await iap.consumePurchase(purchaseToken);
                }
              } catch (e) {
                debugPrint('[Membership] 恢复 consume 失败(非致命): $e');
              }
            } else if (verified.isVerifying) {
              verifying++;
            }
          } catch (e) {
            debugPrint('[Membership] HMS 恢复验票失败: $e');
          }
        }

        if (purchases.isEmpty && restored == 0 && verifying == 0) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: '华为端无已购记录，后端也无订单数据',
          );
          return;
        }
      }

      await loadQuota();
      _invalidateGlobalQuota();
      if (!mounted) return;

      if (restored > 0) {
        state = state.copyWith(
          isLoading: false,
          successMessage: '已恢复 $restored 笔购买记录',
        );
      } else if (verifying > 0) {
        state = state.copyWith(
          isLoading: false,
          successMessage: '发现 $verifying 笔待确认订单，系统正在自动处理中',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '未找到可恢复的购买记录',
        );
      }
    } catch (e) {
      debugPrint('[Membership] restorePurchases error: $e');
      if (mounted) state = state.copyWith(isLoading: false, errorMessage: '恢复购买失败: $e');
    }
  }

  void _invalidateGlobalQuota() {
    _ref.invalidate(quotaProvider);
  }
}

/// 全局唯一配额状态 — 供 profile/usage 等模块共用
class QuotaState {
  final QuotaInfo? data;
  final bool isLoading;
  final String? error;

  const QuotaState({this.data, this.isLoading = false, this.error});

  QuotaState copyWith({QuotaInfo? data, bool? isLoading, String? error}) {
    return QuotaState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isPro => data?.isPro ?? false;
}

class QuotaNotifier extends StateNotifier<QuotaState> {
  final PaymentDataSource _ds;

  QuotaNotifier(this._ds) : super(const QuotaState());

  Future<void> loadQuota() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final quota = await _ds.getMyQuota();
      if (!mounted) return;
      state = state.copyWith(data: quota, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadQuota();
  }
}

/// 全局配额 Provider — 统一入口，替代旧 profile/quota_provider 和 payment/quotaProvider
final quotaProvider = StateNotifierProvider<QuotaNotifier, QuotaState>((ref) {
  final notifier = QuotaNotifier(PaymentDataSource());
  notifier.loadQuota();
  return notifier;
});

final membershipProvider =
    StateNotifierProvider<MembershipNotifier, MembershipState>((ref) {
  final paymentDs = PaymentDataSource();
  return MembershipNotifier(ref, paymentDs);
});
