import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../generate/data/task_data_source.dart';
import 'models/polish_models.dart';

class PolishRemoteDataSource {
  final TaskDataSource _taskDs = TaskDataSource();

  /// 提交精修任务（通过统一任务服务）
  Future<int> submitPolishTask(PolishRequest request) async {
    final isLongDoc = request.inputMode == InputMode.upload;
    return _taskDs.submitTask(
      taskType: TaskType.polish,
      docType: request.docType,
      userInput: {
        'text': request.text ?? '',
        'polish_level': request.level.value,
        'doc_type': request.docType,
        'file_path': request.filePath,
        'scene_id': isLongDoc ? 'scene_polish_long' : 'scene_polish',
        'layer': isLongDoc ? 2 : 1,
      },
      title: request.fileName ?? '未命名',
    );
  }

  /// 任务进度流（SSE）
  Stream<TaskProgress> polishProgressStream(int taskId) {
    return _taskDs.progressStream(taskId);
  }

  /// 查询任务状态
  Future<TaskStatusData> getTaskStatus(int taskId) {
    return _taskDs.getTaskStatus(taskId);
  }

  /// 上传文件
  Future<Map<String, dynamic>> uploadFile(File file) async {
    final fileName = file.path.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: MediaType(
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

  /// 导出精修结果
  Future<Response> exportWord({
    required int documentId,
    required ExportMode exportMode,
    required List<PolishSuggestion> suggestions,
  }) async {
    return ApiClient.instance.post(
      '${AppConstants.apiBaseUrl}/export/word',
      data: {
        'document_id': documentId,
        'export_mode': exportMode.value,
        'suggestions': suggestions.map((s) => s.toJson()).toList(),
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// 确认精修结果 — 将用户审阅决策回写到数据库
  Future<void> confirmPolish({
    required int documentId,
    required List<PolishSuggestion> suggestions,
  }) async {
    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      '${AppConstants.apiBaseUrl}/document/polish/confirm',
      data: {
        'document_id': documentId,
        'suggestions': suggestions.map((s) => s.toJson()).toList(),
      },
    );
    final data = response.data;
    if (data == null || data['code'] != 200) {
      throw Exception(data?['message'] ?? '确认失败');
    }
  }
}
