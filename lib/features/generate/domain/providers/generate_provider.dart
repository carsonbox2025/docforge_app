import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/generate_data_source.dart';
import '../../data/task_data_source.dart';
import '../../data/models/generate_models.dart';
import '../../../../shared/models/dsl/document_block.dart'
    show DocumentBlock, GenerationStatus, ChapterStatus, OutlineItem, StreamingBlock;
import '../../../../shared/utils/file_export.dart';

final generateProvider =
    StateNotifierProvider<GenerateNotifier, GenerateState>((ref) {
  return GenerateNotifier(GenerateDataSource());
});

class GenerateNotifier extends StateNotifier<GenerateState> {
  final GenerateDataSource _dataSource;
  StreamSubscription? _progressSub;
  int? _currentTaskId;

  GenerateNotifier(this._dataSource) : super(const GenerateState());

  void selectDocType(DocType type) {
    state = state.copyWith(selectedType: type);
  }

  void selectLanguage(DocLanguage lang) {
    state = state.copyWith(selectedLanguage: lang);
  }

  void updateContent(String content) {
    state = state.copyWith(content: content);
  }

  void selectExportFormat(ExportFormat fmt) {
    state = state.copyWith(selectedFormat: fmt);
  }

  /// 提交生成任务（异步后台执行）
  Future<void> startGenerate({bool outlineOnly = false}) async {
    if (state.content.trim().isEmpty) return;

    state = state.copyWith(
      stage: GenerateStage.generating,
      status: GenerationStatus.planning,
      progress: 0,
      outline: [],
      currentBlocks: {},
      streamingBlocks: {},
      clearError: true,
    );

    final request = GenerateRequest(
      templateId: state.selectedType.defaultTemplateId,
      content: state.content,
      language: state.selectedLanguage,
      title: state.docTitle.isEmpty ? null : state.docTitle,
      outlineOnly: outlineOnly,
    );

    try {
      final taskId = await _dataSource.submitGenerateTask(request);
      _currentTaskId = taskId;

      state = state.copyWith(
        status: GenerationStatus.generating,
        progressMsg: '任务已提交',
      );

      _listenProgress(taskId);
    } catch (e) {
      debugPrint('[Generate] submit error: $e');
      state = state.copyWith(
        stage: GenerateStage.input,
        status: GenerationStatus.error,
        error: '任务提交失败: $e',
      );
    }
  }

  void _listenProgress(int taskId) {
    _progressSub?.cancel();

    final stream = _dataSource.taskProgressStream(taskId);
    _progressSub = stream.listen(
      (update) {
        if (!mounted) return;

        // 解析进度详情中的章节信息
        final detail = update.detail;
        if (detail != null) {
          _handleProgressDetail(detail);
        }

        // 更新进度
        final progressPct = update.progress.clamp(0.0, 1.0);
        final status = progressPct < 1.0
            ? GenerationStatus.generating
            : GenerationStatus.complete;

        state = state.copyWith(
          progress: progressPct,
          progressMsg: update.message,
          status: status,
        );
      },
      onDone: () {
        if (!mounted) return;
        _onStreamDone(taskId);
      },
      onError: (e) {
        if (!mounted) return;
        debugPrint('[Generate] progress stream error: $e');
        _pollUntilDone(taskId);
      },
    );
  }

  void _handleProgressDetail(Map<String, dynamic> detail) {
    // 处理章节规划信息
    final chapters = detail['chapters'] as List<dynamic>?;
    if (chapters != null) {
      final outline = <OutlineItem>[];
      for (final ch in chapters) {
        final map = ch as Map<String, dynamic>;
        outline.add(OutlineItem(
          chapterId: map['id'] as String? ?? '',
          title: map['title'] as String? ?? '未命名章节',
          taskId: map['id'] as String?,
          status: ChapterStatus.pending,
        ));
      }
      if (outline.isNotEmpty) {
        state = state.copyWith(outline: outline);
      }
    }

    // 处理当前章节
    final currentChapter = detail['current_chapter'] as String?;
    if (currentChapter != null) {
      final outline = List<OutlineItem>.from(state.outline);
      final item = outline.where((o) => o.chapterId == currentChapter).firstOrNull;
      if (item != null) {
        item.status = ChapterStatus.generating;
        state = state.copyWith(outline: outline);
      }
    }
  }

  Future<void> _onStreamDone(int taskId) async {
    try {
      final status = await _dataSource.getTaskStatus(taskId);
      if (status.status == TaskStatus.completed) {
        state = state.copyWith(
          stage: GenerateStage.review,
          status: GenerationStatus.complete,
          progress: 1.0,
          documentId: status.documentId,
          resultData: status.resultData,
        );
      } else if (status.status == TaskStatus.failed) {
        state = state.copyWith(
          stage: GenerateStage.input,
          status: GenerationStatus.error,
          error: status.errorMsg ?? '生成失败',
        );
      } else if (status.status == TaskStatus.cancelled) {
        state = state.copyWith(
          stage: GenerateStage.input,
          status: GenerationStatus.idle,
          error: '任务已取消',
        );
      } else {
        _pollUntilDone(taskId);
      }
    } catch (e) {
      debugPrint('[Generate] status check error: $e, fallback to polling');
      _pollUntilDone(taskId);
    }
  }

  Future<void> _pollUntilDone(int taskId, {int maxAttempts = 120}) async {
    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      try {
        final status = await _dataSource.getTaskStatus(taskId);
        state = state.copyWith(
          progress: status.progress.clamp(0.0, 1.0),
          progressMsg: status.progressMsg,
        );

        if (status.status.isTerminal) {
          if (status.status == TaskStatus.completed) {
            state = state.copyWith(
              stage: GenerateStage.review,
              status: GenerationStatus.complete,
              progress: 1.0,
              documentId: status.documentId,
              resultData: status.resultData,
            );
          } else if (status.status == TaskStatus.failed) {
            state = state.copyWith(
              stage: GenerateStage.input,
              status: GenerationStatus.error,
              error: status.errorMsg ?? '生成失败',
            );
          } else if (status.status == TaskStatus.cancelled) {
            state = state.copyWith(
              stage: GenerateStage.input,
              status: GenerationStatus.idle,
              error: '任务已取消',
            );
          }
          return;
        }
      } catch (_) {}
    }
    state = state.copyWith(
      stage: GenerateStage.input,
      status: GenerationStatus.error,
      error: '任务超时',
    );
  }

  void backToInput() {
    _progressSub?.cancel();
    _cancelTask();
    state = state.copyWith(stage: GenerateStage.input);
  }

  void backToGenerating() {
    state = state.copyWith(stage: GenerateStage.generating);
  }

  Future<void> _cancelTask() async {
    if (_currentTaskId != null) {
      try {
        await _dataSource.cancelTask(_currentTaskId!);
      } catch (_) {}
    }
  }

  /// 导出文档（通过 document_id）
  Future<void> exportDocument() async {
    final docId = state.documentId;
    if (docId == null) {
      debugPrint('[Generate] export: no document_id');
      return;
    }

    state = state.copyWith(isExporting: true);
    try {
      final bytes = await _dataSource.exportDocument(docId);
      final title = state.docTitle.isNotEmpty ? state.docTitle : 'document';
      await FileExporter.saveAndShare(
        bytes: Uint8List.fromList(bytes),
        fileName: '$title.${state.selectedFormat.extension}',
        subject: title,
      );
    } catch (e) {
      debugPrint('[Generate] Export error: $e');
    } finally {
      if (mounted) state = state.copyWith(isExporting: false);
    }
  }

  /// 获取预览 URL
  String? getPreviewUrl() {
    final docId = state.documentId;
    if (docId == null) return null;
    return _dataSource.getPreviewUrl(docId);
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }
}

/// 生成阶段
enum GenerateStage { input, generating, review }

/// 步骤状态
enum StepStatus { done, active, pending }

class GenerateState {
  final GenerateStage stage;
  final DocType selectedType;
  final DocLanguage selectedLanguage;
  final String content;
  final ExportFormat selectedFormat;

  // 生成状态
  final GenerationStatus status;
  final String docTitle;
  final double progress;
  final String? progressMsg;

  // Block DSL 状态
  final List<OutlineItem> outline;
  final Map<String, List<DocumentBlock>> currentBlocks;
  final Map<String, StreamingBlock> streamingBlocks;

  // 结果
  final int? documentId;
  final Map<String, dynamic>? resultData;

  final String? error;
  final bool isExporting;

  const GenerateState({
    this.stage = GenerateStage.input,
    this.selectedType = DocType.contract,
    this.selectedLanguage = DocLanguage.zhCN,
    this.content = '',
    this.selectedFormat = ExportFormat.docx,
    this.status = GenerationStatus.idle,
    this.docTitle = '',
    this.progress = 0,
    this.progressMsg,
    this.outline = const [],
    this.currentBlocks = const {},
    this.streamingBlocks = const {},
    this.documentId,
    this.resultData,
    this.error,
    this.isExporting = false,
  });

  GenerateState copyWith({
    GenerateStage? stage,
    DocType? selectedType,
    DocLanguage? selectedLanguage,
    String? content,
    ExportFormat? selectedFormat,
    GenerationStatus? status,
    String? docTitle,
    double? progress,
    String? progressMsg,
    List<OutlineItem>? outline,
    Map<String, List<DocumentBlock>>? currentBlocks,
    Map<String, StreamingBlock>? streamingBlocks,
    int? documentId,
    Map<String, dynamic>? resultData,
    String? error,
    bool? isExporting,
    bool clearError = false,
  }) =>
      GenerateState(
        stage: stage ?? this.stage,
        selectedType: selectedType ?? this.selectedType,
        selectedLanguage: selectedLanguage ?? this.selectedLanguage,
        content: content ?? this.content,
        selectedFormat: selectedFormat ?? this.selectedFormat,
        status: status ?? this.status,
        docTitle: docTitle ?? this.docTitle,
        progress: progress ?? this.progress,
        progressMsg: progressMsg ?? this.progressMsg,
        outline: outline ?? this.outline,
        currentBlocks: currentBlocks ?? this.currentBlocks,
        streamingBlocks: streamingBlocks ?? this.streamingBlocks,
        documentId: documentId ?? this.documentId,
        resultData: resultData ?? this.resultData,
        error: clearError ? null : (error ?? this.error),
        isExporting: isExporting ?? this.isExporting,
      );
}
