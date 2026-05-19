import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';

class QuotaDataSource {
  /// 获取用量统计
  Future<QuotaUsage> getQuotaUsage() async {
    final response = await ApiClient.instance.get(
      AppConstants.quotaUsageUrl,
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('配额数据为空');
    return QuotaUsage.fromJson(data);
  }

  /// 获取用户综合统计
  Future<UserStats> getStats() async {
    final response = await ApiClient.instance.get(
      AppConstants.quotaStatsUrl,
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('统计数据为空');
    return UserStats.fromJson(data);
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

class UserStats {
  final int generateCount;
  final int polishCount;
  final int translateCount;
  final int totalWordCount;
  final String wordCountDisplay;
  final int remainingQuota;
  final int totalQuota;

  const UserStats({
    required this.generateCount,
    required this.polishCount,
    required this.translateCount,
    required this.totalWordCount,
    required this.wordCountDisplay,
    required this.remainingQuota,
    required this.totalQuota,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
    generateCount: json['generate_count'] as int? ?? 0,
    polishCount: json['polish_count'] as int? ?? 0,
    translateCount: json['translate_count'] as int? ?? 0,
    totalWordCount: json['total_word_count'] as int? ?? 0,
    wordCountDisplay: json['word_count_display'] as String? ?? '0',
    remainingQuota: json['remaining_quota'] as int? ?? 0,
    totalQuota: json['total_quota'] as int? ?? -1,
  );
}
