/// 草稿数据模型
class Draft {
  final String id;
  final String title;
  final String content;
  final String docType; // contract, report, bid, paper, etc.
  final String updatedAt;

  const Draft({
    required this.id,
    required this.title,
    required this.content,
    required this.docType,
    required this.updatedAt,
  });

  /// 进度（0.0 ~ 1.0），基于内容长度估算
  double get progress {
    if (content.isEmpty) return 0.0;
    // 简单启发式：每 500 字符约 10% 进度，上限 0.95（未完成）
    final estimate = (content.length / 5000).clamp(0.1, 0.95);
    return estimate;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'docType': docType,
        'updatedAt': updatedAt,
      };

  factory Draft.fromJson(Map<String, dynamic> json) => Draft(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        docType: json['docType'] as String? ?? 'default',
        updatedAt: json['updatedAt'] as String? ?? '',
      );

  Draft copyWith({
    String? title,
    String? content,
    String? docType,
    String? updatedAt,
  }) {
    return Draft(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      docType: docType ?? this.docType,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
