import 'dart:async';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/sse/sse_client.dart';
import '../../generate/data/task_data_source.dart';
import 'models/translate_models.dart';

class TranslateDataSource {
  final TaskDataSource _taskDs = TaskDataSource();

  /// 提交翻译任务（通过统一任务服务）
  Future<int> submitTranslateTask(TranslateRequest request, {String mode = 'quick'}) {
    return _taskDs.submitTask(
      taskType: TaskType.translate,
      userInput: {
        'text': request.text,
        'mode': mode,
      },
      title: '翻译文档',
      sourceLang: request.sourceLang.code,
      targetLang: request.targetLang.code,
    );
  }

  /// 任务进度流（SSE）
  Stream<TaskProgress> translateProgressStream(int taskId) {
    return _taskDs.progressStream(taskId);
  }

  /// 查询任务状态
  Future<TaskStatusData> getTaskStatus(int taskId) {
    return _taskDs.getTaskStatus(taskId);
  }

  /// 旧接口兼容：直连 SSE 翻译
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

  Future<List<int>> exportDocument({
    required String translatedContent,
    required ExportFormat format,
    required String sourceLang,
    required String targetLang,
  }) async {
    final response = await ApiClient.instance.post<List<int>>(
      '${AppConstants.apiBaseUrl}/translate/document/export',
      data: {
        'content': translatedContent,
        'format': format.name,
        'source_lang': sourceLang,
        'target_lang': targetLang,
      },
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
}
