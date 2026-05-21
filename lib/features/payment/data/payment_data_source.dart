import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import 'models/payment_models.dart';

/// 支付 API 数据源 — 对接统一支付模块
class PaymentDataSource {
  final Dio _dio = ApiClient.instance.dio;

  String get _paymentBase => '${AppConstants.apiOrigin}/aistudio/service/payment';

  /// 查询商品列表
  Future<List<Product>> getProducts(String channel) async {
    final response = await _dio.get(
      '$_paymentBase/products',
      queryParameters: {
        'app_key': AppConstants.appKey,
        'channel': channel,
      },
    );
    final data = response.data['data'];
    if (data is List) {
      return data
          .cast<Map<String, dynamic>>()
          .map((m) => Product.fromJson(m))
          .toList();
    }
    return [];
  }

  /// 创建订单
  Future<OrderRecord> createOrder(CreateOrderRequest request) async {
    final response = await _dio.post(
      '$_paymentBase/orders',
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
      '$_paymentBase/orders/$orderNo/verify',
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

  /// 查询订单状态
  Future<OrderRecord> getOrder(String orderNo) async {
    final response = await _dio.get('$_paymentBase/orders/$orderNo');
    final data = response.data['data'];
    if (data == null) {
      throw Exception(response.data['message'] ?? '查询订单失败');
    }
    return OrderRecord.fromJson(data as Map<String, dynamic>);
  }

  /// 恢复购买（非消耗品/订阅）
  Future<List<OrderRecord>> restorePurchases() async {
    final response = await _dio.post(
      '$_paymentBase/restore',
      data: {'app_key': AppConstants.appKey},
    );
    final data = response.data['data'];
    if (data is List) {
      return data
          .cast<Map<String, dynamic>>()
          .map((m) => OrderRecord.fromJson(m))
          .toList();
    }
    return [];
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

  /// 申请退款
  Future<bool> refundOrder(String orderNo, {String reason = ''}) async {
    final response = await _dio.post(
      '$_paymentBase/admin/orders/$orderNo/refund',
      data: {'reason': reason},
    );
    return response.data['code'] == 200 || response.data['code'] == 0;
  }
}
