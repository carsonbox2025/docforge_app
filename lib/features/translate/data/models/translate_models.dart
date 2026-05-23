import 'dart:math';
import '../../../../shared/models/export_format.dart';
export '../../../../shared/models/export_format.dart';

class Language {
  final String code;
  final String name;

  const Language({required this.code, required this.name});

  static const zhCN = Language(code: 'zh-CN', name: '中文');
  static const enUS = Language(code: 'en-US', name: 'English');
  static const jaJP = Language(code: 'ja-JP', name: '日本語');
  static const koKR = Language(code: 'ko-KR', name: '한국어');
  static const frFR = Language(code: 'fr-FR', name: 'Français');
  static const deDE = Language(code: 'de-DE', name: 'Deutsch');

  static const List<Language> all = [
    zhCN, enUS, jaJP, koKR, frFR, deDE,
  ];
}

enum TranslateMode { text, document }

enum TranslateStage { input, translating, result }

class GlossaryTerm {
  final String source;
  final String target;

  const GlossaryTerm({required this.source, required this.target});

  Map<String, dynamic> toJson() => {'source': source, 'target': target};

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) =>
      GlossaryTerm(source: json['source'] as String, target: json['target'] as String);
}

class IndustryOption {
  final String value;
  final String label;

  const IndustryOption({required this.value, required this.label});

  static const List<IndustryOption> all = [
    IndustryOption(value: 'general', label: '通用'),
    IndustryOption(value: 'legal', label: '法律'),
    IndustryOption(value: 'tech', label: '科技'),
    IndustryOption(value: 'medical', label: '医疗'),
    IndustryOption(value: 'finance', label: '金融'),
    IndustryOption(value: 'academic', label: '学术'),
  ];
}

class DocTypeOption {
  final String value;
  final String label;

  const DocTypeOption({required this.value, required this.label});

  static const List<DocTypeOption> all = [
    DocTypeOption(value: 'auto', label: '自动检测'),
    DocTypeOption(value: 'contract', label: '合同'),
    DocTypeOption(value: 'official', label: '公文'),
    DocTypeOption(value: 'thesis', label: '论文'),
    DocTypeOption(value: 'generic', label: '通用'),
  ];
}

class ParagraphProgress {
  final int index;
  final int total;
  final String preview;
  final String fullSource;
  final String translated;
  final bool isComplete;

  const ParagraphProgress({
    required this.index,
    required this.total,
    this.preview = '',
    this.fullSource = '',
    this.translated = '',
    this.isComplete = false,
  });

  ParagraphProgress copyWith({
    String? translated,
    bool? isComplete,
  }) =>
      ParagraphProgress(
        index: index,
        total: total,
        preview: preview,
        fullSource: fullSource,
        translated: translated ?? this.translated,
        isComplete: isComplete ?? this.isComplete,
      );
}

class ExtractedTerm {
  final String source;
  final String target;

  const ExtractedTerm({required this.source, required this.target});

  factory ExtractedTerm.fromJson(Map<String, dynamic> json) => ExtractedTerm(
        source: json['source'] as String? ?? '',
        target: json['target'] as String? ?? '',
      );
}

class TermHighlight {
  final int start;
  final int end;
  final String term;
  final String translated;

  const TermHighlight({
    required this.start,
    required this.end,
    required this.term,
    required this.translated,
  });
}

class BilingualParagraph {
  final int index;
  final String source;
  final String translated;
  final List<TermHighlight> highlights;

  const BilingualParagraph({
    required this.index,
    required this.source,
    required this.translated,
    this.highlights = const [],
  });
}

class TranslateRequest {
  final String text;
  final Language sourceLang;
  final Language targetLang;
  final List<GlossaryTerm> glossary;
  final String docType;
  final String industry;
  final String customRequirements;

  const TranslateRequest({
    required this.text,
    required this.sourceLang,
    required this.targetLang,
    this.glossary = const [],
    this.docType = 'generic',
    this.industry = 'general',
    this.customRequirements = '',
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'source_lang': sourceLang.code,
        'target_lang': targetLang.code,
        'glossary': glossary.map((g) => g.toJson()).toList(),
        'doc_type': docType,
        'industry': industry,
        'custom_requirements': customRequirements,
      };
}

class TranslateResult {
  final String translatedText;
  final List<GlossaryTerm> appliedGlossary;
  final String? paragraphTitle;

  const TranslateResult({
    required this.translatedText,
    this.appliedGlossary = const [],
    this.paragraphTitle,
  });

  factory TranslateResult.fromJson(Map<String, dynamic> json) => TranslateResult(
        translatedText: json['translated_text'] as String,
        appliedGlossary: (json['applied_glossary'] as List<dynamic>?)
                ?.map((e) => GlossaryTerm.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        paragraphTitle: json['paragraph_title'] as String?,
      );
}

class ExportFormatOption {
  final ExportFormat format;
  final String name;
  final String extension;

  const ExportFormatOption({
    required this.format,
    required this.name,
    required this.extension,
  });

  static const List<ExportFormatOption> all = [
    ExportFormatOption(format: ExportFormat.docx, name: 'Word', extension: '.docx'),
    ExportFormatOption(format: ExportFormat.pdf, name: 'PDF', extension: '.pdf'),
    ExportFormatOption(format: ExportFormat.html, name: 'HTML', extension: '.html'),
  ];
}

List<BilingualParagraph> buildBilingualParagraphs(
  List<String> sourceParagraphs,
  List<String> translatedParagraphs,
  List<ExtractedTerm> terms,
) {
  final maxLen = max(sourceParagraphs.length, translatedParagraphs.length);
  final paddedSource = List.generate(
    maxLen,
    (i) => i < sourceParagraphs.length ? sourceParagraphs[i] : '',
  );
  final paddedTranslated = List.generate(
    maxLen,
    (i) => i < translatedParagraphs.length ? translatedParagraphs[i] : '',
  );

  return List.generate(maxLen, (i) {
    final highlights = _findTermHighlights(paddedTranslated[i], terms);
    return BilingualParagraph(
      index: i,
      source: paddedSource[i],
      translated: paddedTranslated[i],
      highlights: highlights,
    );
  });
}

List<TermHighlight> _findTermHighlights(String text, List<ExtractedTerm> terms) {
  return terms
      .where((t) => t.target.isNotEmpty)
      .map((t) {
        final idx = text.indexOf(t.target);
        if (idx < 0) return null;
        return TermHighlight(
          start: idx,
          end: idx + t.target.length,
          term: t.source,
          translated: t.target,
        );
      })
      .whereType<TermHighlight>()
      .toList();
}
