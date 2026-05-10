import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/generate_data_source.dart';
import '../../data/models/generate_models.dart';
import '../../../../shared/models/dsl/document_block.dart';
import '../../../../shared/models/export_format.dart';
import '../../../../shared/utils/file_export.dart';

final generateProvider =
    StateNotifierProvider<GenerateNotifier, GenerateState>((ref) {
  return GenerateNotifier(GenerateDataSource());
});

class GenerateNotifier extends StateNotifier<GenerateState> {
  final GenerateDataSource _dataSource;
  CancelToken? _cancelToken;

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

  Future<void> startGenerate({bool outlineOnly = false}) async {
    if (state.content.trim().isEmpty) return;

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    state = state.copyWith(
      stage: GenerateStage.generating,
      status: GenerationStatus.planning,
      generatedContent: '',
      progress: 0,
      outlineOnly: outlineOnly,
      outline: [],
      currentBlocks: {},
      streamingBlocks: {},
      documentResult: null,
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
      final stream = _dataSource.generateStream(request, cancelToken: _cancelToken);

      await for (final event in stream) {
        if (!mounted) return;
        _handleEvent(event);
      }

      if (!mounted) return;
      if (state.currentBlocks.isNotEmpty) {
        state = state.copyWith(
          stage: GenerateStage.review,
          status: GenerationStatus.complete,
          progress: 1.0,
        );
      } else if (state.generatedContent.isNotEmpty) {
        // 旧协议 fallback：纯文本模式
        state = state.copyWith(
          stage: GenerateStage.review,
          status: GenerationStatus.complete,
          progress: 1.0,
        );
      } else {
        state = state.copyWith(
          stage: GenerateStage.input,
          status: GenerationStatus.error,
          error: '生成失败，未收到内容',
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      debugPrint('[Generate] Error: $e');
      state = state.copyWith(
        stage: GenerateStage.input,
        status: GenerationStatus.error,
        error: '生成失败，请稍后重试',
      );
    }
  }

  // ==========================================================================
  // SSE 事件处理（对齐 web 端 useDocGenStream.ts）
  // ==========================================================================

  void _handleEvent(GenerateEvent event) {
    final data = event.dataAsJson;
    if (data == null) return;

    final type = data['type'] as String?;
    debugPrint('[Generate] event: type=$type, keys=${data.keys.toList()}');

    switch (type) {
      // --- 规划阶段 ---
      case 'plan_complete':
      case 'planning_complete':
        _onPlanComplete(data);
        break;

      // --- 章节事件 ---
      case 'chapter_start':
        _onChapterStart(data);
        break;
      case 'chapter_end':
        _onChapterEnd(data);
        break;

      // --- Block DSL 粒度事件 ---
      case 'block_start':
        _onBlockStart(data);
        _updateAgentPerception(data);
        break;
      case 'block_delta':
        _onBlockDelta(data);
        break;
      case 'block_data':
        _onBlockData(data);
        break;
      case 'block_end':
        _onBlockEnd(data);
        break;

      // --- v2 渲染事件 ---
      case 'chart_render_complete':
        _onChartRenderComplete(data);
        break;
      case 'image_complete':
        _onImageComplete(data);
        break;

      // --- 完结事件 ---
      case 'final_answer':
      case 'complete':
        _onFinalAnswer(data);
        break;

      // --- 旧协议兼容（direct_llm 模式）---
      case 'chapter_start_old':
        break;
      case 'delta':
        _onLegacyDelta(data);
        break;
      case 'done':
        break;

      case 'error':
        final msg = data['message'] as String? ?? '生成出错';
        state = state.copyWith(
          status: GenerationStatus.error,
          error: msg,
        );
        break;

      // --- Agent 感知事件 ---
      case 'thought':
      case 'tool_call':
      case 'action':
      case 'execute_start':
        _updateAgentPerception(data);
        break;
    }
  }

  String? _resolveChapterId(Map<String, dynamic> data) {
    final chId = data['chapter_id'] as String?;
    if (chId != null) return chId;
    final taskId = data['task_id'] as String?;
    if (taskId != null) {
      final item = state.outline.where((o) => o.taskId == taskId).firstOrNull;
      return item?.chapterId ?? taskId;
    }
    return null;
  }

  void _onPlanComplete(Map<String, dynamic> data) {
    final eventData = data['data'] as Map<String, dynamic>? ?? data;
    final tasks = eventData['tasks'] as List<dynamic>? ?? [];

    final outline = <OutlineItem>[];
    for (final t in tasks) {
      final task = t as Map<String, dynamic>;
      final chapterMeta = task['chapter_meta'] as Map<String, dynamic>? ?? {};
      final chId = chapterMeta['chapter_id'] as String? ?? task['task_id'] as String? ?? task['id'] as String? ?? '';
      final title = chapterMeta['title'] as String? ?? (task['description'] as String?)?.substring(0, (task['description'] as String?)?.length.clamp(0, 30)) ?? '未命名';
      outline.add(OutlineItem(
        chapterId: chId,
        title: title,
        taskId: task['task_id'] as String? ?? task['id'] as String?,
      ));
    }

    state = state.copyWith(
      outline: outline,
      status: GenerationStatus.generating,
    );
  }

  void _onChapterStart(Map<String, dynamic> data) {
    final eventData = data['data'] as Map<String, dynamic>? ?? data;
    final chId = data['chapter_id'] as String? ?? eventData['chapter_id'] as String? ?? data['task_id'] as String? ?? 'ch_${DateTime.now().millisecondsSinceEpoch}';
    final title = eventData['title'] as String? ?? '未命名章节';

    final outline = List<OutlineItem>.from(state.outline);
    final existing = outline.where((o) => o.chapterId == chId).firstOrNull;
    if (existing == null) {
      outline.add(OutlineItem(
        chapterId: chId,
        title: title,
        status: ChapterStatus.generating,
        taskId: data['task_id'] as String?,
      ));
    } else {
      existing.status = ChapterStatus.generating;
    }

    state = state.copyWith(outline: outline);
  }

  void _onChapterEnd(Map<String, dynamic> data) {
    final chId = data['chapter_id'] as String? ?? _resolveChapterId(data);
    if (chId == null) return;

    final outline = List<OutlineItem>.from(state.outline);
    final item = outline.where((o) => o.chapterId == chId).firstOrNull;
    if (item != null) item.status = ChapterStatus.completed;

    // 清理该章节的 streaming blocks
    final streaming = Map<String, StreamingBlock>.from(state.streamingBlocks);
    streaming.removeWhere((key, _) => key.startsWith('$chId:'));

    state = state.copyWith(outline: outline, streamingBlocks: streaming);
  }

  void _onBlockStart(Map<String, dynamic> data) {
    final chId = _resolveChapterId(data);
    final blockId = data['block_id'] as String?;
    final blockType = data['block_type'] as String? ?? 'paragraph';
    final attrs = (data['attrs'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString()));

    if (chId == null || blockId == null) return;

    final sBlock = StreamingBlock(
      id: blockId,
      type: blockType,
      attrs: attrs,
    );

    final streaming = Map<String, StreamingBlock>.from(state.streamingBlocks);
    streaming['$chId:$blockId'] = sBlock;

    // 追加到 currentBlocks
    final blocks = Map<String, List<DocumentBlock>>.from(state.currentBlocks);
    final chapterBlocks = List<DocumentBlock>.from(blocks[chId] ?? []);
    if (!chapterBlocks.any((b) => b.id == blockId)) {
      chapterBlocks.add(sBlock.toDocumentBlock());
      blocks[chId] = chapterBlocks;
    }

    state = state.copyWith(streamingBlocks: streaming, currentBlocks: blocks);
  }

  void _onBlockDelta(Map<String, dynamic> data) {
    final blockId = data['block_id'] as String?;
    if (blockId == null) return;

    final chId = _resolveChapterId(data);
    final delta = data['delta'] as String? ?? '';
    if (chId == null || delta.isEmpty) return;

    final key = '$chId:$blockId';
    final streaming = Map<String, StreamingBlock>.from(state.streamingBlocks);
    final sBlock = streaming[key];
    if (sBlock == null) return;

    sBlock.content += delta;

    // 定点更新 currentBlocks 中单个 block
    final blocks = Map<String, List<DocumentBlock>>.from(state.currentBlocks);
    final chapterBlocks = blocks[chId];
    if (chapterBlocks != null) {
      final idx = chapterBlocks.indexWhere((b) => b.id == blockId);
      if (idx != -1) {
        final updated = List<DocumentBlock>.from(chapterBlocks);
        updated[idx] = sBlock.toDocumentBlock();
        blocks[chId] = updated;
      }
    }

    state = state.copyWith(streamingBlocks: streaming, currentBlocks: blocks);
  }

  void _onBlockData(Map<String, dynamic> data) {
    final chId = _resolveChapterId(data);
    final blockId = data['block_id'] as String?;
    final blockData = data['data'] as Map<String, dynamic>?;
    if (chId == null || blockId == null || blockData == null) return;

    final key = '$chId:$blockId';
    final streaming = Map<String, StreamingBlock>.from(state.streamingBlocks);
    final sBlock = streaming[key];
    if (sBlock == null) return;

    sBlock.data = {...?sBlock.data, ...blockData};

    final blocks = Map<String, List<DocumentBlock>>.from(state.currentBlocks);
    final chapterBlocks = blocks[chId];
    if (chapterBlocks != null) {
      final idx = chapterBlocks.indexWhere((b) => b.id == blockId);
      if (idx != -1) {
        final updated = List<DocumentBlock>.from(chapterBlocks);
        updated[idx] = sBlock.toDocumentBlock();
        blocks[chId] = updated;
      }
    }

    state = state.copyWith(streamingBlocks: streaming, currentBlocks: blocks);
  }

  void _onBlockEnd(Map<String, dynamic> data) {
    final chId = _resolveChapterId(data);
    final blockId = data['block_id'] as String?;
    if (chId == null || blockId == null) return;

    final key = '$chId:$blockId';
    final streaming = Map<String, StreamingBlock>.from(state.streamingBlocks);
    final sBlock = streaming[key];
    if (sBlock != null) {
      sBlock.status = 'complete';
      streaming.remove(key);

      final blocks = Map<String, List<DocumentBlock>>.from(state.currentBlocks);
      final chapterBlocks = blocks[chId];
      if (chapterBlocks != null) {
        final idx = chapterBlocks.indexWhere((b) => b.id == blockId);
        if (idx != -1) {
          final updated = List<DocumentBlock>.from(chapterBlocks);
          updated[idx] = sBlock.toDocumentBlock();
          blocks[chId] = updated;
        }
      }

      state = state.copyWith(streamingBlocks: streaming, currentBlocks: blocks);
    }
  }

  void _onChartRenderComplete(Map<String, dynamic> data) {
    final chId = _resolveChapterId(data);
    final blockId = data['block_id'] as String?;
    final url = data['url'] as String?;
    if (chId == null || blockId == null || url == null) return;

    final blocks = Map<String, List<DocumentBlock>>.from(state.currentBlocks);
    final chapterBlocks = blocks[chId];
    if (chapterBlocks != null) {
      final updated = chapterBlocks.map((b) {
        if (b.id == blockId) {
          return b.copyWith(url: url, renderStatus: RenderStatus.done);
        }
        return b;
      }).toList();
      blocks[chId] = updated;
    }

    state = state.copyWith(currentBlocks: blocks);
  }

  void _onImageComplete(Map<String, dynamic> data) {
    final chId = _resolveChapterId(data);
    final blockId = data['block_id'] as String?;
    final url = data['url'] as String?;
    if (chId == null || blockId == null || url == null) return;

    final blocks = Map<String, List<DocumentBlock>>.from(state.currentBlocks);
    final chapterBlocks = blocks[chId];
    if (chapterBlocks != null) {
      final updated = chapterBlocks.map((b) {
        if (b.id == blockId) return b.copyWith(url: url);
        return b;
      }).toList();
      blocks[chId] = updated;
    }

    state = state.copyWith(currentBlocks: blocks);
  }

  void _onFinalAnswer(Map<String, dynamic> data) {
    final eventData = data['data'] as Map<String, dynamic>? ?? data;
    final docResult = eventData['doc_result'] as Map<String, dynamic>? ??
        (eventData['output'] is Map<String, dynamic> && (eventData['output'] as Map).containsKey('chapters')
            ? eventData['output'] as Map<String, dynamic>
            : null);

    if (docResult != null) {
      state = state.copyWith(documentResult: DocumentResult.fromJson(docResult));
    } else {
      // 从已有 outline + currentBlocks 构建
      final chapters = state.outline.map((item) {
        final blocks = state.currentBlocks[item.chapterId] ?? [];
        return ChapterDoc(
          chapterId: item.chapterId,
          title: item.title,
          blocks: blocks,
          wordCount: blocks.fold(0, (sum, b) => sum + (b.text?.length ?? 0)),
        );
      }).toList();
      state = state.copyWith(
        documentResult: DocumentResult(documentTitle: '', chapters: chapters),
      );
    }
  }

  void _onLegacyDelta(Map<String, dynamic> data) {
    // direct_llm 模式的旧协议：纯文本追加
    final text = data['text'] as String? ?? '';
    if (text.isEmpty) return;

    final chapterTitle = data['chapter_title'] as String?;
    if (chapterTitle != null) {
      final chId = data['chapter_id'] as String? ?? 'ch_${state.outline.length}';
      final outline = List<OutlineItem>.from(state.outline);
      if (!outline.any((o) => o.chapterId == chId)) {
        outline.add(OutlineItem(
          chapterId: chId,
          title: chapterTitle,
          status: ChapterStatus.generating,
        ));
        state = state.copyWith(outline: outline);
      }
    }

    state = state.copyWith(
      generatedContent: state.generatedContent + text,
      progress: (state.outline.where((o) => o.status == ChapterStatus.completed).length / (state.outline.length + 1)).clamp(0.0, 0.95),
    );
  }

  void _updateAgentPerception(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final isThinking = type == 'thought';
    final isToolCalling = type == 'tool_call' || type == 'action' || type == 'execute_start';
    final isWriting = type == 'block_start';
    if (!isThinking && !isToolCalling && !isWriting) return;

    final chId = _resolveChapterId(data);
    if (chId == null) return;

    final outline = List<OutlineItem>.from(state.outline);
    final item = outline.where((o) => o.chapterId == chId).firstOrNull;
    if (item == null) return;

    if (isThinking) {
      final content = data['content'] as String? ?? '';
      item.agentStatusMsg = '思考中: ${content.substring(0, content.length.clamp(0, 60))}...';
    } else if (isToolCalling) {
      final toolName = (data['data'] as Map<String, dynamic>?)?['tool'] as String? ??
          (data['data'] as Map<String, dynamic>?)?['name'] as String? ?? '工具';
      item.agentStatusMsg = '调度工具: $toolName';
    } else if (isWriting) {
      item.agentStatusMsg = '正在撰写...';
    }

    state = state.copyWith(outline: outline);
  }

  void backToInput() {
    _cancelToken?.cancel();
    state = state.copyWith(stage: GenerateStage.input);
  }

  void backToGenerating() {
    state = state.copyWith(stage: GenerateStage.generating);
  }

  Future<void> exportDocument() async {
    state = state.copyWith(isExporting: true);
    try {
      final bytes = await _dataSource.exportDocument(
        'current',
        state.selectedFormat,
      );
      final title = state.documentResult?.documentTitle ?? 'document';
      await FileExporter.saveAndShare(
        bytes: Uint8List.fromList(bytes),
        fileName: '$title.${state.selectedFormat.extension}',
        subject: title,
      );
    } catch (e) {
      debugPrint('[Generate] Export error: $e');
    } finally {
      state = state.copyWith(isExporting: false);
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }
}

class GenerateState {
  final GenerateStage stage;
  final DocType selectedType;
  final DocLanguage selectedLanguage;
  final String content;
  final ExportFormat selectedFormat;
  final bool outlineOnly;

  // 生成状态
  final GenerationStatus status;
  final String docTitle;
  final String generatedContent;
  final double progress;

  // Block DSL 状态
  final List<OutlineItem> outline;
  final Map<String, List<DocumentBlock>> currentBlocks;
  final Map<String, StreamingBlock> streamingBlocks;
  final DocumentResult? documentResult;

  final String? error;
  final bool isExporting;

  const GenerateState({
    this.stage = GenerateStage.input,
    this.selectedType = DocType.contract,
    this.selectedLanguage = DocLanguage.zhCN,
    this.content = '',
    this.selectedFormat = ExportFormat.docx,
    this.outlineOnly = false,
    this.status = GenerationStatus.idle,
    this.docTitle = '',
    this.generatedContent = '',
    this.progress = 0,
    this.outline = const [],
    this.currentBlocks = const {},
    this.streamingBlocks = const {},
    this.documentResult,
    this.error,
    this.isExporting = false,
  });

  GenerateState copyWith({
    GenerateStage? stage,
    DocType? selectedType,
    DocLanguage? selectedLanguage,
    String? content,
    ExportFormat? selectedFormat,
    bool? outlineOnly,
    GenerationStatus? status,
    String? docTitle,
    String? generatedContent,
    double? progress,
    List<OutlineItem>? outline,
    Map<String, List<DocumentBlock>>? currentBlocks,
    Map<String, StreamingBlock>? streamingBlocks,
    DocumentResult? documentResult,
    String? error,
    bool? isExporting,
    bool clearError = false,
    bool clearDocumentResult = false,
  }) =>
      GenerateState(
        stage: stage ?? this.stage,
        selectedType: selectedType ?? this.selectedType,
        selectedLanguage: selectedLanguage ?? this.selectedLanguage,
        content: content ?? this.content,
        selectedFormat: selectedFormat ?? this.selectedFormat,
        outlineOnly: outlineOnly ?? this.outlineOnly,
        status: status ?? this.status,
        docTitle: docTitle ?? this.docTitle,
        generatedContent: generatedContent ?? this.generatedContent,
        progress: progress ?? this.progress,
        outline: outline ?? this.outline,
        currentBlocks: currentBlocks ?? this.currentBlocks,
        streamingBlocks: streamingBlocks ?? this.streamingBlocks,
        documentResult: clearDocumentResult ? null : (documentResult ?? this.documentResult),
        error: clearError ? null : (error ?? this.error),
        isExporting: isExporting ?? this.isExporting,
      );
}
