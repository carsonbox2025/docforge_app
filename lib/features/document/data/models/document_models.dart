import 'package:flutter/material.dart';

/// 文档类别 — 用户选择的文档类型
enum DocCategory {
  contract('contract', '合同', Icons.description_outlined, Color(0xFF2563EB), Color(0x0F2563EB)),
  bid('bid', '标书', Icons.bar_chart_outlined, Color(0xFF7C3AED), Color(0x0F7C3AED)),
  official('official', '公文', Icons.account_balance_outlined, Color(0xFFDC2626), Color(0x0FDC2626)),
  resume('resume', '简历', Icons.person_outline, Color(0xFF10B981), Color(0x0F10B981)),
  paper('paper', '论文', Icons.menu_book_outlined, Color(0xFFF97316), Color(0x0FF97316)),
  report('report', '报告', Icons.insert_chart_outlined, Color(0xFF8B5CF6), Color(0x0F8B5CF6)),
  minutes('minutes', '纪要', Icons.groups_outlined, Color(0xFF0891B2), Color(0x0F0891B2)),
  proposal('proposal', '方案', Icons.computer_outlined, Color(0xFF059669), Color(0x0F059669)),
  generic('generic', '通用', Icons.article_outlined, Color(0xFF6B7280), Color(0x0F6B7280));

  const DocCategory(this.code, this.label, this.icon, this.color, this.bgColor);

  final String code;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  static DocCategory fromCode(String? code) => DocCategory.values.firstWhere(
        (e) => e.code == code,
        orElse: () => DocCategory.generic,
      );
}

/// 操作类型
enum SourceType {
  generate('generate', 'AI 生成', Icons.auto_awesome, Color(0xFF2563EB), Color(0x0F2563EB)),
  polish('polish', '润色', Icons.auto_fix_high, Color(0xFF10B981), Color(0x0F10B981)),
  translate('translate', '翻译', Icons.translate, Color(0xFFF97316), Color(0x0FF97316));

  const SourceType(this.code, this.label, this.icon, this.color, this.bgColor);

  final String code;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
}

/// 文档状态 — 覆盖完整生命周期
enum DocStatus {
  pending('pending', '排队中', Color(0xFFF59E0B), Color(0x0FF59E0B)),
  running('running', '进行中', Color(0xFF2563EB), Color(0x0F2563EB)),
  completed('completed', '已完成', Color(0xFF10B981), Color(0x0F10B981)),
  failed('failed', '失败', Color(0xFFEF4444), Color(0x0FEF4444)),
  cancelled('cancelled', '已取消', Color(0xFF94A3B8), Color(0xFFF1F5F9)),
  draft('draft', '草稿', Color(0xFF94A3B8), Color(0xFFF1F5F9));

  const DocStatus(this.code, this.label, this.color, this.bgColor);

  final String code;
  final String label;
  final Color color;
  final Color bgColor;

  bool get isTerminal => this == DocStatus.completed || this == DocStatus.failed || this == DocStatus.cancelled || this == DocStatus.draft;
}

/// 文档中心筛选 Tab
enum DocCenterTab {
  running('进行中'),
  completed('已完成'),
  all('全部');

  const DocCenterTab(this.label);
  final String label;
}

/// 统一文档模型
class DocForgeDocument {
  final int id;
  final String title;
  final DocCategory docCategory;
  final SourceType sourceType;
  final DocStatus status;
  final double progress;
  final String? progressMsg;
  final Map<String, dynamic>? progressDetail;
  final dynamic dslContent;
  final String? errorMsg;
  final int? wordCount;
  final dynamic outline;
  final dynamic reviewResult;
  final String? fileUrl;
  final String? sourceLang;
  final String? targetLang;
  final int? templateId;
  final String? createdAt;
  final String? startedAt;
  final String? completedAt;

  const DocForgeDocument({
    required this.id,
    required this.title,
    required this.docCategory,
    required this.sourceType,
    required this.status,
    this.progress = 0,
    this.progressMsg,
    this.progressDetail,
    this.dslContent,
    this.errorMsg,
    this.wordCount,
    this.outline,
    this.reviewResult,
    this.fileUrl,
    this.sourceLang,
    this.targetLang,
    this.templateId,
    this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  /// 兼容旧代码的 docType getter
  DocCategory get docType => docCategory;

  DocForgeDocument copyWith({
    double? progress,
    String? progressMsg,
    Map<String, dynamic>? progressDetail,
    DocStatus? status,
  }) =>
      DocForgeDocument(
        id: id,
        title: title,
        docCategory: docCategory,
        sourceType: sourceType,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        progressMsg: progressMsg ?? this.progressMsg,
        progressDetail: progressDetail ?? this.progressDetail,
        dslContent: dslContent,
        errorMsg: errorMsg,
        wordCount: wordCount,
        outline: outline,
        reviewResult: reviewResult,
        fileUrl: fileUrl,
        sourceLang: sourceLang,
        targetLang: targetLang,
        templateId: templateId,
        createdAt: createdAt,
        startedAt: startedAt,
        completedAt: completedAt,
      );

  factory DocForgeDocument.fromJson(Map<String, dynamic> json) => DocForgeDocument(
        id: json['id'] as int,
        title: json['title'] as String? ?? '未命名文档',
        docCategory: DocCategory.fromCode(json['doc_type'] as String?),
        sourceType: SourceType.values.firstWhere(
          (e) => e.code == json['source_type'],
          orElse: () => SourceType.generate,
        ),
        status: DocStatus.values.firstWhere(
          (e) => e.code == json['status'],
          orElse: () => DocStatus.completed,
        ),
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        progressMsg: json['progress_msg'] as String?,
        progressDetail: json['progress_detail'] as Map<String, dynamic>?,
        dslContent: json['dsl_content'],
        errorMsg: json['error_msg'] as String?,
        wordCount: json['word_count'] as int?,
        outline: json['outline'],
        reviewResult: json['review_result'],
        fileUrl: json['file_url'] as String?,
        sourceLang: json['source_lang'] as String?,
        targetLang: json['target_lang'] as String?,
        templateId: json['template_id'] as int?,
        createdAt: json['created_at'] as String?,
        startedAt: json['started_at'] as String?,
        completedAt: json['completed_at'] as String?,
      );
}

/// SSE 进度更新
class DocProgress {
  final double progress;
  final String message;
  final Map<String, dynamic>? detail;

  const DocProgress({required this.progress, required this.message, this.detail});
}
