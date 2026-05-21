import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/iap/channel_detector.dart';
import '../../../../core/iap/iap_service.dart';
import '../../../../core/iap/iap_receipt_queue.dart';
import '../../../../core/storage/local_cache.dart';
import '../../data/payment_data_source.dart';
import '../../data/models/payment_models.dart';

const _quotaCacheKey = 'user_quota';
const _quotaCacheTtl = Duration(minutes: 5);

/// 全局配额 Provider
final quotaProvider = FutureProvider<QuotaInfo>((ref) async {
  final cached =
      LocalCache.instance.getWithTtl<Map<String, dynamic>>(_quotaCacheKey);
  if (cached != null) {
    try {
      return QuotaInfo.fromJson(cached);
    } catch (_) {
      await LocalCache.instance.delete(_quotaCacheKey);
    }
  }

  final quota = await PaymentDataSource().getMyQuota();

  try {
    await LocalCache.instance
        .set(_quotaCacheKey, quota.toJson(), ttl: _quotaCacheTtl);
  } catch (_) {}

  return quota;
});

/// 动态商品列表 Provider，根据当前渠道自动加载
final productsProvider = FutureProvider.family<List<Product>, String>((ref, channel) async {
  return await PaymentDataSource().getProducts(channel);
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

  const PaymentState({this.isLoading = false, this.currentOrder, this.error});

  PaymentState copyWith({
    bool? isLoading,
    OrderRecord? currentOrder,
    String? error,
    bool clearError = false,
  }) =>
      PaymentState(
        isLoading: isLoading ?? this.isLoading,
        currentOrder: currentOrder ?? this.currentOrder,
        error: clearError ? null : (error ?? this.error),
      );
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  final PaymentDataSource _ds = PaymentDataSource();
  final IapService _iap = IapService();

  PaymentNotifier() : super(const PaymentState());

  /// 创建订单 — 在线支付返回 pay_url，IAP 返回空
  Future<OrderRecord> createOrder({
    required PaymentChannel channel,
    required String productId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final order = await _ds.createOrder(CreateOrderRequest(
        appKey: AppConstants.appKey,
        channel: channel.name,
        productId: productId,
      ));
      state = state.copyWith(isLoading: false, currentOrder: order);
      return order;
    } catch (e) {
      debugPrint('[Payment] createOrder error: $e');
      state = state.copyWith(isLoading: false, error: '创建订单失败: $e');
      rethrow;
    }
  }

  /// IAP 支付流程：创建订单 → 原生 SDK 支付 → 验票
  Future<bool> iapPurchase({
    required String productId,
    required PaymentChannel channel,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 1. 创建本地订单
      final order = await _ds.createOrder(CreateOrderRequest(
        appKey: AppConstants.appKey,
        channel: channel.name,
        productId: productId,
      ));
      state = state.copyWith(currentOrder: order);

      // 2. 调原生 SDK 支付
      final result = await _iap.launchPayFlow(
        productId: productId,
        orderNo: order.orderNo,
      );

      if (!result.success || result.receiptData == null) {
        state = state.copyWith(
          isLoading: false,
          error: result.error ?? '支付失败',
        );
        return false;
      }

      // 3. 🚨 写入本地防掉单挂起凭证队列
      final queued = QueuedReceipt(
        orderNo: order.orderNo,
        receiptData: result.receiptData!,
        productId: productId,
        channel: channel.name,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await IapReceiptQueue.instance.enqueue(queued);

      // 4. 服务端验票并发货
      final verified = await _ds.verifyOrder(order.orderNo, result.receiptData!);
      
      // 5. 🚨 验票成功，从本地防掉单队列中安全擦除
      await IapReceiptQueue.instance.dequeue(order.orderNo);

      state = state.copyWith(
        isLoading: false,
        currentOrder: verified,
      );
      return verified.isPaid;
    } catch (e) {
      debugPrint('[Payment] iapPurchase error: $e');
      state = state.copyWith(
        isLoading: false, 
        error: '支付已成功，但网络较慢。请稍后点击上方【恢复购买】确认会员状态',
      );
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
        if (order.isPaid) return true;
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
