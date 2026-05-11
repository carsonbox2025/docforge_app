import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';

/// 任务类型
enum TaskType { generate, polish, translate }

/// 任务状态
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

/// 任务状态响应
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
    this.createdAt,
    this.completedAt,
  });

  factory TaskStatusData.fromJson(Map<String, dynamic> json) => TaskStatusData(
        id: json['id'] as int,
        taskType: TaskType.values.firstWhere(
          (e) => e.name == json['task_type'],
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
        documentId: json['document_id'] as int?,
        createdAt: json['created_at'] as String?,
        completedAt: json['completed_at'] as String?,
      );
}

class TaskDataSource {
  /// 提交异步任务
  Future<int> submitTask({
    required TaskType taskType,
    required Map<String, dynamic> userInput,
    String? templateId,
    String? title,
    String? polishLevel,
    String? sourceLang,
    String? targetLang,
  }) async {
    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      '/task/submit',
      data: {
        'task_type': taskType.name,
        'user_input': userInput,
        if (templateId != null) 'template_id': templateId,
        if (title != null) 'title': title,
        if (polishLevel != null) 'polish_level': polishLevel,
        if (sourceLang != null) 'source_lang': sourceLang,
        if (targetLang != null) 'target_lang': targetLang,
      },
    );
    final data = response.data!;
    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '任务提交失败');
    }
    return data['data']['task_id'] as int;
  }

  /// 查询任务状态
  Future<TaskStatusData> getTaskStatus(int taskId) async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/task/$taskId',
    );
    final data = response.data!;
    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '查询失败');
    }
    return TaskStatusData.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// SSE 实时进度流
  Stream<TaskProgress> progressStream(int taskId) async* {
    final dio = ApiClient.instance.dio;
    final response = await dio.get<ResponseBody>(
      '/task/$taskId/stream',
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero,  // SSE 不设超时，由心跳保活
      ),
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
            if (progress < 0) {
              // heartbeat
              continue;
            }
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
  }

  /// 取消任务
  Future<bool> cancelTask(int taskId) async {
    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      '/task/$taskId/cancel',
    );
    final data = response.data!;
    return data['code'] == 200;
  }

  /// 查询任务列表
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
    if (taskType != null) queryParams['task_type'] = taskType.name;

    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/task/list',
      queryParameters: queryParams,
    );
    final data = response.data!;
    if (data['code'] != 200) {
      throw Exception(data['message'] ?? '查询失败');
    }
    return data['data'] as Map<String, dynamic>;
  }

  /// 获取文档 HTML 预览 URL
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

  /// 导出文档（通过 document_id）
  Future<List<int>> exportDocument(int documentId, String format) async {
    final response = await ApiClient.instance.post<List<int>>(
      '/export/word',
      data: {'document_id': documentId, 'format': format},
      options: Options(responseType: ResponseType.bytes),
    );
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
