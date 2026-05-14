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
        '${AppConstants.apiBaseUrl}/glossary',
        queryParameters: {
          'language_pair': ?languagePair,
        },
      );
      final data = response.data['data'] as List<dynamic>?;
      if (data == null) return [];
      return data.map((e) => _parseEntry(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _getMockData();
    }
  }

  /// 添加术语
  Future<GlossaryEntry?> addEntry(GlossaryEntry entry) async {
    try {
      final response = await ApiClient.instance.post(
        '${AppConstants.apiBaseUrl}/glossary',
        data: {
          'source_term': entry.sourceTerm,
          'target_term': entry.targetTerm,
          'language_pair': entry.languagePairLabel,
          'note': entry.note,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      return _parseEntry(data);
    } catch (_) {
      return null;
    }
  }

  /// 更新术语
  Future<GlossaryEntry?> updateEntry(GlossaryEntry entry) async {
    try {
      final response = await ApiClient.instance.put(
        '${AppConstants.apiBaseUrl}/glossary/${entry.id}',
        data: {
          'source_term': entry.sourceTerm,
          'target_term': entry.targetTerm,
          'language_pair': entry.languagePairLabel,
          'note': entry.note,
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
      await ApiClient.instance.delete('${AppConstants.apiBaseUrl}/glossary/$id');
      return true;
    } catch (_) {
      return false;
    }
  }

  GlossaryEntry _parseEntry(Map<String, dynamic> json) {
    return GlossaryEntry(
      id: json['id'] as int? ?? 0,
      sourceTerm: json['source_term'] as String? ?? '',
      targetTerm: json['target_term'] as String? ?? '',
      languagePairLabel: json['language_pair'] as String? ?? '',
      note: json['note'] as String?,
    );
  }

  List<GlossaryEntry> _getMockData() {
    return const [
      GlossaryEntry(id: 1, sourceTerm: '合同', targetTerm: 'Contract', languagePairLabel: '中文 → English', note: '法律文件'),
      GlossaryEntry(id: 2, sourceTerm: '甲方', targetTerm: 'Party A', languagePairLabel: '中文 → English', note: ''),
      GlossaryEntry(id: 3, sourceTerm: '乙方', targetTerm: 'Party B', languagePairLabel: '中文 → English', note: ''),
      GlossaryEntry(id: 4, sourceTerm: '知识产权', targetTerm: 'Intellectual Property', languagePairLabel: '中文 → English', note: ''),
      GlossaryEntry(id: 5, sourceTerm: '合同', targetTerm: '契約', languagePairLabel: '中文 → 日本語', note: ''),
      GlossaryEntry(id: 6, sourceTerm: '保密条款', targetTerm: 'Non-disclosure Agreement', languagePairLabel: '中文 → English', note: 'NDA'),
      GlossaryEntry(id: 7, sourceTerm: '违约', targetTerm: 'Breach of Contract', languagePairLabel: '中文 → English', note: ''),
      GlossaryEntry(id: 8, sourceTerm: '招标', targetTerm: 'Tender / Bidding', languagePairLabel: '中文 → English', note: ''),
    ];
  }
}
