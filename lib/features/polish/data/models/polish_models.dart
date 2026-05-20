/// 润色强度
enum PolishLevel {
  light('light', '轻度', '仅修正错误'),
  medium('normal', '中度', '优化表达'),
  deep('deep', '深度', '全面审阅');

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

/// 导出模式
enum ExportMode {
  original('original', '原格式导出'),
  professional('professional', '专业排版导出'),
  trackChanges('track_changes', '修订模式导出'),
  report('report', '审阅报告');

  final String value;
  final String label;
  const ExportMode(this.value, this.label);
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
    DocTypePill(label: '论文'),
    DocTypePill(label: '通用'),
  ];
}

/// 审阅阶段
enum PolishStage { input, reviewing, review }

/// 精修建议卡片
class PolishSuggestion {
  final String id;
  final int paragraphIndex;
  final String sectionId;
  final String original;
  final String suggested;
  final String category;
  final String severity;
  final String reason;
  final String status;
  final int startIndex;
  final int endIndex;
  final int tableIndex;
  final int cellIndex;

  PolishSuggestion({
    required this.id,
    required this.paragraphIndex,
    required this.sectionId,
    required this.original,
    required this.suggested,
    required this.category,
    required this.severity,
    required this.reason,
    this.status = 'pending',
    this.startIndex = -1,
    this.endIndex = -1,
    this.tableIndex = -1,
    this.cellIndex = -1,
  });

  factory PolishSuggestion.fromJson(Map<String, dynamic> json) {
    return PolishSuggestion(
      id: json['id'] as String? ?? '',
      paragraphIndex: json['paragraph_index'] as int? ?? 0,
      sectionId: json['section_id'] as String? ?? 'main',
      original: json['original'] as String? ?? '',
      suggested: json['suggested'] as String? ?? '',
      category: json['category'] as String? ?? 'style',
      severity: json['severity'] as String? ?? 'suggestion',
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      startIndex: json['start_offset'] as int? ?? -1,
      endIndex: json['end_offset'] as int? ?? -1,
      tableIndex: json['table_index'] as int? ?? -1,
      cellIndex: json['cell_index'] as int? ?? -1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
      };

  PolishSuggestion copyWith({String? status}) => PolishSuggestion(
        id: id,
        paragraphIndex: paragraphIndex,
        sectionId: sectionId,
        original: original,
        suggested: suggested,
        category: category,
        severity: severity,
        reason: reason,
        status: status ?? this.status,
        startIndex: startIndex,
        endIndex: endIndex,
        tableIndex: tableIndex,
        cellIndex: cellIndex,
      );
}

/// 原始段落
class SourceParagraph {
  final int index;
  final String text;
  final String sectionId;
  final String styleName;
  final bool isTable;
  final int tableIndex;
  final int cellIndex;

  const SourceParagraph({
    required this.index,
    required this.text,
    required this.sectionId,
    required this.styleName,
    this.isTable = false,
    this.tableIndex = -1,
    this.cellIndex = -1,
  });

  factory SourceParagraph.fromJson(Map<String, dynamic> json) {
    return SourceParagraph(
      index: json['index'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? 'main',
      styleName: json['style_name'] as String? ?? 'Normal',
      isTable: json['is_table'] as bool? ?? false,
      tableIndex: json['table_index'] as int? ?? -1,
      cellIndex: json['cell_index'] as int? ?? -1,
    );
  }
}

/// 大纲条目
class OutlineItem {
  final String id;
  final String title;
  String status;

  OutlineItem({required this.id, required this.title, this.status = 'pending'});

  factory OutlineItem.fromJson(Map<String, dynamic> json) {
    return OutlineItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
    );
  }
}

/// Undo/Redo 操作记录
class PolishUndoAction {
  final String action;
  final String suggestionId;
  final String previousStatus;

  const PolishUndoAction({
    required this.action,
    required this.suggestionId,
    required this.previousStatus,
  });
}

/// 精修请求
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
        'polish_level': level.value,
        'doc_type': _mapDocType(docType),
      };

  static String _mapDocType(String label) {
    const mapping = {
      '自动检测': 'generic',
      '合同': 'contract',
      '公文': 'official',
      '论文': 'thesis',
      '通用': 'generic',
    };
    return mapping[label] ?? 'generic';
  }
}
