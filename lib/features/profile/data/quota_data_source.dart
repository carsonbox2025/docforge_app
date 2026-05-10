import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';

class QuotaDataSource {
  /// 获取用量统计
  Future<QuotaUsage> getQuotaUsage() async {
    final response = await ApiClient.instance.get(
      '${AppConstants.apiBaseUrl}/quota/usage',
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('配额数据为空');
    return QuotaUsage.fromJson(data);
  }
}

class QuotaUsage {
  final QuotaItem generate;
  final QuotaItem polish;
  final QuotaItem translate;

  const QuotaUsage({
    required this.generate,
    required this.polish,
    required this.translate,
  });

  factory QuotaUsage.fromJson(Map<String, dynamic> json) {
    return QuotaUsage(
      generate: QuotaItem.fromJson(json['generate'] as Map<String, dynamic>? ?? {}),
      polish: QuotaItem.fromJson(json['polish'] as Map<String, dynamic>? ?? {}),
      translate: QuotaItem.fromJson(json['translate'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class QuotaItem {
  final int used;
  final int limit;
  final String period;

  const QuotaItem({
    required this.used,
    required this.limit,
    required this.period,
  });

  factory QuotaItem.fromJson(Map<String, dynamic> json) {
    return QuotaItem(
      used: json['used'] as int? ?? 0,
      limit: json['limit'] as int? ?? 0,
      period: json['period'] as String? ?? 'month',
    );
  }
}
