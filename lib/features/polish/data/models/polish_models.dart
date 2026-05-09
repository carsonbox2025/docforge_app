import 'package:flutter/foundation.dart';
export '../../../../shared/models/export_format.dart';

/// 润色强度
enum PolishLevel {
  light('light', '轻度', '仅修正错误'),
  medium('medium', '中度', '优化表达'),
  deep('deep', '深度', '重写提升');

  final String value;
  final String label;
  final String description;
  const PolishLevel(this.value, this.label, this.description);
}

/// 输入模式
enum InputMode {
  upload,
  text,
}

/// 文档类型 pill
class DocTypePill {
  final String label;
  final bool isAutoDetect;
  const DocTypePill({required this.label, this.isAutoDetect = false});

  static const List<DocTypePill> defaults = [
    DocTypePill(label: '自动检测', isAutoDetect: true),
    DocTypePill(label: '合同'),
    DocTypePill(label: '公文'),
    DocTypePill(label: '报告'),
    DocTypePill(label: '论文'),
    DocTypePill(label: '简历'),
  ];
}

/// 结果页 Tab
enum CompareTab {
  diff('修订对比'),
  polished('仅润色'),
  original('仅原文');

  final String label;
  const CompareTab(this.label);
}

/// 润色请求
class PolishRequest {
  final String? text;
  final String? filePath;
  final InputMode inputMode;
  final PolishLevel level;
  final String docType;
  final String? fileName;

  const PolishRequest({
    this.text,
    this.filePath,
    required this.inputMode,
    required this.level,
    required this.docType,
    this.fileName,
  });

  Map<String, dynamic> toJson() => {
        if (text != null) 'text': text,
        if (filePath != null) 'file_path': filePath,
        'input_mode': inputMode.name,
        'level': level.value,
        'doc_type': docType,
      };
}

/// 单条修订
class DiffSegment {
  final String type; // 'equal', 'delete', 'insert', 'highlight'
  final String text;

  const DiffSegment({required this.type, required this.text});
}

/// 润色段落
class PolishParagraph {
  final List<DiffSegment> segments;

  const PolishParagraph({required this.segments});

  factory PolishParagraph.fromDiffSegments(List<DiffSegment> segments) =>
      PolishParagraph(segments: segments);
}

/// 润色结果
class PolishResult {
  final String title;
  final PolishLevel level;
  final int changeCount;
  final int acceptedCount;
  final int pendingCount;
  final List<PolishParagraph> paragraphs;
  final String? originalText;
  final String? polishedText;

  const PolishResult({
    required this.title,
    required this.level,
    required this.changeCount,
    this.acceptedCount = 0,
    this.pendingCount = 0,
    this.paragraphs = const [],
    this.originalText,
    this.polishedText,
  });
}
