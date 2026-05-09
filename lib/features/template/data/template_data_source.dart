import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import 'models/template_models.dart';

class TemplateDataSource {
  /// 获取模板列表
  Future<List<Template>> getTemplates({
    TemplateCategory category = TemplateCategory.all,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await ApiClient.instance.get(
        '${AppConstants.apiBaseUrl}/templates',
        queryParameters: {
          'category': category.name,
          'page': page,
          'page_size': pageSize,
        },
      );
      final data = response.data['data'] as List<dynamic>?;
      if (data == null) return [];
      return data.map((e) => _parseTemplate(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _getMockData();
    }
  }

  /// 获取模板详情
  Future<Template?> getTemplateDetail(int id) async {
    try {
      final response = await ApiClient.instance.get(
        '${AppConstants.apiBaseUrl}/templates/$id',
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      return _parseTemplate(data);
    } catch (_) {
      return _getMockData().where((t) => t.id == id).firstOrNull;
    }
  }

  Template _parseTemplate(Map<String, dynamic> json) {
    return Template(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      category: TemplateCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => TemplateCategory.contract,
      ),
      documentCount: json['document_count'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      colorScheme: TemplateColorScheme.schemes[(json['id'] as int? ?? 0) % TemplateColorScheme.schemes.length],
    );
  }

  List<Template> _getMockData() {
    return const [
      Template(
        id: 1,
        name: '劳动合同',
        category: TemplateCategory.contract,
        documentCount: 12,
        description: '标准劳动合同模板，包含试用期、薪资、保险等条款，适用于企业用工。',
        colorScheme: TemplateColorScheme(primary: Color(0xFF2563EB), light: Color(0xFF3B82F6), bg: Color(0xFFDBEAFE)),
        tags: ['标准', '企业'],
      ),
      Template(
        id: 2,
        name: '采购合同',
        category: TemplateCategory.contract,
        documentCount: 8,
        description: '货物/服务采购合同模板，包含交付、验收、付款等条款。',
        colorScheme: TemplateColorScheme(primary: Color(0xFF10B981), light: Color(0xFF34D399), bg: Color(0xFFD1FAE5)),
        tags: ['采购', '供应链'],
      ),
      Template(
        id: 3,
        name: '行政通知',
        category: TemplateCategory.official,
        documentCount: 15,
        description: '公文通知模板，包含标题、正文、落款格式，适用于政府机关和企事业单位。',
        colorScheme: TemplateColorScheme(primary: Color(0xFFF97316), light: Color(0xFFFB923C), bg: Color(0xFFFED7AA)),
        tags: ['行政', '通知'],
      ),
      Template(
        id: 4,
        name: '可行性研究报告',
        category: TemplateCategory.report,
        documentCount: 6,
        description: '项目可行性研究报告模板，包含市场分析、技术方案、经济评价等章节。',
        colorScheme: TemplateColorScheme(primary: Color(0xFF7C3AED), light: Color(0xFF8B5CF6), bg: Color(0xFFDDD6FE)),
        tags: ['研究', '评估'],
      ),
      Template(
        id: 5,
        name: '学术论文',
        category: TemplateCategory.paper,
        documentCount: 10,
        description: '学术论文模板，包含摘要、引言、方法、结果、讨论等标准章节。',
        colorScheme: TemplateColorScheme(primary: Color(0xFFEF4444), light: Color(0xFFF87171), bg: Color(0xFFFECACA)),
        tags: ['学术', '研究'],
      ),
      Template(
        id: 6,
        name: '个人简历',
        category: TemplateCategory.resume,
        documentCount: 5,
        description: '专业简历模板，包含个人信息、教育背景、工作经历、技能特长等模块。',
        colorScheme: TemplateColorScheme(primary: Color(0xFF06B6D4), light: Color(0xFF22D3EE), bg: Color(0xFFA5F3FC)),
        tags: ['求职', '个人'],
      ),
      Template(
        id: 7,
        name: '招标文件',
        category: TemplateCategory.bid,
        documentCount: 9,
        description: '政府采购/工程招标文件模板，包含招标公告、投标须知、合同条款等。',
        colorScheme: TemplateColorScheme(primary: Color(0xFFF59E0B), light: Color(0xFFFBBF24), bg: Color(0xFFFDE68A)),
        tags: ['招标', '采购'],
      ),
      Template(
        id: 8,
        name: '会议纪要',
        category: TemplateCategory.minutes,
        documentCount: 7,
        description: '会议纪要模板，包含会议信息、议题、决议事项、后续行动等。',
        colorScheme: TemplateColorScheme(primary: Color(0xFFEC4899), light: Color(0xFFF472B6), bg: Color(0xFFFBCFE8)),
        tags: ['会议', '协作'],
      ),
      Template(
        id: 9,
        name: '技术开发合同',
        category: TemplateCategory.contract,
        documentCount: 4,
        description: 'IT项目技术开发合同模板，包含需求说明、交付标准、知识产权等条款。',
        colorScheme: TemplateColorScheme(primary: Color(0xFF2563EB), light: Color(0xFF3B82F6), bg: Color(0xFFDBEAFE)),
        tags: ['技术', '开发'],
      ),
      Template(
        id: 10,
        name: '年度工作总结',
        category: TemplateCategory.report,
        documentCount: 8,
        description: '年度工作总结报告模板，包含工作回顾、成果展示、问题分析、来年计划。',
        colorScheme: TemplateColorScheme(primary: Color(0xFF10B981), light: Color(0xFF34D399), bg: Color(0xFFD1FAE5)),
        tags: ['总结', '报告'],
      ),
    ];
  }
}
