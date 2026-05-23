import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import 'models/glossary_models.dart';

class GlossaryDataSource {
  /// 获取术语列表
  Future<List<GlossaryEntry>> getGlossaryList({
    String? languagePair,
  }) async {
    try {
      final response = await ApiClient.instance.get(
        AppConstants.glossaryListUrl,
        queryParameters: {
          if (languagePair != null) 'language_pair': languagePair,
        },
      );
      final data = response.data['data'] as List<dynamic>?;
      if (data == null) return [];
      return data.map((e) => _parseEntry(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 添加术语
  Future<GlossaryEntry?> addEntry(GlossaryEntry entry) async {
    try {
      final pair = LanguagePair.defaults.firstWhere(
        (p) => p.label == entry.languagePairLabel,
        orElse: () => LanguagePair.defaults.first,
      );
      final response = await ApiClient.instance.post(
        AppConstants.glossaryAddUrl,
        data: {
          'source_term': entry.sourceTerm,
          'target_term': entry.targetTerm,
          'source_lang': pair.sourceCode,
          'target_lang': pair.targetCode,
          'context': entry.note,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      return entry.copyWith(id: data['id'] as int? ?? entry.id);
    } catch (_) {
      return null;
    }
  }

  /// 更新术语
  Future<GlossaryEntry?> updateEntry(GlossaryEntry entry) async {
    try {
      final pair = LanguagePair.defaults.firstWhere(
        (p) => p.label == entry.languagePairLabel,
        orElse: () => LanguagePair.defaults.first,
      );
      final response = await ApiClient.instance.put(
        AppConstants.glossaryUpdateUrl(entry.id),
        data: {
          'source_term': entry.sourceTerm,
          'target_term': entry.targetTerm,
          'source_lang': pair.sourceCode,
          'target_lang': pair.targetCode,
          'context': entry.note,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      return _parseEntry(data);
    } catch (_) {
      return null;
    }
  }

  /// 删除术语
  Future<bool> deleteEntry(int id) async {
    try {
      await ApiClient.instance.delete(AppConstants.glossaryDeleteUrl(id));
      return true;
    } catch (_) {
      return false;
    }
  }

  GlossaryEntry _parseEntry(Map<String, dynamic> json) {
    final sourceLang = json['source_lang'] as String? ?? '';
    final targetLang = json['target_lang'] as String? ?? '';
    final label = _buildLabel(sourceLang, targetLang);
    return GlossaryEntry(
      id: json['id'] as int? ?? 0,
      sourceTerm: json['source_term'] as String? ?? '',
      targetTerm: json['target_term'] as String? ?? '',
      languagePairLabel: label,
      note: json['context'] as String? ?? json['note'] as String?,
    );
  }

  String _buildLabel(String sourceCode, String targetCode) {
    try {
      final source = LanguagePair.defaults.firstWhere(
        (p) => p.sourceCode == sourceCode,
        orElse: () => LanguagePair.defaults.first,
      );
      final sourceName = source.sourceName;
      final target = LanguagePair.defaults.firstWhere(
        (p) => p.targetCode == targetCode,
        orElse: () => LanguagePair.defaults.first,
      );
      final targetName = target.targetName;
      return '$sourceName → $targetName';
    } catch (_) {
      return '$sourceCode → $targetCode';
    }
  }
}
