import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/generate_data_source.dart';
import '../../data/task_data_source.dart';
import '../../data/models/generate_models.dart';
import '../../../../shared/models/dsl/dsl_node.dart' show DslNode, DslOutline;
import '../../../../shared/utils/file_export.dart';
import '../../../scene/data/models/scene_models.dart';

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

enum GenerationStatus { idle, planning, generating, complete, error }

/// Layer 2 规划阶段定义
class PlanningPhaseDef {
  final String key;
  final String label;
  final String description;
  const PlanningPhaseDef({
    required this.key,
    required this.label,
    required this.description,
  });
}

const kPlanningPhases = [
  PlanningPhaseDef(key: 'analyzing', label: '分析中', description: '正在分析您的需求...'),
  PlanningPhaseDef(key: 'structuring', label: '结构规划', description: '正在规划文档结构...'),
  PlanningPhaseDef(key: 'detailing', label: '细节填充', description: '正在完善章节细节...'),
  PlanningPhaseDef(key: 'optimizing', label: '优化完善', description: '正在优化文档方案...'),
];

final generateProvider =
    StateNotifierProvider.autoDispose<GenerateNotifier, GenerateState>((ref) {
  return GenerateNotifier(GenerateDataSource());
});

class GenerateNotifier extends StateNotifier<GenerateState> {
  final GenerateDataSource _dataSource;
  StreamSubscription? _progressSub;
  int? _currentTaskId;
  bool _disposed = false;

  GenerateNotifier(this._dataSource) : super(const GenerateState());

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

  /// 选择场景 — 根据 layer 自动决定 mode，清空上次生成状态
  void selectScene(SceneConfig scene) {
    final autoMode = scene.isLayer2 ? 'professional' : 'quick';
    _log('[Generate] selectScene: sceneId=${scene.sceneId}, name=${scene.name}, '
        'docType=${scene.docType}, layer=${scene.layer}, autoMode=$autoMode');
    _progressSub?.cancel();
    _currentTaskId = null;
    state = state.copyWith(
      selectedScene: scene,
      mode: autoMode,
      stage: GenerateStage.input,
      status: GenerationStatus.idle,
      docTitle: '',
      content: '',
      formFields: {},
      fieldsData: {},
      outline: [],
      dslNodes: {},
      streamingBlocks: {},
      planningThoughts: [],
      planningPhase: 'analyzing',
      documentId: null,
      resultData: null,
      progress: 0,
      progressMsg: null,
      clearError: true,
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

  /// 提交生成任务（异步后台执行）
  Future<void> startGenerate() async {
    final scene = state.selectedScene;
    if (scene == null) {
      _log('[Generate] startGenerate FAILED: no scene selected');
      state = state.copyWith(error: '请先选择文档场景');
      return;
    }

    final content = _assembleContent(scene);
    if (content.trim().isEmpty) {
      state = state.copyWith(error: '请填写内容后再提交');
      return;
    }

    _log('[Generate] startGenerate: sceneId=${scene.sceneId}, docType=${scene.docType}, '
        'layer=${scene.layer}, templateId=${scene.templateId}, mode=${state.mode}');

    final isLayer2 = scene.isLayer2;
    state = state.copyWith(
      stage: GenerateStage.generating,
      status: isLayer2 ? GenerationStatus.planning : GenerationStatus.generating,
      progress: 0,
      docTitle: '',
      outline: [],
      dslNodes: {},
      streamingBlocks: {},
      planningThoughts: [],
      planningPhase: 'analyzing',
      documentId: null,
      resultData: null,
      clearError: true,
    );

    final request = GenerateRequest(
      templateId: scene.templateId,
      content: content,
      language: state.selectedLanguage,
      title: state.docTitle.isEmpty ? null : state.docTitle,
      mode: state.mode,
      docType: scene.docType,
      sceneId: scene.sceneId,
      layer: scene.layer,
      fieldsData: state.fieldsData.isNotEmpty ? state.fieldsData : null,
      formFields: state.formFields.isNotEmpty ? state.formFields : null,
    );

    _log('[Generate] request body: ${request.toJson()}');

    try {
      final taskId = await _dataSource.submitGenerateTask(request);
      _currentTaskId = taskId;
      _log('[Generate] task submitted successfully, taskId=$taskId');

      state = state.copyWith(
        status: isLayer2 ? state.status : GenerationStatus.generating,
        progressMsg: '任务已提交',
      );

      _listenProgress(taskId);
    } catch (e) {
      _log('[Generate] submit error: $e');
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
        if (_disposed || !mounted) return;

        final detailKeys = update.detail?.keys.toList() ?? <String>[];
        _log('[Generate] progress update: taskId=$taskId, progress=${update.progress}, '
            'message=${update.message}, detailKeys=$detailKeys');

        // 解析 DSL 更新（try-catch 防止类型转换异常阻断整个回调）
        final detail = update.detail;
        if (detail != null) {
          try {
            _handleDslUpdate(detail);
          } catch (e, st) {
            _log('[Generate] _handleDslUpdate ERROR: $e\n$st');
          }
        }

        // 状态流转：继承当前状态（planning 不被覆盖），仅在终态时强制覆盖
        final progressPct = update.progress.clamp(0.0, 1.0);
        GenerationStatus nextStatus = state.status;
        if (progressPct >= 1.0) {
          nextStatus = GenerationStatus.complete;
        } else if (state.status == GenerationStatus.idle) {
          nextStatus = GenerationStatus.generating;
        }

        state = state.copyWith(
          progress: progressPct,
          progressMsg: update.message,
          status: nextStatus,
        );

        _log('[Generate] state after update: status=${state.status}, '
            'thoughts=${state.planningThoughts.length}, '
            'outline=${state.outline.length}, '
            'dslNodes sections=${state.dslNodes.keys.toList()}, '
            'hasNodes=${state.dslNodes.values.any((l) => l.isNotEmpty)}');
      },
      onDone: () {
        if (_disposed || !mounted) return;
        _log('[Generate] progress stream done, checking final status for taskId=$taskId');
        _onStreamDone(taskId);
      },
      onError: (e) {
        if (_disposed || !mounted) return;
        _log('[Generate] progress stream error for taskId=$taskId: $e');
        _pollUntilDone(taskId);
      },
    );
  }

  void _handleDslUpdate(Map<String, dynamic> detail) {
    // 1. 处理 planning_event（Layer 2 规划阶段）
    final planningEvent = detail['planning_event'] as Map<String, dynamic>?;
    if (planningEvent != null) {
      _log('[Generate] → planning_event: phase=${planningEvent['phase']}, '
          'contentLen=${(planningEvent['content'] as String?)?.length ?? 0}');
      _handlePlanningEvent(planningEvent);
      return;
    }

    final dslUpdate = detail['dsl_update'] as Map<String, dynamic>?;
    if (dslUpdate == null) {
      _log('[Generate] → legacy detail: keys=${detail.keys.toList()}');
      // 兼容旧格式
      _handleLegacyProgressDetail(detail);
      return;
    }

    _log('[Generate] → dsl_update: outline=${(dslUpdate['outline'] as List?)?.length ?? 0}, '
        'nodeUpdates=${(dslUpdate['node_updates'] as List?)?.length ?? 0}');

    // 2. 收到第一个 dsl_update → 规划完成，进入正式生成
    if (state.status == GenerationStatus.planning) {
      state = state.copyWith(
        status: GenerationStatus.generating,
        planningPhase: 'complete',
      );
    }

    // 更新 outline
    final outlineRaw = dslUpdate['outline'] as List<dynamic>?;
    if (outlineRaw != null) {
      final newOutline = outlineRaw
          .map((o) => DslOutline.fromJson(o as Map<String, dynamic>))
          .toList();
      
      if (newOutline.isNotEmpty) {
        bool outlineChanged = newOutline.length != state.outline.length;
        if (!outlineChanged) {
          for (int i = 0; i < newOutline.length; i++) {
            if (newOutline[i].id != state.outline[i].id ||
                newOutline[i].title != state.outline[i].title ||
                newOutline[i].status != state.outline[i].status) {
              outlineChanged = true;
              break;
            }
          }
        }
        
        if (outlineChanged) {
          _log('[Generate] outline updated: ${newOutline.length} sections');
          state = state.copyWith(outline: newOutline);
        }
      }
    }

    // 更新 active section
    final activeSection = dslUpdate['active_section'] as String?;
    if (activeSection != null) {
      _log('[Generate] active section: $activeSection');
    }

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
          _log('[Generate] DSL replace_all: section=$section, count=${nodes[section]!.length}');
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
        } else if (op == 'update_text') {
          // 增量文本更新：O(1) 内存操作
          final nodeIndex = u['node_index'] as int?;
          final delta = u['delta'] as String? ?? '';
          if (nodeIndex != null && delta.isNotEmpty) {
            final sectionNodes = nodes[section];
            if (sectionNodes != null && nodeIndex < sectionNodes.length) {
              final oldNode = sectionNodes[nodeIndex];
              final updatedNode = oldNode.copyWith(
                text: (oldNode.text ?? '') + delta,
              );
              nodes[section] = [
                ...sectionNodes.sublist(0, nodeIndex),
                updatedNode,
                ...sectionNodes.sublist(nodeIndex + 1),
              ];
            }
          }
        } else if (op == 'replace_node') {
          // 替换单个节点（list/table 增量）
          final nodeIndex = u['node_index'] as int?;
          final rawNode = u['node'] as Map<String, dynamic>?;
          if (nodeIndex != null && rawNode != null) {
            final sectionNodes = nodes[section];
            if (sectionNodes != null && nodeIndex < sectionNodes.length) {
              final updatedNode = DslNode.fromJson(rawNode);
              nodes[section] = [
                ...sectionNodes.sublist(0, nodeIndex),
                updatedNode,
                ...sectionNodes.sublist(nodeIndex + 1),
              ];
            }
          }
        }
      }

      state = state.copyWith(dslNodes: nodes);
    }
  }

  void _handlePlanningEvent(Map<String, dynamic> event) {
    final content = event['content'] as String? ?? '';
    final phase = event['phase'] as String? ?? 'analyzing';

    final thoughts = List<String>.from(state.planningThoughts);
    if (content.contains('\n') || thoughts.isEmpty) {
      thoughts.add(content.replaceFirst(RegExp(r'^\n+'), ''));
    } else {
      thoughts[thoughts.length - 1] = thoughts.last + content;
    }

    _log('[Generate] planning thought: phase=$phase, len=${thoughts.join('').length}');

    state = state.copyWith(
      planningThoughts: thoughts,
      planningPhase: phase,
      status: GenerationStatus.planning,
    );
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
        _log('[Generate] legacy outline updated: ${outline.length} chapters');
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
      _log('[Generate] final status for taskId=$taskId: '
          'status=${status.status}, documentId=${status.documentId}');

      if (status.status == TaskStatus.completed) {
        _log('[Generate] completed: resultData=${status.resultData}');
        state = state.copyWith(
          stage: GenerateStage.review,
          status: GenerationStatus.complete,
          progress: 1.0,
          documentId: status.documentId,
          resultData: status.resultData,
          docTitle: status.title?.isNotEmpty == true ? status.title : null,
        );
      } else if (status.status == TaskStatus.failed) {
        _log('[Generate] failed: errorMsg=${status.errorMsg}');
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
        _log('[Generate] unexpected status ${status.status}, starting poll');
        _pollUntilDone(taskId);
      }
    } catch (e) {
      _log('[Generate] status check error: $e, starting poll');
      _pollUntilDone(taskId);
    }
  }

  Future<void> _pollUntilDone(int taskId, {int maxAttempts = 360}) async {
    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (_disposed || !mounted) return;

      try {
        final status = await _dataSource.getTaskStatus(taskId);
        if (_disposed || !mounted) return;
        state = state.copyWith(
          progress: status.progress.clamp(0.0, 1.0),
          progressMsg: status.progressMsg,
        );

        if (status.status.isTerminal) {
          _log('[Generate] poll terminal: taskId=$taskId, status=${status.status}');
          if (status.status == TaskStatus.completed) {
            state = state.copyWith(
              stage: GenerateStage.review,
              status: GenerationStatus.complete,
              progress: 1.0,
              documentId: status.documentId,
              resultData: status.resultData,
              docTitle: status.title?.isNotEmpty == true ? status.title : null,
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
      } catch (e) {
        _log('[Generate] poll error: $e');
      }
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
  Future<void> cancelGenerate() async {
    _progressSub?.cancel();
    _progressSub = null;
    final taskId = _currentTaskId;
    _currentTaskId = null;

    state = state.copyWith(
      stage: GenerateStage.input,
      status: GenerationStatus.idle,
      clearError: true,
    );

    if (taskId != null) {
      _log('[Generate] cancelling taskId=$taskId');
      try {
        await _dataSource.cancelTask(taskId);
      } catch (e) {
        _log('[Generate] cancelTask failed for $taskId: $e');
      }
    }
  }

  /// 组装提交内容：基于场景表单字段组装
  String _assembleContent(SceneConfig scene) {
    final parts = <String>[];
    for (final entry in state.formFields.entries) {
      if (entry.value.isNotEmpty) {
        parts.add('${entry.key}：${entry.value}');
      }
    }
    if (parts.isEmpty) return state.content;
    return parts.join('\n');
  }

  /// 导出文档（通过 document_id）
  Future<void> exportDocument() async {
    final docId = state.documentId;
    if (docId == null) {
      _log('[Generate] export: no document_id');
      return;
    }

    state = state.copyWith(isExporting: true);
    try {
      // 从 API 获取最新标题（避免内存状态时序问题）
      String title = state.docTitle;
      try {
        final status = await _dataSource.getTaskStatus(docId);
        if (status.title != null && status.title!.isNotEmpty) {
          title = status.title!;
          if (mounted) state = state.copyWith(docTitle: title);
        }
      } catch (_) {}

      if (title.isEmpty) {
        title = state.selectedScene?.name ?? 'document';
      }

      final bytes = await _dataSource.exportDocument(docId);
      await FileExporter.saveAndShare(
        bytes: Uint8List.fromList(bytes),
        fileName: '$title${state.selectedFormat.extension}',
        subject: title,
      );
    } catch (e) {
      _log('[Generate] Export error: $e');
      if (mounted) {
        state = state.copyWith(
          isExporting: false,
          error: '导出失败，请检查网络后重试',
        );
      }
      return;
    }
    if (mounted) state = state.copyWith(isExporting: false, error: null);
  }

  /// 获取预览 URL
  String? getPreviewUrl() {
    final docId = state.documentId;
    if (docId == null) return null;
    return _dataSource.getPreviewUrl(docId);
  }

  @override
  void dispose() {
    _disposed = true;
    _progressSub?.cancel();
    _progressSub = null;
    super.dispose();
  }
}

/// 生成阶段
enum GenerateStage { input, generating, review }

/// 步骤状态
enum StepStatus { done, active, pending }

class GenerateState {
  final GenerateStage stage;
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
  final String mode; // quick / professional

  // DSL 状态
  final List<DslOutline> outline;
  final Map<String, List<DslNode>> dslNodes;

  // 兼容旧格式
  final Map<String, dynamic> streamingBlocks;

  // Layer 2 规划阶段
  final List<String> planningThoughts;
  final String planningPhase;

  // 结果
  final int? documentId;
  final Map<String, dynamic>? resultData;

  final String? error;
  final bool isExporting;

  const GenerateState({
    this.stage = GenerateStage.input,
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
    this.planningThoughts = const [],
    this.planningPhase = 'analyzing',
    this.documentId,
    this.resultData,
    this.error,
    this.isExporting = false,
  });

  GenerateState copyWith({
    GenerateStage? stage,
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
    List<String>? planningThoughts,
    String? planningPhase,
    Object? documentId = _sentinel,
    Object? resultData = _sentinel,
    String? error,
    bool? isExporting,
    bool clearError = false,
  }) =>
      GenerateState(
        stage: stage ?? this.stage,
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
        planningThoughts: planningThoughts ?? this.planningThoughts,
        planningPhase: planningPhase ?? this.planningPhase,
        documentId: documentId == _sentinel ? this.documentId : documentId as int?,
        resultData: resultData == _sentinel ? this.resultData : resultData as Map<String, dynamic>?,
        error: clearError ? null : (error ?? this.error),
        isExporting: isExporting ?? this.isExporting,
      );

  static const _sentinel = Object();
}
