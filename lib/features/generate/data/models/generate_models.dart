import 'package:flutter/material.dart';
import '../../../../shared/models/export_format.dart';
export '../../../../shared/models/export_format.dart';

/// 文档类型枚举
enum DocType {
  contract('contract', 'tpl_contract_tech', '合同', Icons.description_outlined),
  bid('bid', 'tpl_bid_technical', '标书', Icons.bar_chart_outlined),
  official('official', 'tpl_official_gbt9704', '公文', Icons.account_balance_outlined),
  resume('resume', 'tpl_resume_standard', '简历', Icons.person_outline),
  paper('paper', 'tpl_paper_thesis', '论文', Icons.menu_book_outlined),
  report('report', 'tpl_report_annual', '报告', Icons.insert_chart_outlined),
  minutes('minutes', 'tpl_minutes_meeting', '纪要', Icons.groups_outlined),
  proposal('proposal', 'tpl_report_annual', '方案', Icons.computer_outlined);

  const DocType(this.code, this.defaultTemplateId, this.label, this.icon);
  final String code;
  final String defaultTemplateId;
  final String label;
  final IconData icon;
}

/// 语言选项
enum DocLanguage {
  zhCN('zh-CN', '中文'),
  enUS('en-US', 'English'),
  jaJP('ja-JP', '日本語'),
  koKR('ko-KR', '한국어');

  const DocLanguage(this.code, this.label);
  final String code;
  final String label;
}

/// ExportFormat 图标映射（共享 ExportFormat 不含 IconData）
extension ExportFormatIcon on ExportFormat {
  IconData get icon => switch (this) {
    ExportFormat.docx => Icons.description_outlined,
    ExportFormat.pdf => Icons.picture_as_pdf_outlined,
    ExportFormat.html => Icons.code_outlined,
  };
}

/// 生成请求
class GenerateRequest {
  final String templateId;
  final String content;
  final DocLanguage language;
  final String? title;
  final String mode; // quick / professional
  final String docType;
  final String sceneId;
  final int layer;
  final Map<String, String>? fieldsData;

  const GenerateRequest({
    required this.templateId,
    required this.content,
    required this.language,
    this.title,
    this.mode = 'quick',
    required this.docType,
    required this.sceneId,
    required this.layer,
    this.fieldsData,
  });

  Map<String, dynamic> toJson() => {
        'doc_type': docType,
        'source_type': 'generate',
        'template_id': templateId,
        'user_input': {
          'content': content,
          'language': language.code,
          'mode': mode,
        },
        if (title != null) 'title': title,
        'scene_id': sceneId,
        'layer': layer,
        if (fieldsData != null) 'fields_data': fieldsData,
      };
}

/// 章节元数据
class ChapterMeta {
  final String title;
  final int order;

  const ChapterMeta({required this.title, required this.order});

  factory ChapterMeta.fromJson(Map<String, dynamic> json) => ChapterMeta(
        title: json['title'] as String? ?? '',
        order: json['order'] as int? ?? 0,
      );
}

/// 审校级别
enum ReviewLevel {
  pass('pass'),
  warn('warn'),
  error('error'),
  info('info');

  const ReviewLevel(this.code);
  final String code;
}

/// 审校发现项
class ReviewFinding {
  final ReviewLevel level;
  final String message;
  final String location;

  const ReviewFinding({
    required this.level,
    required this.message,
    required this.location,
  });

  factory ReviewFinding.fromJson(Map<String, dynamic> json) => ReviewFinding(
        level: ReviewLevel.values.firstWhere(
          (e) => e.code == json['level'],
          orElse: () => ReviewLevel.info,
        ),
        message: json['message'] as String? ?? '',
        location: json['location'] as String? ?? '',
      );
}
