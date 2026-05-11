import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/task_data_source.dart';
import '../../../../shared/utils/file_export.dart';

final taskDataSourceProvider = Provider<TaskDataSource>((ref) => TaskDataSource());

final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  return TaskNotifier(ref.watch(taskDataSourceProvider));
});

class TaskNotifier extends StateNotifier<TaskState> {
  final TaskDataSource _ds;
  StreamSubscription? _progressSub;
  int? _currentTaskId;

  TaskNotifier(this._ds) : super(const TaskState());

  /// 提交生成任务
  Future<void> submitGenerate({
    required String templateId,
    required String content,
    String? title,
    String language = 'zh-CN',
  }) async {
    await _submit(
      taskType: TaskType.generate,
      userInput: {'content': content, 'language': language},
      templateId: templateId,
      title: title,
    );
  }

  /// 提交润色任务
  Future<void> submitPolish({
    required String text,
    String? templateId,
    String? title,
    String docType = 'generic',
    String polishLevel = 'normal',
  }) async {
    await _submit(
      taskType: TaskType.polish,
      userInput: {'text': text, 'doc_type': docType},
      templateId: templateId,
      title: title,
      polishLevel: polishLevel,
    );
  }

  /// 提交翻译任务
  Future<void> submitTranslate({
    required String text,
    String? title,
    String sourceLang = 'zh-CN',
    String targetLang = 'en-US',
  }) async {
    await _submit(
      taskType: TaskType.translate,
      userInput: {'text': text},
      title: title,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );
  }

  Future<void> _submit({
    required TaskType taskType,
    required Map<String, dynamic> userInput,
    String? templateId,
    String? title,
    String? polishLevel,
    String? sourceLang,
    String? targetLang,
  }) async {
    state = const TaskState(stage: TaskStage.submitting);

    try {
      final taskId = await _ds.submitTask(
        taskType: taskType,
        userInput: userInput,
        templateId: templateId,
        title: title,
        polishLevel: polishLevel,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
      _currentTaskId = taskId;

      state = TaskState(
        stage: TaskStage.running,
        taskId: taskId,
        taskType: taskType,
        progress: 0,
        progressMsg: '任务已提交',
      );

      _listenProgress(taskId);
    } catch (e) {
      debugPrint('[Task] submit error: $e');
      state = TaskState(stage: TaskStage.failed, error: e.toString());
    }
  }

  void _listenProgress(int taskId) {
    _progressSub?.cancel();

    final stream = _ds.progressStream(taskId);
    _progressSub = stream.listen(
      (update) {
        if (!mounted) return;
        state = state.copyWith(
          progress: update.progress,
          progressMsg: update.message,
          progressDetail: update.detail,
        );
      },
      onDone: () {
        if (!mounted) return;
        _onStreamDone(taskId);
      },
      onError: (e) {
        if (!mounted) return;
        debugPrint('[Task] progress stream error: $e');
        _pollUntilDone(taskId);
      },
    );
  }

  Future<void> _onStreamDone(int taskId) async {
    try {
      final status = await _ds.getTaskStatus(taskId);
      if (status.status == TaskStatus.completed) {
        state = state.copyWith(
          stage: TaskStage.completed,
          progress: 1.0,
          progressMsg: '完成',
          documentId: status.documentId,
          resultData: status.resultData,
        );
      } else if (status.status == TaskStatus.failed) {
        state = state.copyWith(
          stage: TaskStage.failed,
          error: status.errorMsg ?? '任务失败',
        );
      } else if (status.status == TaskStatus.cancelled) {
        state = state.copyWith(
          stage: TaskStage.cancelled,
        );
      } else {
        // 还在跑，轮询兜底
        _pollUntilDone(taskId);
      }
    } catch (e) {
      debugPrint('[Task] status check error: $e');
      state = state.copyWith(stage: TaskStage.completed, progress: 1.0);
    }
  }

  Future<void> _pollUntilDone(int taskId, {int maxAttempts = 120}) async {
    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      try {
        final status = await _ds.getTaskStatus(taskId);
        state = state.copyWith(
          progress: status.progress,
          progressMsg: status.progressMsg,
        );

        if (status.status.isTerminal) {
          if (status.status == TaskStatus.completed) {
            state = state.copyWith(
              stage: TaskStage.completed,
              progress: 1.0,
              documentId: status.documentId,
              resultData: status.resultData,
            );
          } else if (status.status == TaskStatus.failed) {
            state = state.copyWith(
              stage: TaskStage.failed,
              error: status.errorMsg ?? '任务失败',
            );
          } else {
            state = state.copyWith(stage: TaskStage.cancelled);
          }
          return;
        }
      } catch (_) {}
    }
    state = state.copyWith(stage: TaskStage.failed, error: '任务超时');
  }

  /// 取消任务
  Future<void> cancelTask() async {
    if (_currentTaskId == null) return;
    try {
      await _ds.cancelTask(_currentTaskId!);
      state = state.copyWith(stage: TaskStage.cancelled);
    } catch (e) {
      debugPrint('[Task] cancel error: $e');
    }
  }

  /// 导出文档
  Future<void> exportDocument(int documentId, String title, String format) async {
    state = state.copyWith(isExporting: true);
    try {
      final bytes = await _ds.exportDocument(documentId, format);
      await FileExporter.saveAndShare(
        bytes: Uint8List.fromList(bytes),
        fileName: '$title.docx',
        subject: title,
      );
    } catch (e) {
      debugPrint('[Task] export error: $e');
    } finally {
      if (mounted) state = state.copyWith(isExporting: false);
    }
  }

  /// 获取 HTML 预览 URL
  String? getPreviewUrl() {
    final docId = state.documentId;
    if (docId == null) return null;
    return _ds.getPreviewUrl(docId);
  }

  /// 重置状态
  void reset() {
    _progressSub?.cancel();
    _currentTaskId = null;
    state = const TaskState();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }
}

enum TaskStage { idle, submitting, running, completed, failed, cancelled }

class TaskState {
  final TaskStage stage;
  final int? taskId;
  final TaskType? taskType;
  final double progress;
  final String? progressMsg;
  final Map<String, dynamic>? progressDetail;
  final int? documentId;
  final Map<String, dynamic>? resultData;
  final String? error;
  final bool isExporting;

  const TaskState({
    this.stage = TaskStage.idle,
    this.taskId,
    this.taskType,
    this.progress = 0,
    this.progressMsg,
    this.progressDetail,
    this.documentId,
    this.resultData,
    this.error,
    this.isExporting = false,
  });

  TaskState copyWith({
    TaskStage? stage,
    int? taskId,
    TaskType? taskType,
    double? progress,
    String? progressMsg,
    Map<String, dynamic>? progressDetail,
    int? documentId,
    Map<String, dynamic>? resultData,
    String? error,
    bool? isExporting,
  }) =>
      TaskState(
        stage: stage ?? this.stage,
        taskId: taskId ?? this.taskId,
        taskType: taskType ?? this.taskType,
        progress: progress ?? this.progress,
        progressMsg: progressMsg ?? this.progressMsg,
        progressDetail: progressDetail ?? this.progressDetail,
        documentId: documentId ?? this.documentId,
        resultData: resultData ?? this.resultData,
        error: error ?? this.error,
        isExporting: isExporting ?? this.isExporting,
      );
}
