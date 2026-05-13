import 'dart:async';
import 'models/generate_models.dart';
import 'task_data_source.dart';

class GenerateDataSource {
  final TaskDataSource _taskDs = TaskDataSource();

  /// 发起文档生成（异步任务模式）
  Future<int> submitGenerateTask(GenerateRequest request) async {
    return _taskDs.submitTask(
      taskType: TaskType.generate,
      userInput: {
        'content': request.content,
        'language': request.language.code,
        'mode': request.mode,
        if (request.sceneId != null) 'scene_id': request.sceneId,
        if (request.layer != null) 'layer': request.layer,
        if (request.fieldsData != null) 'fields_data': request.fieldsData,
      },
      templateId: request.templateId,
      title: request.title,
      docType: request.docType,
    );
  }

  /// 任务进度流（SSE）
  Stream<TaskProgress> taskProgressStream(int taskId) {
    return _taskDs.progressStream(taskId);
  }

  /// 查询任务状态
  Future<TaskStatusData> getTaskStatus(int taskId) {
    return _taskDs.getTaskStatus(taskId);
  }

  /// 取消任务
  Future<bool> cancelTask(int taskId) {
    return _taskDs.cancelTask(taskId);
  }

  /// 导出文档（通过 document_id）
  Future<List<int>> exportDocument(int documentId, [String format = 'docx']) async {
    return _taskDs.exportDocument(documentId, format);
  }

  /// 获取预览 URL
  String getPreviewUrl(int documentId) {
    return _taskDs.getPreviewUrl(documentId);
  }
}
