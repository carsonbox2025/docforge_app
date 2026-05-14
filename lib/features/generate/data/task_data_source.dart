import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

/// 任务类型（兼容旧引用）
enum TaskType { generate, polish, translate }

/// 任务状态（兼容旧引用）
enum TaskStatus {
  pending,
  running,
  completed,
  failed,
  cancelled;

  bool get isTerminal =>
      this == TaskStatus.completed ||
      this == TaskStatus.failed ||
      this == TaskStatus.cancelled;
}

/// 任务进度更新
class TaskProgress {
  final double progress;
  final String message;
  final Map<String, dynamic>? detail;

  const TaskProgress({
    required this.progress,
    required this.message,
    this.detail,
  });
}

/// 任务状态响应（兼容旧引用）
class TaskStatusData {
  final int id;
  final TaskType taskType;
  final TaskStatus status;
  final double progress;
  final String? progressMsg;
  final Map<String, dynamic>? progressDetail;
  final Map<String, dynamic>? resultData;
  final String? errorMsg;
  final int? documentId;
  final String? title;
  final String? createdAt;
  final String? completedAt;

  const TaskStatusData({
    required this.id,
    required this.taskType,
    required this.status,
    this.progress = 0,
    this.progressMsg,
    this.progressDetail,
    this.resultData,
    this.errorMsg,
    this.documentId,
    this.title,
    this.createdAt,
    this.completedAt,
  });

  factory TaskStatusData.fromJson(Map<String, dynamic> json) => TaskStatusData(
        id: json['id'] as int,
        taskType: TaskType.values.firstWhere(
          (e) => e.name == (json['doc_type'] ?? json['task_type']),
          orElse: () => TaskType.generate,
        ),
        status: TaskStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TaskStatus.pending,
        ),
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        progressMsg: json['progress_msg'] as String?,
        progressDetail: json['progress_detail'] as Map<String, dynamic>?,
        resultData: json['result_data'] as Map<String, dynamic>?,
        errorMsg: json['error_msg'] as String?,
        documentId: (json['document_id'] as int?) ?? (json['id'] as int?),
        title: json['title'] as String?,
        createdAt: json['created_at'] as String?,
        completedAt: json['completed_at'] as String?,
      );
}

class TaskDataSource {
  /// 提交异步任务 → 统一 /document/submit
  Future<int> submitTask({
    required TaskType taskType,
    required Map<String, dynamic> userInput,
    String? templateId,
    String? title,
    String? polishLevel,
    String? sourceLang,
    String? targetLang,
    String docType = 'generic',
  }) async {
    final payload = {
      'doc_type': docType,
      'source_type': taskType.name,
      'user_input': userInput,
      'template_id': ?templateId,
      'title': ?title,
      'polish_level': ?polishLevel,
      'source_lang': ?sourceLang,
      'target_lang': ?targetLang,
    };
    _log('[TaskDataSource] submitTask: docType=$docType, taskType=${taskType.name}, '
        'templateId=$templateId, sceneId=${userInput['scene_id']}, layer=${userInput['layer']}');

    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      '/document/submit',
      data: payload,
    );
    final data = response.data!;
    if (data['code'] != 200) {
      _log('[TaskDataSource] submitTask FAILED: code=${data['code']}, message=${data['message']}');
      throw Exception(data['message'] ?? '任务提交失败');
    }
    final taskId = data['data']['id'] as int;
    _log('[TaskDataSource] submitTask success: taskId=$taskId');
    return taskId;
  }

  /// 查询任务状态 → GET /document/{id}
  Future<TaskStatusData> getTaskStatus(int taskId) async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/document/$taskId',
    );
    final data = response.data!;
    if (data['code'] != 200) {
      _log('[TaskDataSource] getTaskStatus FAILED: taskId=$taskId, code=${data['code']}');
      throw Exception(data['message'] ?? '查询失败');
    }
    final statusData = TaskStatusData.fromJson(data['data'] as Map<String, dynamic>);
    _log('[TaskDataSource] getTaskStatus: taskId=$taskId, status=${statusData.status}, '
        'progress=${statusData.progress}, documentId=${statusData.documentId}');
    return statusData;
  }

  /// SSE 实时进度流 → /document/{id}/stream（独立 Dio 实例，避免占用连接池）
  Stream<TaskProgress> progressStream(int taskId, {CancelToken? cancelToken}) async* {
    final mainDio = ApiClient.instance.dio;
    final dio = Dio(BaseOptions(
      baseUrl: mainDio.options.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
      headers: {
        ...mainDio.options.headers,
      },
    ));
    try {
      final response = await dio.get<ResponseBody>(
        '/document/$taskId/stream',
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 30),
          sendTimeout: const Duration(seconds: 10),
        ),
        cancelToken: cancelToken,
      );

      final stream = response.data!.stream;
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final payload = line.substring(6).trim();
            if (payload == '[DONE]') return;

            try {
              final json = jsonDecode(payload) as Map<String, dynamic>;
              final progress = (json['progress'] as num?)?.toDouble() ?? 0;
              if (progress < 0) continue;
              yield TaskProgress(
                progress: progress,
                message: json['message'] as String? ?? '',
                detail: json['detail'] as Map<String, dynamic>?,
              );
              if (progress >= 1.0) return;
            } catch (_) {
              continue;
            }
          }
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
    }
  }

  /// 取消任务 → POST /document/{id}/cancel
  Future<bool> cancelTask(int taskId) async {
    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      '/document/$taskId/cancel',
    );
    final data = response.data!;
    return data['code'] == 200;
  }

  /// 查询任务列表 → GET /document/list
  Future<Map<String, dynamic>> listTasks({
    TaskStatus? status,
    TaskType? taskType,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (status != null) queryParams['status'] = status.name;
    if (taskType != null) queryParams['doc_type'] = taskType.name;

    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/document/list',
      queryParameters: queryParams,
    );
    final data = response.data!;
    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '查询失败');
    }
    return data['data'] as Map<String, dynamic>;
  }

  /// 获取文档预览 URL
  String getPreviewUrl(int documentId) {
    return '${AppConstants.apiBasePath}/preview/$documentId/html';
  }

  /// 获取文档元信息
  Future<Map<String, dynamic>> getDocumentMeta(int documentId) async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/preview/$documentId/meta',
    );
    final data = response.data!;
    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '查询失败');
    }
    return data['data'] as Map<String, dynamic>;
  }

  /// 导出文档
  Future<List<int>> exportDocument(int documentId, String format) async {
    _log('[TaskDataSource] exportDocument: documentId=$documentId, format=$format');
    final response = await ApiClient.instance.post<List<int>>(
      '/export/word',
      data: {'document_id': documentId, 'format': format},
      options: Options(responseType: ResponseType.bytes),
    );
    _log('[TaskDataSource] exportDocument success: ${response.data?.length ?? 0} bytes');
    return response.data!;
  }

  /// 注册推送设备
  Future<void> registerDevice(String token, String platform) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/device/register',
      data: {'device_token': token, 'platform': platform},
    );
  }
}
