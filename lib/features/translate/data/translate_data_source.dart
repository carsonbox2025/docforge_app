import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../generate/data/task_data_source.dart';
import 'models/translate_models.dart';

class TranslateDataSource {
  final TaskDataSource _taskDs = TaskDataSource();

  Future<int> submitTranslateTask(TranslateRequest request) {
    return _taskDs.submitTask(
      taskType: TaskType.translate,
      userInput: {
        'text': request.text,
        'mode': 'professional',
        'doc_type': request.docType,
        'industry': request.industry,
        'custom_requirements': request.customRequirements,
      },
      title: '未命名',
      sourceLang: request.sourceLang.code,
      targetLang: request.targetLang.code,
    );
  }

  Future<int> submitTranslateDocumentTask({
    required String serverFilePath,
    required String fileName,
    required Language sourceLang,
    required Language targetLang,
    String docType = 'generic',
    String industry = 'general',
    String customRequirements = '',
  }) {
    return _taskDs.submitTask(
      taskType: TaskType.translate,
      userInput: {
        'file_path': serverFilePath,
        'mode': 'professional',
        'doc_type': docType,
        'industry': industry,
        'custom_requirements': customRequirements,
      },
      title: fileName,
      sourceLang: sourceLang.code,
      targetLang: targetLang.code,
    );
  }

  Stream<TaskProgress> translateProgressStream(int taskId) {
    return _taskDs.progressStream(taskId);
  }

  Future<bool> cancelTask(int taskId) {
    return _taskDs.cancelTask(taskId);
  }

  Future<TaskStatusData> getTaskStatus(int taskId) {
    return _taskDs.getTaskStatus(taskId);
  }

  Future<Map<String, dynamic>> uploadFile(String localPath) async {
    final fileName = localPath.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        localPath,
        filename: fileName,
        contentType: DioMediaType(
          ext == 'docx' ? 'application' : 'text',
          ext == 'docx'
              ? 'vnd.openxmlformats-officedocument.wordprocessingml.document'
              : ext,
        ),
      ),
    });

    final response = await ApiClient.instance.post(
      '${AppConstants.apiBaseUrl}/document/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    final data = response.data;
    if (data is Map && data['code'] == 200 && data['data'] != null) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception('文件上传失败');
  }

  Future<List<int>> exportDocument(int documentId) async {
    final response = await ApiClient.instance.post<List<int>>(
      '/export/word',
      data: {'document_id': documentId},
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
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

  Future<List<ExtractedTerm>> getAutoSavedTerms({
    String? sourceLang,
    String? targetLang,
  }) async {
    final queryParams = <String, dynamic>{};
    if (sourceLang != null) queryParams['source_lang'] = sourceLang;
    if (targetLang != null) queryParams['target_lang'] = targetLang;

    final response = await ApiClient.instance.get(
      '${AppConstants.apiBaseUrl}/translate/glossary/auto-saved',
      queryParameters: queryParams,
    );
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => ExtractedTerm.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> deleteAutoSavedTerm(int termId) async {
    final response = await ApiClient.instance.delete<Map<String, dynamic>>(
      '${AppConstants.apiBaseUrl}/translate/glossary/term/$termId',
    );
    return response.data?['code'] == 200;
  }

  Future<int> mergeTerms({
    required List<Map<String, String>> terms,
    required String sourceLang,
    required String targetLang,
  }) async {
    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      '${AppConstants.apiBaseUrl}/translate/glossary/merge',
      data: {
        'terms': terms,
        'source_lang': sourceLang,
        'target_lang': targetLang,
      },
    );
    return response.data?['data']?['merged_count'] as int? ?? 0;
  }
}
