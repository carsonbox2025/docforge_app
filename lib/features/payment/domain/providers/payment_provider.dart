import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/iap/channel_detector.dart';
import '../../../../core/iap/iap_service.dart';
import '../../../../core/iap/iap_receipt_queue.dart';
import '../../data/payment_data_source.dart';
import '../../data/models/payment_models.dart';

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
      state = state.copyWith(isLoading: false, error: '创建订单失败');
      rethrow;
    }
  }

  /// IAP 支付流程：创建订单 → 原生 SDK 支付 → 验票
  Future<bool> iapPurchase({
    required String productId,
    required PaymentChannel channel,
    String productType = 'consumable',
    VoidCallback? onVerifying,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    debugPrint('[Payment] iapPurchase 开始: product=$productId, channel=${channel.name}');
    String? orderNo;
    bool confirmed = false;
    try {
      // 1. 创建订单
      debugPrint('[Payment] 步骤1: 创建订单...');
      final order = await _ds.createOrder(CreateOrderRequest(
        appKey: AppConstants.appKey,
        channel: channel.name,
        productId: productId,
      ));
      orderNo = order.orderNo;
      state = state.copyWith(currentOrder: order);

      // 2. 调原生 SDK 支付
      debugPrint('[Payment] 步骤2: HMS SDK 支付...');
      final result = await _iap.launchPayFlow(
        productId: productId,
        orderNo: order.orderNo,
        productType: order.productType,
      );

      // 3. 支付失败/取消 → 通知后端取消订单
      if (!result.success || result.receiptData == null) {
        debugPrint('[Payment] 步骤2失败: ${result.error}');
        try { await _ds.cancelOrder(order.orderNo); } catch (_) {}
        state = state.copyWith(
          isLoading: false,
          error: result.error ?? '支付失败',
        );
        return false;
      }

      // 4. 支付成功 → confirm（receipt 入库 + 状态→verifying）
      debugPrint('[Payment] 步骤3: confirm...');
      await _ds.confirmOrder(order.orderNo, result.receiptData!);
      confirmed = true;
      onVerifying?.call();

      // 5. 写入本地防掉单队列
      final queued = QueuedReceipt(
        orderNo: order.orderNo,
        receiptData: result.receiptData!,
        productId: productId,
        channel: channel.name,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await IapReceiptQueue.instance.enqueue(queued);

      // 6. 服务端验票
      debugPrint('[Payment] 步骤4: 验票...');
      final verified = await _ds.verifyOrder(order.orderNo, result.receiptData!);

      // 7. 验票成功，清除队列
      await IapReceiptQueue.instance.dequeue(order.orderNo);
      debugPrint('[Payment] 完成: status=${verified.status}');

      state = state.copyWith(
        isLoading: false,
        currentOrder: verified,
        purchaseSuccess: verified.isPaid,
      );
      return verified.isPaid;
    } on PlatformException catch (e) {
      debugPrint('[Payment] iapPurchase PlatformException: code=${e.code}, message=${e.message}');
      if (orderNo != null) { try { await _ds.cancelOrder(orderNo); } catch (_) {} }
      state = state.copyWith(isLoading: false, error: '支付失败(原生): ${e.message ?? e.code}');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('[Payment] iapPurchase MissingPluginException: $e');
      if (orderNo != null) { try { await _ds.cancelOrder(orderNo); } catch (_) {} }
      state = state.copyWith(isLoading: false, error: 'HMS SDK 未初始化，请确认设备支持华为支付');
      return false;
    } catch (e) {
      debugPrint('[Payment] iapPurchase error: $e');
      if (confirmed) {
        // confirm 已成功，receipt 已入库，说明验票阶段失败
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
