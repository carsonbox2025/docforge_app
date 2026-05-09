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

enum TranslateStage { input, result }

class GlossaryTerm {
  final String source;
  final String target;

  const GlossaryTerm({required this.source, required this.target});

  Map<String, dynamic> toJson() => {'source': source, 'target': target};

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) =>
      GlossaryTerm(source: json['source'] as String, target: json['target'] as String);
}

class TranslateRequest {
  final String text;
  final Language sourceLang;
  final Language targetLang;
  final List<GlossaryTerm> glossary;

  const TranslateRequest({
    required this.text,
    required this.sourceLang,
    required this.targetLang,
    this.glossary = const [],
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'source_lang': sourceLang.code,
        'target_lang': targetLang.code,
        'glossary': glossary.map((g) => g.toJson()).toList(),
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
