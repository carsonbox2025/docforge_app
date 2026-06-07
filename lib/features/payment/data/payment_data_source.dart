import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/iap/payment_logger.dart';
import '../../../../core/network/api_client.dart';
import 'models/payment_models.dart';

/// restore API 的结构化响应
class RestoreResult {
  final List<OrderRecord> orders;
  final int restored;
  final int failed;

  const RestoreResult({this.orders = const [], this.restored = 0, this.failed = 0});
}

/// 支付 API 数据源 — 对接统一支付模块
class PaymentDataSource {
  final Dio _dio = ApiClient.instance.dio;

  /// 查询商品列表
  Future<List<Product>> getProducts(String channel, {String? productType}) async {
    final log = PaymentLogger.instance;
    final queryParams = <String, dynamic>{
      'app_key': AppConstants.appKey,
      'channel': channel,
    };
    if (productType != null) {
      queryParams['product_type'] = productType;
    }
    log.log('API', '查询商品: channel=$channel, type=$productType');
    try {
      final response = await _dio.get(
        AppConstants.paymentBase + '/products',
        queryParameters: queryParams,
      );
      final data = response.data['data'];
      if (data is List) {
        final products = data
            .cast<Map<String, dynamic>>()
            .map((m) => Product.fromJson(m))
            .toList();
        log.log('API', '返回 ${products.length} 个商品: ${products.map((p) => "${p.productId}(${p.productType})").join(", ")}');
        return products;
      }
      log.log('API', '返回数据非 List: ${data.runtimeType}');
      return [];
    } catch (e) {
      log.log('API', '查询商品失败: $e');
      return [];
    }
  }

  /// 创建订单
  Future<OrderRecord> createOrder(CreateOrderRequest request) async {
    final response = await _dio.post(
      AppConstants.paymentOrdersUrl,
      data: request.toJson(),
    );
    final data = response.data['data'];
    if (data == null) {
      throw Exception(response.data['message'] ?? '创建订单失败');
    }
    return OrderRecord.fromJson(data as Map<String, dynamic>);
  }

  /// IAP 验票
  Future<OrderRecord> verifyOrder(String orderNo, String receiptData) async {
    final response = await _dio.post(
      AppConstants.paymentOrderVerifyUrl(orderNo),
      data: {
        'app_key': AppConstants.appKey,
        'receipt_data': receiptData,
      },
    );
    final data = response.data['data'];
    if (data == null) {
      throw Exception(response.data['message'] ?? '验票失败');
    }
    return OrderRecord.fromJson(data as Map<String, dynamic>);
  }

  /// IAP 支付成功确认（pending → verifying）
  Future<OrderRecord> confirmOrder(String orderNo, String receiptData) async {
    final response = await _dio.post(
      AppConstants.paymentOrderConfirmUrl(orderNo),
      data: {
        'app_key': AppConstants.appKey,
        'receipt_data': receiptData,
      },
    );
    final data = response.data['data'];
    if (data == null) {
      throw Exception(response.data['message'] ?? '确认失败');
    }
    return OrderRecord.fromJson(data as Map<String, dynamic>);
  }

  /// 取消订单（用户取消/支付失败 → cancelled）
  Future<OrderRecord> cancelOrder(String orderNo) async {
    final response = await _dio.post(
      AppConstants.paymentOrderCancelUrl(orderNo),
      data: {'app_key': AppConstants.appKey},
    );
    final data = response.data['data'];
    if (data == null) {
      throw Exception(response.data['message'] ?? '取消失败');
    }
    return OrderRecord.fromJson(data as Map<String, dynamic>);
  }

  /// 查询订单状态
  Future<OrderRecord> getOrder(String orderNo) async {
    final response = await _dio.get(AppConstants.paymentOrderUrl(orderNo));
    final data = response.data['data'];
    if (data == null) {
      throw Exception(response.data['message'] ?? '查询订单失败');
    }
    return OrderRecord.fromJson(data as Map<String, dynamic>);
  }

  /// 恢复购买（非消耗品/订阅）
  Future<RestoreResult> restorePurchases() async {
    final response = await _dio.post(
      AppConstants.paymentRestoreUrl,
      data: {'app_key': AppConstants.appKey},
    );
    final data = response.data['data'];
    if (data is Map<String, dynamic>) {
      final orders = (data['orders'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map((m) => OrderRecord.fromJson(m))
              .toList() ??
          [];
      return RestoreResult(
        orders: orders,
        restored: data['restored'] as int? ?? 0,
        failed: data['failed'] as int? ?? 0,
      );
    }
    // 兼容旧版后端返回 List
    if (data is List) {
      final orders = data
          .cast<Map<String, dynamic>>()
          .map((m) => OrderRecord.fromJson(m))
          .toList();
      return RestoreResult(
        orders: orders,
        restored: orders.where((o) => o.isPaid).length,
        failed: 0,
      );
    }
    return const RestoreResult();
  }

  /// 获取当前用户配额
  Future<QuotaInfo> getMyQuota() async {
    final response = await _dio.get(AppConstants.quotasMeUrl);
    final data = response.data['data'];
    if (data == null) {
      throw Exception(response.data['message'] ?? '获取配额失败');
    }
    return QuotaInfo.fromJson(data as Map<String, dynamic>);
  }
}
