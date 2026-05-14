import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import 'models/template_models.dart';

class TemplateDataSource {
  /// 获取模板列表（后端无独立详情接口，详情通过列表获取）
  Future<List<Template>> getTemplates({
    TemplateCategory category = TemplateCategory.all,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await ApiClient.instance.get(
      '${AppConstants.apiBaseUrl}/templates/list',
      queryParameters: {
        'category': category.name,
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = response.data['data'] as List<dynamic>?;
    if (data == null) return [];
    return data.map((e) => _parseTemplate(e as Map<String, dynamic>)).toList();
  }

  Template _parseTemplate(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final index = id.hashCode.abs() % TemplateColorScheme.schemes.length;
    return Template(
      id: id,
      name: json['name'] as String? ?? '',
      category: TemplateCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => TemplateCategory.contract,
      ),
      documentCount: json['document_count'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      colorScheme: TemplateColorScheme.schemes[index],
      requirePro: json['require_pro'] as bool? ?? false,
    );
  }
}
