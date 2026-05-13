import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import 'models/payment_models.dart';

/// 支付 API 数据源
class PaymentDataSource {
  final Dio _dio = ApiClient.instance.dio;

  /// 创建订单 → 返回支付链接
  Future<OrderRecord> createOrder(CreateOrderRequest request) async {
    final response = await _dio.post(
      AppConstants.ordersCreateUrl,
      data: request.toJson(),
    );
    final data = response.data['data'];
    if (data == null) {
      throw Exception(response.data['message'] ?? '创建订单失败');
    }
    return OrderRecord.fromJson(data as Map<String, dynamic>);
  }

  /// 查询订单状态
  Future<OrderRecord> getOrder(String orderNo) async {
    final response = await _dio.get(AppConstants.orderDetailUrl(orderNo));
    final data = response.data['data'];
    if (data == null) {
      throw Exception(response.data['message'] ?? '查询订单失败');
    }
    return OrderRecord.fromJson(data as Map<String, dynamic>);
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
      AppConstants.orderRefundUrl(orderNo),
      data: {'reason': reason},
    );
    return response.data['code'] == 200 || response.data['code'] == 0;
  }
}
