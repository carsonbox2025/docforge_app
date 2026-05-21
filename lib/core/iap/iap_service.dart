import 'dart:async';
import 'package:flutter/services.dart';
import 'channel_detector.dart';

class ProductInfo {
  final String productId;
  final String name;
  final int priceCents;
  final String currency;

  const ProductInfo({
    required this.productId,
    required this.name,
    required this.priceCents,
    this.currency = 'CNY',
  });
}

class PurchaseResult {
  final bool success;
  final String? receiptData;
  final String? orderNo;
  final String? error;

  const PurchaseResult({
    this.success = false,
    this.receiptData,
    this.orderNo,
    this.error,
  });
}

class VerifyResult {
  final bool success;
  final String orderNo;
  final String status;

  const VerifyResult({
    this.success = false,
    this.orderNo = '',
    this.status = '',
  });
}

/// IAP 服务 — 通过 Platform Channel 与原生 SDK 通信
class IapService {
  static const _channel = MethodChannel('com.docforge.app/iap');

  final IapChannel _channelType;

  IapService() : _channelType = ChannelDetector.detect();

  IapChannel get channel => _channelType;

  /// 查询商品信息
  Future<List<ProductInfo>> queryProducts(List<String> productIds) async {
    if (_channelType == IapChannel.official) return [];
    try {
      final List result = await _channel.invokeMethod('queryProducts', {
        'channel': _channelType.name,
        'productIds': productIds,
      });
      return result
          .cast<Map>()
          .map((m) => ProductInfo(
                productId: m['productId'] as String,
                name: m['name'] as String? ?? '',
                priceCents: m['priceCents'] as int? ?? 0,
                currency: m['currency'] as String? ?? 'CNY',
              ))
          .toList();
    } on PlatformException {
      return [];
    }
  }

  /// 发起支付 → 返回 receipt
  Future<PurchaseResult> launchPayFlow({
    required String productId,
    required String orderNo,
  }) async {
    if (_channelType == IapChannel.official) {
      return const PurchaseResult(error: '官方渠道不支持 IAP');
    }
    try {
      final Map? result = await _channel.invokeMethod('launchPayFlow', {
        'channel': _channelType.name,
        'productId': productId,
        'orderNo': orderNo,
      });
      if (result == null) {
        return const PurchaseResult(error: '支付结果为空');
      }
      final success = result['success'] as bool? ?? false;
      return PurchaseResult(
        success: success,
        receiptData: result['receiptData'] as String?,
        orderNo: orderNo,
        error: success ? null : (result['error'] as String? ?? '支付失败'),
      );
    } on PlatformException catch (e) {
      return PurchaseResult(error: e.message ?? '支付异常');
    }
  }

  /// 消耗品确认消费
  Future<bool> consumePurchase(String purchaseToken) async {
    try {
      final result = await _channel.invokeMethod('consumePurchase', {
        'channel': _channelType.name,
        'purchaseToken': purchaseToken,
      });
      return result as bool? ?? false;
    } on PlatformException {
      return false;
    }
  }
}
