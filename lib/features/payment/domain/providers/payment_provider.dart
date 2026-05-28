import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/iap/channel_detector.dart';
import '../../../../core/iap/iap_service.dart';
import '../../../../core/iap/iap_receipt_queue.dart';
import '../../../../core/iap/payment_logger.dart';
import '../../data/payment_data_source.dart';
import '../../data/models/payment_models.dart';

/// 动态商品列表 Provider，IAP 渠道查全类型并按类型分组验证 HMS，在线支付只查消耗品
final productsProvider = FutureProvider.family<List<Product>, String>((ref, channel) async {
  final ds = PaymentDataSource();
  final iapChannel = ChannelDetector.detect();
  if (iapChannel != IapChannel.official) {
    final log = PaymentLogger.instance;
    // 按类型从后端查询商品
    final byType = <String, List<Product>>{};
    for (final type in ['consumable', 'non_consumable', 'subscription']) {
      final products = await ds.getProducts(channel, productType: type);
      if (products.isNotEmpty) byType[type] = products;
    }
    final allProducts = byType.values.expand((p) => p).toList();
    log.log('Backend', '后端商品共 ${allProducts.length} 个: ${allProducts.map((p) => "${p.productId}(${p.productType})").join(", ")}');

    // 按类型分组调 HMS SDK 验证，看华为侧哪些商品存在
    final iap = IapService();
    for (final entry in byType.entries) {
      final type = entry.key;
      final ids = entry.value.map((p) => p.productId).toList();
      log.log('HMS', '查询华为商品: type=$type, ids=$ids');
      try {
        final hmsProducts = await iap.queryProducts(ids, productType: type);
        if (hmsProducts.isEmpty) {
          log.log('HMS', '⚠ 华为侧返回 0 个商品 (type=$type)');
        } else {
          for (final hp in hmsProducts) {
            log.log('HMS', '✓ ${hp.productId}: ${hp.name}, ¥${(hp.priceCents / 100).toStringAsFixed(2)}');
          }
        }
      } catch (e) {
        log.log('HMS', '查询失败: $e');
      }
    }
    return allProducts;
  }
  return await ds.getProducts(channel, productType: 'consumable');
});

/// 当前渠道 Provider
final currentChannelProvider = Provider<PaymentChannel>((ref) {
  final iapChannel = ChannelDetector.detect();
  if (iapChannel != IapChannel.official) {
    return PaymentChannel.values.firstWhere(
      (c) => c.name == iapChannel.name,
      orElse: () => PaymentChannel.alipay,
    );
  }
  return PaymentChannel.alipay;
});

/// 是否 IAP 渠道
final isIapProvider = Provider<bool>((ref) {
  return ChannelDetector.isIap;
});

/// 支付状态
class PaymentState {
  final bool isLoading;
  final OrderRecord? currentOrder;
  final String? error;
  final bool? purchaseSuccess;

  const PaymentState({this.isLoading = false, this.currentOrder, this.error, this.purchaseSuccess});

  PaymentState copyWith({
    bool? isLoading,
    OrderRecord? currentOrder,
    String? error,
    bool clearError = false,
    bool? purchaseSuccess,
  }) =>
      PaymentState(
        isLoading: isLoading ?? this.isLoading,
        currentOrder: currentOrder ?? this.currentOrder,
        error: clearError ? null : (error ?? this.error),
        purchaseSuccess: purchaseSuccess,
      );
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentDataSource _ds = PaymentDataSource();
  final IapService _iap = IapService();
  static PaymentLogger get _log => PaymentLogger.instance;

  PaymentNotifier() : super(const PaymentState());

  /// 创建订单 — 在线支付返回 pay_url，IAP 返回空
  Future<OrderRecord> createOrder({
    required PaymentChannel channel,
    required String productId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    _log.log('Order', '创建订单: channel=${channel.name}, productId=$productId, apiOrigin=${AppConstants.apiOrigin}');
    try {
      final order = await _ds.createOrder(CreateOrderRequest(
        appKey: AppConstants.appKey,
        channel: channel.name,
        productId: productId,
        sandbox: !kReleaseMode,
      ));
      state = state.copyWith(isLoading: false, currentOrder: order);
      _log.log('Order', '订单创建成功: orderNo=${order.orderNo}, type=${order.productType}, amount=${order.amountCents}');
      return order;
    } catch (e) {
      _log.log('Order', '创建订单失败: $e');
      state = state.copyWith(isLoading: false, error: '创建订单失败');
      rethrow;
    }
  }

  /// IAP 支付流程：创建订单 → 原生 SDK 支付 → 验票 → 消耗品确认消费
  Future<bool> iapPurchase({
    required String productId,
    required PaymentChannel channel,
    String productType = 'consumable',
    VoidCallback? onVerifying,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    _log.log('Pay', '═══ IAP 支付流程开始 ═══');
    _log.log('Pay', '参数: product=$productId, channel=${channel.name}, type=$productType');
    _log.log('Pay', 'API: ${AppConstants.apiOrigin}');
    String? orderNo;
    String? receiptData;
    bool confirmed = false;
    try {
      // 1. 创建订单
      _log.log('Pay', '步骤1/5: 创建订单...');
      final order = await _ds.createOrder(CreateOrderRequest(
        appKey: AppConstants.appKey,
        channel: channel.name,
        productId: productId,
        sandbox: !kReleaseMode,
      ));
      orderNo = order.orderNo;
      final actualProductType = order.productType;
      state = state.copyWith(currentOrder: order);
      _log.log('Pay', '订单OK: orderNo=${order.orderNo}, type=$actualProductType, amount=${order.amountCents}');

      // 2. 调原生 SDK 支付
      _log.log('Pay', '步骤2/5: 调用 HMS SDK 支付...');
      _log.log('Pay', 'SDK参数: channel=${_iap.channel.name}, productId=$productId, productType=$actualProductType');
      final result = await _iap.launchPayFlow(
        productId: productId,
        orderNo: order.orderNo,
        productType: actualProductType,
      );

      // 3. 支付失败/取消 → 通知后端取消订单
      if (!result.success || result.receiptData == null) {
        _log.log('Pay', '步骤2失败: ${result.error}');
        try { await _ds.cancelOrder(order.orderNo); } catch (_) {}
        state = state.copyWith(
          isLoading: false,
          error: 'HMS SDK 参数:\nproductId=$productId\norderNo=${order.orderNo}\nproductType=$actualProductType\nchannel=${channel.name}\n\n错误: ${result.error ?? "支付失败"}',
        );
        return false;
      }

      receiptData = result.receiptData!;

      // 4. 支付成功 → confirm（receipt 入库 + 状态→verifying）
      _log.log('Pay', '步骤3/5: confirm (receipt 入库)...');
      await _ds.confirmOrder(order.orderNo, receiptData);
      confirmed = true;
      onVerifying?.call();

      // 5. 写入本地防掉单队列
      final queued = QueuedReceipt(
        orderNo: order.orderNo,
        receiptData: receiptData,
        productId: productId,
        channel: channel.name,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await IapReceiptQueue.instance.enqueue(queued);
      _log.log('Pay', '已写入防掉单队列');

      // 6. 服务端验票
      _log.log('Pay', '步骤4/5: 服务端验票...');
      final verified = await _ds.verifyOrder(order.orderNo, receiptData);

      // 7. 消耗品必须 consume，否则华为侧保持"已拥有"状态，无法再次购买
      if (actualProductType == 'consumable') {
        _log.log('Pay', '步骤5/5: 消耗品 consume 确认消费...');
        final consumed = await _iap.consumePurchase(receiptData);
        _log.log('Pay', 'consume 结果: $consumed');
      } else {
        _log.log('Pay', '步骤5/5: 非消耗品，跳过 consume');
      }

      // 8. 验票成功，清除队列
      await IapReceiptQueue.instance.dequeue(order.orderNo);
      _log.log('Pay', '═══ IAP 支付完成: status=${verified.status} ═══');

      state = state.copyWith(
        isLoading: false,
        currentOrder: verified,
        purchaseSuccess: verified.isPaid,
      );
      return verified.isPaid;
    } on PlatformException catch (e) {
      _log.log('Pay', 'PlatformException: code=${e.code}, message=${e.message}');
      if (orderNo != null) { try { await _ds.cancelOrder(orderNo); } catch (_) {} }
      state = state.copyWith(isLoading: false, error: '支付失败(原生): ${e.message ?? e.code}');
      return false;
    } on MissingPluginException catch (e) {
      _log.log('Pay', 'MissingPluginException: $e');
      if (orderNo != null) { try { await _ds.cancelOrder(orderNo); } catch (_) {} }
      state = state.copyWith(isLoading: false, error: 'HMS SDK 未初始化，请确认设备支持华为支付');
      return false;
    } catch (e) {
      _log.log('Pay', '异常: $e');
      if (confirmed) {
        state = state.copyWith(
          isLoading: false,
          error: '支付已成功但验票失败，请点击"恢复购买"补全权益',
        );
      } else {
        if (orderNo != null) { try { await _ds.cancelOrder(orderNo); } catch (_) {} }
        state = state.copyWith(isLoading: false, error: '支付失败: ${e.toString()}');
      }
      return false;
    }
  }

  /// 在线支付轮询确认
  Future<bool> pollUntilPaid(String orderNo, {int maxAttempts = 90}) async {
    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final order = await _ds.getOrder(orderNo);
        state = state.copyWith(currentOrder: order);
        if (order.isPaid) {
          state = state.copyWith(purchaseSuccess: true);
          return true;
        }
        if (!order.isPending) return false;
      } catch (e) {
        debugPrint('[Payment] pollUntilPaid #$i error: $e');
        if (i >= 3) return false;
      }
    }
    return false;
  }

  /// 恢复购买
  Future<List<OrderRecord>> restorePurchases() async {
    return _ds.restorePurchases();
  }

  /// 获取配额
  Future<QuotaInfo> getQuota() async {
    return _ds.getMyQuota();
  }
}

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>(
  (ref) => PaymentNotifier(),
);
