import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'channel_detector.dart';
import 'payment_logger.dart';

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
  final String? purchaseData;
  final String? signature;
  final String? orderNo;
  final String? error;

  const PurchaseResult({
    this.success = false,
    this.receiptData,
    this.purchaseData,
    this.signature,
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

  static PaymentLogger get _log => PaymentLogger.instance;

  /// 查询商品信息
  Future<List<ProductInfo>> queryProducts(
    List<String> productIds, {
    String productType = 'consumable',
  }) async {
    if (_channelType == IapChannel.official) {
      _log.log('IAP', '跳过查询: 当前为 official 渠道');
      return [];
    }
    _log.log('IAP', '查询商品: ids=$productIds, type=$productType, channel=${_channelType.name}');
    try {
      final List result = await _channel.invokeMethod('queryProducts', {
        'channel': _channelType.name,
        'productIds': productIds,
        'productType': productType,
      });
      _log.log('IAP', '查询商品成功: ${result.length} 个');
      return result
          .cast<Map>()
          .map((m) => ProductInfo(
                productId: m['productId'] as String,
                name: m['name'] as String? ?? '',
                priceCents: m['priceCents'] as int? ?? 0,
                currency: m['currency'] as String? ?? 'CNY',
              ))
          .toList();
    } on PlatformException catch (e) {
      _log.log('IAP', '查询商品 PlatformException: code=${e.code}, msg=${e.message}');
      return [];
    } on MissingPluginException catch (e) {
      _log.log('IAP', '查询商品 MissingPluginException: $e');
      return [];
    }
  }

  /// 发起支付 → 返回 receipt
  Future<PurchaseResult> launchPayFlow({
    required String productId,
    required String orderNo,
    String productType = 'consumable',
  }) async {
    if (_channelType == IapChannel.official) {
      _log.log('IAP', '跳过支付: 当前为 official 渠道');
      return const PurchaseResult(error: '官方渠道不支持 IAP');
    }
    _log.log('IAP', '发起支付: productId=$productId, orderNo=$orderNo, type=$productType, channel=${_channelType.name}');
    try {
      final Map? result = await _channel.invokeMethod('launchPayFlow', {
        'channel': _channelType.name,
        'productId': productId,
        'orderNo': orderNo,
        'productType': productType,
      });
      if (result == null) {
        _log.log('IAP', '支付返回 null');
        return const PurchaseResult(error: '支付结果为空（SDK 未返回数据）');
      }
      final success = result['success'] as bool? ?? false;
      _log.log('IAP', '支付结果: success=$success, hasReceipt=${result['receiptData'] != null}, error=${result['error']}');
      return PurchaseResult(
        success: success,
        receiptData: result['receiptData'] as String?,
        purchaseData: result['purchaseData'] as String?,
        signature: result['signature'] as String?,
        orderNo: orderNo,
        error: success ? null : (result['error'] as String? ?? '支付失败'),
      );
    } on PlatformException catch (e) {
      _log.log('IAP', '支付 PlatformException: code=${e.code}, msg=${e.message}, details=${e.details}');
      if (e.code == 'ALREADY_OWNED') {
        return PurchaseResult(error: '您已购买此商品，请点击"恢复购买"完成激活');
      }
      return PurchaseResult(error: '支付异常(${e.code}): ${e.message ?? "未知错误"}');
    } on MissingPluginException catch (e) {
      _log.log('IAP', '支付 MissingPluginException: $e');
      return PurchaseResult(error: 'HMS SDK 未初始化或方法未注册，请确认设备支持华为支付');
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
    } on MissingPluginException {
      return false;
    }
  }

  /// 查询未确认订单（obtainOwnedPurchases）— 恢复购买时优先使用
  Future<List<Map<String, dynamic>>> queryPendingPurchases({
    String productType = 'consumable',
  }) async {
    if (_channelType == IapChannel.official) return [];
    _log.log('IAP', '查询未确认订单: type=$productType, channel=${_channelType.name}');
    try {
      final List result = await _channel.invokeMethod('queryPendingPurchases', {
        'channel': _channelType.name,
        'productType': productType,
      });
      _log.log('IAP', '未确认订单: ${result.length} 条 (type=$productType)');
      return result
          .cast<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException catch (e) {
      _log.log('IAP', '查询未确认订单失败: code=${e.code}, msg=${e.message}');
      rethrow;
    } on MissingPluginException catch (e) {
      _log.log('IAP', '查询未确认订单 MissingPlugin: $e');
      rethrow;
    }
  }

  /// 从 HMS 服务器查询已购记录（用于恢复购买）
  Future<List<Map<String, dynamic>>> restorePurchases({
    String productType = 'subscription',
  }) async {
    if (_channelType == IapChannel.official) return [];
    _log.log('IAP', '查询已购: type=$productType, channel=${_channelType.name}');
    try {
      final List result = await _channel.invokeMethod('restorePurchases', {
        'channel': _channelType.name,
        'productType': productType,
      });
      _log.log('IAP', '已购记录: ${result.length} 条 (type=$productType)');
      return result
          .cast<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException catch (e) {
      _log.log('IAP', '查询已购失败: code=${e.code}, msg=${e.message}');
      rethrow;
    } on MissingPluginException catch (e) {
      _log.log('IAP', '查询已购 MissingPlugin: $e');
      rethrow;
    }
  }
}
