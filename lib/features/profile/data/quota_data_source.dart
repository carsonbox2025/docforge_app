import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../payment/data/models/payment_models.dart';

class QuotaDataSource {
  /// 获取配额 — 使用统一的 /quotas/me 接口
  Future<QuotaInfo> getQuota() async {
    final response = await ApiClient.instance.get(
      AppConstants.quotasMeUrl,
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('配额数据为空');
    return QuotaInfo.fromJson(data);
  }
}
