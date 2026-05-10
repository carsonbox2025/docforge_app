import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import 'models/history_models.dart';

class HistoryDataSource {
  /// 获取历史文档列表
  Future<List<HistoryDocument>> getHistoryList({
    HistoryFilter filter = HistoryFilter.all,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await ApiClient.instance.get(
      '${AppConstants.apiBaseUrl}/history/list',
      queryParameters: {
        'filter': filter.name,
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = response.data['data'] as List<dynamic>?;
    if (data == null) return [];
    return data.map((e) => parseDocument(e as Map<String, dynamic>)).toList();
  }

  /// 获取文档详情（返回完整原始 JSON，包含内容和审校结果）
  Future<Map<String, dynamic>?> getDocumentDetail(int id) async {
    final response = await ApiClient.instance.get(
      '${AppConstants.apiBaseUrl}/history/$id',
    );
    return response.data['data'] as Map<String, dynamic>?;
  }

  /// 删除文档
  Future<bool> deleteDocument(int id) async {
    await ApiClient.instance.delete('${AppConstants.apiBaseUrl}/history/$id');
    return true;
  }

  HistoryDocument parseDocument(Map<String, dynamic> json) {
    return HistoryDocument(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      docType: HistoryDocType.values.firstWhere(
        (e) => e.code == json['doc_type'],
        orElse: () => HistoryDocType.generated,
      ),
      status: DocStatus.values.firstWhere(
        (e) => e.code == json['status'],
        orElse: () => DocStatus.completed,
      ),
      category: DocCategory.values.firstWhere(
        (e) => e.label == json['category'],
        orElse: () => DocCategory.contract,
      ),
      wordCount: json['word_count'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      summary: json['summary'] as String?,
    );
  }

  ReviewResult parseReview(Map<String, dynamic> json) {
    final issues = (json['issues'] as List<dynamic>?)
            ?.map((e) => ReviewIssue(
                  level: e['level'] as String? ?? 'info',
                  message: e['message'] as String? ?? '',
                  location: e['location'] as String? ?? '',
                ))
            .toList() ??
        [];
    return ReviewResult(
      passCount: json['pass_count'] as int? ?? 0,
      warnCount: json['warn_count'] as int? ?? 0,
      errorCount: json['error_count'] as int? ?? 0,
      issues: issues,
    );
  }
}
