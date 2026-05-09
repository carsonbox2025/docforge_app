import 'package:flutter/material.dart';

/// 历史文档操作类型
enum HistoryDocType {
  generated('generated', '生成', Icons.bolt, Color(0xFF2563EB), Color(0x0F2563EB)),
  polished('polished', '精修', Icons.auto_fix_high, Color(0xFF10B981), Color(0x0F10B981)),
  translated('translated', '翻译', Icons.translate, Color(0xFFF97316), Color(0x0FF97316));

  const HistoryDocType(this.code, this.label, this.icon, this.color, this.bgColor);

  final String code;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
}

/// 文档状态
enum DocStatus {
  completed('completed', '已完成', Color(0xFF10B981), Color(0x0F10B981)),
  processing('processing', '处理中', Color(0xFF2563EB), Color(0x0F2563EB)),
  failed('failed', '失败', Color(0xFFEF4444), Color(0x0FEF4444)),
  draft('draft', '草稿', Color(0xFF94A3B8), Color(0xFFF1F5F9));

  const DocStatus(this.code, this.label, this.color, this.bgColor);

  final String code;
  final String label;
  final Color color;
  final Color bgColor;
}

/// 历史筛选 Tab
enum HistoryFilter {
  all('全部'),
  generated('生成'),
  polished('精修'),
  translated('翻译');

  const HistoryFilter(this.label);
  final String label;
}

/// 文档分类
enum DocCategory {
  contract('合同'),
  bid('标书'),
  official('公文'),
  report('报告'),
  paper('论文'),
  resume('简历'),
  minutes('纪要'),
  proposal('方案');

  const DocCategory(this.label);
  final String label;
}

/// 历史文档模型
class HistoryDocument {
  final int id;
  final String title;
  final HistoryDocType docType;
  final DocStatus status;
  final DocCategory category;
  final int wordCount;
  final String createdAt;
  final String? summary;

  const HistoryDocument({
    required this.id,
    required this.title,
    required this.docType,
    required this.status,
    this.category = DocCategory.contract,
    this.wordCount = 0,
    required this.createdAt,
    this.summary,
  });
}

/// 审校结果
class ReviewResult {
  final int passCount;
  final int warnCount;
  final int errorCount;
  final List<ReviewIssue> issues;

  const ReviewResult({
    this.passCount = 0,
    this.warnCount = 0,
    this.errorCount = 0,
    this.issues = const [],
  });
}

/// 审校问题项
class ReviewIssue {
  final String level; // 'pass', 'warn', 'error', 'info'
  final String message;
  final String location;

  const ReviewIssue({
    required this.level,
    required this.message,
    required this.location,
  });
}
