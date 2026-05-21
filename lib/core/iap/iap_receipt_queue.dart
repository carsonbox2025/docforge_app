import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/storage/local_cache.dart';
import '../../features/payment/data/payment_data_source.dart';

class QueuedReceipt {
  final String orderNo;
  final String receiptData;
  final String productId;
  final String channel;
  final int timestamp;

  QueuedReceipt({
    required this.orderNo,
    required this.receiptData,
    required this.productId,
    required this.channel,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'orderNo': orderNo,
    'receiptData': receiptData,
    'productId': productId,
    'channel': channel,
    'timestamp': timestamp,
  };

  factory QueuedReceipt.fromJson(Map<String, dynamic> json) => QueuedReceipt(
    orderNo: json['orderNo'] as String,
    receiptData: json['receiptData'] as String,
    productId: json['productId'] as String,
    channel: json['channel'] as String,
    timestamp: json['timestamp'] as int,
  );
}

/// IAP 掉单补偿本地队列（极度保障商业合规性与上架退款率）
class IapReceiptQueue {
  static const _storageKey = 'iap_unverified_receipts_v1';
  final PaymentDataSource _ds = PaymentDataSource();

  static final IapReceiptQueue instance = IapReceiptQueue._();
  IapReceiptQueue._();

  /// 1. 保存未完成的凭证到本地
  Future<void> enqueue(QueuedReceipt receipt) async {
    final list = await _loadQueue();
    // 防重复加入
    list.removeWhere((r) => r.orderNo == receipt.orderNo);
    list.add(receipt);
    await _saveQueue(list);
  }

  /// 2. 移除已完成的凭证
  Future<void> dequeue(String orderNo) async {
    final list = await _loadQueue();
    list.removeWhere((r) => r.orderNo == orderNo);
    await _saveQueue(list);
  }

  /// 3. 执行队列内的所有凭证自动验票补单（在应用启动或打开支付墙时调用）
  Future<void> processPendingQueue() async {
    final list = await _loadQueue();
    if (list.isEmpty) return;

    debugPrint('[IapQueue] 开始自动补单重试，挂起凭证数: ${list.length}');
    for (final receipt in list) {
      // 过滤超过 7 天的陈旧未验票订单，防止无限循环
      if (DateTime.now().millisecondsSinceEpoch - receipt.timestamp > 7 * 24 * 3600 * 1000) {
        await dequeue(receipt.orderNo);
        continue;
      }
      try {
        debugPrint('[IapQueue] 正在后台静默验票，单号: ${receipt.orderNo}');
        await _ds.verifyOrder(receipt.orderNo, receipt.receiptData);
        await dequeue(receipt.orderNo);
        debugPrint('[IapQueue] 补单发货成功，单号: ${receipt.orderNo}');
      } catch (e) {
        debugPrint('[IapQueue] 后台验票重试失败，单号: ${receipt.orderNo}, 错误: $e');
      }
    }
  }

  Future<List<QueuedReceipt>> _loadQueue() async {
    try {
      final raw = LocalCache.instance.get<String>(_storageKey);
      if (raw == null || raw.isEmpty) return [];
      final List decoded = jsonDecode(raw);
      return decoded.map((m) => QueuedReceipt.fromJson(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<QueuedReceipt> list) async {
    final raw = jsonEncode(list.map((r) => r.toJson()).toList());
    await LocalCache.instance.set(_storageKey, raw);
  }
}
