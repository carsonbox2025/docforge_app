import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/generate_data_source.dart';
import '../../data/task_data_source.dart';
import '../../data/models/generate_models.dart';
import '../../../../shared/models/dsl/dsl_node.dart' show DslNode, DslOutline;
import '../../../../shared/utils/file_export.dart';
import '../../../scene/data/models/scene_models.dart';

enum GenerationStatus { idle, planning, generating, complete, error }

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

  void selectMode(String mode) {
    state = state.copyWith(mode: mode);
  }

  /// 选择场景
  void selectScene(SceneConfig scene) {
    state = state.copyWith(
      selectedScene: scene,
      selectedType: _docTypeFromScene(scene),
    );
  }

  /// 更新表单字段值
  void updateFormFields(Map<String, String> fields) {
    state = state.copyWith(formFields: fields);
  }

  /// 更新封面字段值
  void updateFieldsData(Map<String, String> fields) {
    state = state.copyWith(fieldsData: fields);
  }

  static DocType _docTypeFromScene(SceneConfig scene) {
    return DocType.values.firstWhere(
      (t) => t.code == scene.docType,
      orElse: () => DocType.contract,
    );
  }

  /// 提交生成任务（异步后台执行）
  Future<void> startGenerate({bool outlineOnly = false}) async {
    final scene = state.selectedScene;
    final content = _assembleContent(scene);
    if (content.trim().isEmpty) {
      state = state.copyWith(error: '请填写内容后再提交');
      return;
    }

    state = state.copyWith(
      stage: GenerateStage.generating,
      status: GenerationStatus.planning,
      progress: 0,
      outline: [],
      dslNodes: {},
      streamingBlocks: {},
      clearError: true,
    );

    final request = GenerateRequest(
      templateId: scene?.templateId ?? state.selectedType.defaultTemplateId,
      content: content,
      language: state.selectedLanguage,
      title: state.docTitle.isEmpty ? null : state.docTitle,
      outlineOnly: outlineOnly,
      mode: state.mode,
      docType: scene?.docType ?? state.selectedType.code,
      sceneId: scene?.sceneId,
      layer: scene?.layer,
      fieldsData: state.fieldsData.isNotEmpty ? state.fieldsData : null,
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

        // 解析 DSL 更新
        final detail = update.detail;
        if (detail != null) {
          _handleDslUpdate(detail);
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

  void _handleDslUpdate(Map<String, dynamic> detail) {
    final dslUpdate = detail['dsl_update'] as Map<String, dynamic>?;
    if (dslUpdate == null) {
      // 兼容旧格式
      _handleLegacyProgressDetail(detail);
      return;
    }

    // 更新 outline
    final outlineRaw = dslUpdate['outline'] as List<dynamic>?;
    if (outlineRaw != null) {
      final outline = outlineRaw
          .map((o) => DslOutline.fromJson(o as Map<String, dynamic>))
          .toList();
      if (outline.isNotEmpty) {
        state = state.copyWith(outline: outline);
      }
    }

    // 更新 active section
    final activeSection = dslUpdate['active_section'] as String?;

    // 更新 DSL nodes
    final nodeUpdates = dslUpdate['node_updates'] as List<dynamic>?;
    if (nodeUpdates != null && nodeUpdates.isNotEmpty) {
      final nodes = Map<String, List<DslNode>>.from(state.dslNodes);

      for (final update in nodeUpdates) {
        final u = update as Map<String, dynamic>;
        final op = u['op'] as String? ?? 'append';
        final section = u['section'] as String? ?? 'main';

        if (op == 'replace_all') {
          final rawNodes = u['nodes'] as List<dynamic>? ?? [];
          nodes[section] = rawNodes
              .map((n) => DslNode.fromJson(n as Map<String, dynamic>))
              .toList();
        } else if (op == 'append') {
          final rawNode = u['node'] as Map<String, dynamic>?;
          if (rawNode != null) {
            final node = DslNode.fromJson(rawNode);
            nodes.putIfAbsent(section, () => []);
            // 避免重复追加（同一 block_id）
            final existingIds = nodes[section]!
                .where((n) => n.id != null)
                .map((n) => n.id)
                .toSet();
            if (node.id == null || !existingIds.contains(node.id)) {
              nodes[section] = [...nodes[section]!, node];
            }
          }
        }
      }

      state = state.copyWith(dslNodes: nodes);
    }
  }

  void _handleLegacyProgressDetail(Map<String, dynamic> detail) {
    // 兼容旧格式 outline
    final chapters = detail['chapters'] as List<dynamic>?;
    if (chapters != null) {
      final outline = <DslOutline>[];
      for (final ch in chapters) {
        final map = ch as Map<String, dynamic>;
        outline.add(DslOutline(
          id: map['id'] as String? ?? '',
          title: map['title'] as String? ?? '未命名章节',
          status: 'pending',
        ));
      }
      if (outline.isNotEmpty) {
        state = state.copyWith(outline: outline);
      }
    }

    final currentChapter = detail['current_chapter'] as String?;
    if (currentChapter != null) {
      final outline = List<DslOutline>.from(state.outline);
      final idx = outline.indexWhere((o) => o.id == currentChapter);
      if (idx >= 0) {
        outline[idx] = DslOutline(
          id: outline[idx].id,
          title: outline[idx].title,
          status: 'generating',
        );
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
    state = state.copyWith(stage: GenerateStage.input, clearError: true);
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void backToGenerating() {
    state = state.copyWith(stage: GenerateStage.generating);
  }

  /// 取消当前生成任务
  void cancelGenerate() {
    _progressSub?.cancel();
    if (_currentTaskId != null) {
      _dataSource.cancelTask(_currentTaskId!);
    }
    state = state.copyWith(
      stage: GenerateStage.input,
      status: GenerationStatus.idle,
      clearError: true,
    );
  }

  /// 组装提交内容：有场景时合并表单字段，否则用原始 content
  String _assembleContent(SceneConfig? scene) {
    if (scene == null) return state.content;

    final parts = <String>[];
    for (final entry in state.formFields.entries) {
      if (entry.value.isNotEmpty) {
        parts.add('${entry.key}：${entry.value}');
      }
    }
    // content 字段单独处理（已在 formFields 中）
    if (parts.isEmpty) return state.content;
    return parts.join('\n');
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
      if (mounted) state = state.copyWith(
        isExporting: false,
        error: '导出失败，请检查网络后重试',
      );
      return;
    }
    if (mounted) state = state.copyWith(isExporting: false);
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

  // 场景模式
  final SceneConfig? selectedScene;
  final Map<String, String> formFields;
  final Map<String, String> fieldsData;

  // 生成状态
  final GenerationStatus status;
  final String docTitle;
  final double progress;
  final String? progressMsg;

  // 模式
  final String mode; // quick / professional / auto

  // DSL 状态（统一）
  final List<DslOutline> outline;
  final Map<String, List<DslNode>> dslNodes;

  // 兼容旧格式
  final Map<String, dynamic> streamingBlocks;

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
    this.selectedScene,
    this.formFields = const {},
    this.fieldsData = const {},
    this.status = GenerationStatus.idle,
    this.docTitle = '',
    this.progress = 0,
    this.progressMsg,
    this.mode = 'quick',
    this.outline = const [],
    this.dslNodes = const {},
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
    SceneConfig? selectedScene,
    bool clearSelectedScene = false,
    Map<String, String>? formFields,
    Map<String, String>? fieldsData,
    GenerationStatus? status,
    String? docTitle,
    double? progress,
    Object? progressMsg = _sentinel,
    String? mode,
    List<DslOutline>? outline,
    Map<String, List<DslNode>>? dslNodes,
    Map<String, dynamic>? streamingBlocks,
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
        selectedScene: clearSelectedScene ? null : (selectedScene ?? this.selectedScene),
        formFields: formFields ?? this.formFields,
        fieldsData: fieldsData ?? this.fieldsData,
        status: status ?? this.status,
        docTitle: docTitle ?? this.docTitle,
        progress: progress ?? this.progress,
        progressMsg: progressMsg == _sentinel ? this.progressMsg : progressMsg as String?,
        mode: mode ?? this.mode,
        outline: outline ?? this.outline,
        dslNodes: dslNodes ?? this.dslNodes,
        streamingBlocks: streamingBlocks ?? this.streamingBlocks,
        documentId: documentId ?? this.documentId,
        resultData: resultData ?? this.resultData,
        error: clearError ? null : (error ?? this.error),
        isExporting: isExporting ?? this.isExporting,
      );

  static const _sentinel = Object();
}
