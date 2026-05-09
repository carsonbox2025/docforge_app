import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../shared/models/export_format.dart';
export '../../../../shared/models/export_format.dart';

/// 文档类型枚举
enum DocType {
  contract('contract', '合同', Icons.description_outlined),
  bid('bid', '标书', Icons.bar_chart_outlined),
  official('official', '公文', Icons.account_balance_outlined),
  resume('resume', '简历', Icons.person_outline),
  paper('paper', '论文', Icons.menu_book_outlined),
  report('report', '报告', Icons.insert_chart_outlined),
  minutes('minutes', '纪要', Icons.groups_outlined),
  proposal('proposal', '方案', Icons.computer_outlined);

  const DocType(this.code, this.label, this.icon);
  final String code;
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

/// 生成阶段
enum GenerateStage { input, generating, review }

/// 步骤状态（用于步骤指示器）
enum StepStatus { done, active, pending }

/// 生成请求
class GenerateRequest {
  final DocType docType;
  final String content;
  final DocLanguage language;
  final bool outlineOnly;

  const GenerateRequest({
    required this.docType,
    required this.content,
    required this.language,
    this.outlineOnly = false,
  });

  Map<String, dynamic> toJson() => {
        'doc_type': docType.code,
        'content': content,
        'language': language.code,
        'outline_only': outlineOnly,
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

/// SSE 流式事件
class GenerateEvent {
  final String event;
  final String? data;

  const GenerateEvent({required this.event, this.data});

  Map<String, dynamic>? get dataAsJson {
    if (data == null) return null;
    try {
      return jsonDecode(data!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
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

/// 生成结果摘要
class GenerateResult {
  final String title;
  final List<ChapterMeta> chapters;
  final String content;
  final int wordCount;
  final List<ReviewFinding> findings;

  const GenerateResult({
    required this.title,
    required this.chapters,
    required this.content,
    this.wordCount = 0,
    this.findings = const [],
  });

  int get chapterCount => chapters.length;

  int get passCount => findings.where((f) => f.level == ReviewLevel.pass).length;
  int get warnCount => findings.where((f) => f.level == ReviewLevel.warn).length;
  int get errorCount => findings.where((f) => f.level == ReviewLevel.error).length;
  int get infoCount => findings.where((f) => f.level == ReviewLevel.info).length;
}
