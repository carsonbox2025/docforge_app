import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/payment_data_source.dart';
import '../../data/models/payment_models.dart';

/// 全局配额 Provider
final quotaProvider = FutureProvider<QuotaInfo>((ref) async {
  return PaymentDataSource().getMyQuota();
});

/// 支付状态管理
class PaymentState {
  final bool isLoading;
  final OrderRecord? currentOrder;
  final String? error;

  const PaymentState({
    this.isLoading = false,
    this.currentOrder,
    this.error,
  });

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

  PaymentNotifier() : super(const PaymentState());

  /// 创建订单并返回支付链接
  Future<OrderRecord> createOrder({
    required PaymentChannel channel,
    String? sceneId,
    int? documentId,
    String orderType = 'per_doc',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final order = await _ds.createOrder(CreateOrderRequest(
        channel: channel.name,
        sceneId: sceneId,
        documentId: documentId,
        orderType: orderType,
      ));
      state = state.copyWith(isLoading: false, currentOrder: order);
      return order;
    } catch (e) {
      debugPrint('[Payment] createOrder error: $e');
      state = state.copyWith(isLoading: false, error: '创建订单失败: $e');
      rethrow;
    }
  }

  /// 轮询订单状态直到支付完成
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
        if (i >= 3) return false; // 连续失败后提前退出
      }
    }
    return false;
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
