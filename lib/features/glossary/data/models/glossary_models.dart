/// 语言对
class LanguagePair {
  final String sourceCode;
  final String sourceName;
  final String targetCode;
  final String targetName;

  const LanguagePair({
    required this.sourceCode,
    required this.sourceName,
    required this.targetCode,
    required this.targetName,
  });

  String get label => '$sourceName → $targetName';

  static const List<LanguagePair> defaults = [
    LanguagePair(sourceCode: 'zh-CN', sourceName: '中文', targetCode: 'en-US', targetName: 'English'),
    LanguagePair(sourceCode: 'zh-CN', sourceName: '中文', targetCode: 'ja-JP', targetName: '日本語'),
    LanguagePair(sourceCode: 'zh-CN', sourceName: '中文', targetCode: 'ko-KR', targetName: '한국어'),
    LanguagePair(sourceCode: 'en-US', sourceName: 'English', targetCode: 'zh-CN', targetName: '中文'),
    LanguagePair(sourceCode: 'en-US', sourceName: 'English', targetCode: 'ja-JP', targetName: '日本語'),
  ];
}

/// 术语条目
class GlossaryEntry {
  final int id;
  final String sourceTerm;
  final String targetTerm;
  final String languagePairLabel;
  final String? note;

  const GlossaryEntry({
    required this.id,
    required this.sourceTerm,
    required this.targetTerm,
    required this.languagePairLabel,
    this.note,
  });

  GlossaryEntry copyWith({
    int? id,
    String? sourceTerm,
    String? targetTerm,
    String? languagePairLabel,
    String? note,
  }) {
    return GlossaryEntry(
      id: id ?? this.id,
      sourceTerm: sourceTerm ?? this.sourceTerm,
      targetTerm: targetTerm ?? this.targetTerm,
      languagePairLabel: languagePairLabel ?? this.languagePairLabel,
      note: note ?? this.note,
    );
  }
}
