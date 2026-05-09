import 'dart:async';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/sse/sse_client.dart';
import 'models/translate_models.dart';

class TranslateDataSource {
  Stream<SseEvent> translateTextStream(TranslateRequest request) {
    return SseClient.connect(
      '${AppConstants.apiBaseUrl}/translate/text',
      data: request.toJson(),
    );
  }

  Future<Map<String, dynamic>> translateDocument({
    required String filePath,
    required Language sourceLang,
    required Language targetLang,
    List<GlossaryTerm> glossary = const [],
  }) async {
    final response = await ApiClient.instance.post(
      '${AppConstants.apiBaseUrl}/translate/document',
      data: {
        'file_path': filePath,
        'source_lang': sourceLang.code,
        'target_lang': targetLang.code,
        'glossary': glossary.map((g) => g.toJson()).toList(),
      },
    );
    return response.data['data'] ?? response.data;
  }

  Future<void> exportDocument({
    required String translatedContent,
    required ExportFormat format,
    required String sourceLang,
    required String targetLang,
  }) async {
    await ApiClient.instance.post(
      '${AppConstants.apiBaseUrl}/translate/export',
      data: {
        'content': translatedContent,
        'format': format.name,
        'source_lang': sourceLang,
        'target_lang': targetLang,
      },
    );
  }

  Future<List<GlossaryTerm>> getGlossary() async {
    final response = await ApiClient.instance.get(
      '${AppConstants.apiBaseUrl}/translate/glossary',
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => GlossaryTerm.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
