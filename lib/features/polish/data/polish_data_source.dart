import 'dart:async';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/sse/sse_client.dart';
import '../../generate/data/task_data_source.dart';
import 'models/polish_models.dart';

class PolishRemoteDataSource {
  final TaskDataSource _taskDs = TaskDataSource();

  /// 提交润色任务（通过统一任务服务）
  Future<int> submitPolishTask(PolishRequest request) async {
    return _taskDs.submitTask(
      taskType: TaskType.polish,
      userInput: {
        'text': request.text ?? '',
        'polish_level': request.level.value,
        'doc_type': request.docType,
        'mode': request.mode,
      },
      title: request.fileName ?? '润色文档',
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

  /// 导出润色结果
  Future<Response> exportResult({
    required String taskId,
    required ExportFormat format,
  }) async {
    return ApiClient.instance.post(
      '${AppConstants.apiBaseUrl}/polish/export',
      data: {'task_id': taskId, 'format': format.name},
      options: Options(responseType: ResponseType.bytes),
    );
  }
}
