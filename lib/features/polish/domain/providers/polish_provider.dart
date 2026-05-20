import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../data/models/polish_models.dart';
import '../../data/polish_data_source.dart';
import '../../../generate/data/task_data_source.dart';
import '../../../../shared/utils/file_export.dart';

class PolishState {
  final PolishStage stage;
  final InputMode inputMode;
  final PolishLevel level;
  final String docType;
  final String? textContent;
  final String? fileName;
  final String? filePath;
  final int? fileSize;
  final bool isProcessing;
  final String? errorMessage;

  // 审阅进度
  final double progress;
  final String progressMsg;
  final List<OutlineItem> outline;

  // 建议列表
  final List<PolishSuggestion> suggestions;
  final String? filterCategory;
  final String? filterSeverity;
  final String filterStatus; // 'all' | 'pending' | 'processed'
  final int currentSuggestionIndex;

  // 原始段落
  final List<SourceParagraph> originalParagraphs;

  // 任务/文档 ID
  final int? taskId;
  final int? documentId;
  final String? sourceFileUrl;

  // Undo/Redo
  final List<PolishUndoAction> undoStack;
  final int undoStackPointer;

  // 统计
  final int totalSuggestions;
  final int acceptedCount;
  final int rejectedCount;
  final int pendingCount;

  const PolishState({
    this.stage = PolishStage.input,
    this.inputMode = InputMode.text,
    this.level = PolishLevel.medium,
    this.docType = '自动检测',
    this.textContent,
    this.fileName,
    this.filePath,
    this.fileSize,
    this.isProcessing = false,
    this.errorMessage,
    this.progress = 0,
    this.progressMsg = '',
    this.outline = const [],
    this.suggestions = const [],
    this.filterCategory,
    this.filterSeverity,
    this.filterStatus = 'pending',
    this.currentSuggestionIndex = -1,
    this.originalParagraphs = const [],
    this.taskId,
    this.documentId,
    this.sourceFileUrl,
    this.undoStack = const [],
    this.undoStackPointer = 0,
    this.totalSuggestions = 0,
    this.acceptedCount = 0,
    this.rejectedCount = 0,
    this.pendingCount = 0,
  });

  PolishState copyWith({
    PolishStage? stage,
    InputMode? inputMode,
    PolishLevel? level,
    String? docType,
    String? textContent,
    String? fileName,
    String? filePath,
    int? fileSize,
    bool? isProcessing,
    String? errorMessage,
    double? progress,
    String? progressMsg,
    List<OutlineItem>? outline,
    List<PolishSuggestion>? suggestions,
    String? filterCategory,
    String? filterSeverity,
    String? filterStatus,
    int? currentSuggestionIndex,
    List<SourceParagraph>? originalParagraphs,
    int? taskId,
    int? documentId,
    String? sourceFileUrl,
    List<PolishUndoAction>? undoStack,
    int? undoStackPointer,
    bool clearError = false,
    bool clearFileName = false,
    bool clearFilePath = false,
    bool clearTextContent = false,
    bool clearFilterCategory = false,
    bool clearFilterSeverity = false,
  }) {
    final newSuggestions = suggestions ?? this.suggestions;
    return PolishState(
      stage: stage ?? this.stage,
      inputMode: inputMode ?? this.inputMode,
      level: level ?? this.level,
      docType: docType ?? this.docType,
      textContent: clearTextContent ? null : (textContent ?? this.textContent),
      fileName: clearFileName ? null : (fileName ?? this.fileName),
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      fileSize: fileSize ?? this.fileSize,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      progress: progress ?? this.progress,
      progressMsg: progressMsg ?? this.progressMsg,
      outline: outline ?? this.outline,
      suggestions: newSuggestions,
      filterCategory: clearFilterCategory ? null : (filterCategory ?? this.filterCategory),
      filterSeverity: clearFilterSeverity ? null : (filterSeverity ?? this.filterSeverity),
      filterStatus: filterStatus ?? this.filterStatus,
      currentSuggestionIndex: currentSuggestionIndex ?? this.currentSuggestionIndex,
      originalParagraphs: originalParagraphs ?? this.originalParagraphs,
      taskId: taskId ?? this.taskId,
      documentId: documentId ?? this.documentId,
      sourceFileUrl: sourceFileUrl ?? this.sourceFileUrl,
      undoStack: undoStack ?? this.undoStack,
      undoStackPointer: undoStackPointer ?? this.undoStackPointer,
      totalSuggestions: newSuggestions.length,
      acceptedCount: newSuggestions.where((s) => s.status == 'accepted').length,
      rejectedCount: newSuggestions.where((s) => s.status == 'rejected').length,
      pendingCount: newSuggestions.where((s) => s.status == 'pending').length,
    );
  }

  List<PolishSuggestion> get filteredSuggestions {
    var list = suggestions;
    if (filterStatus == 'pending') {
      list = list.where((s) => s.status == 'pending').toList();
    } else if (filterStatus == 'processed') {
      list = list.where((s) => s.status != 'pending').toList();
    }
    if (filterCategory != null) {
      list = list.where((s) => s.category == filterCategory).toList();
    }
    if (filterSeverity != null) {
      list = list.where((s) => s.severity == filterSeverity).toList();
    }
    return list;
  }

  bool get canUndo => undoStackPointer > 0;
  bool get canRedo => undoStackPointer < undoStack.length;
}

class PolishNotifier extends StateNotifier<PolishState> {
  final PolishRemoteDataSource _dataSource;
  StreamSubscription? _progressSub;

  PolishNotifier({required PolishRemoteDataSource dataSource})
      : _dataSource = dataSource,
        super(const PolishState());

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  // ─── 设置方法 ───

  void setInputMode(InputMode mode) => state = state.copyWith(inputMode: mode);
  void setLevel(PolishLevel level) => state = state.copyWith(level: level);
  void setDocType(String docType) => state = state.copyWith(docType: docType);
  void setTextContent(String text) => state = state.copyWith(textContent: text);
  void setFileName(String? name) =>
      state = state.copyWith(fileName: name ?? '', clearFileName: name == null);
  void setFilePath(String? path) =>
      state = state.copyWith(filePath: path, clearFilePath: path == null);

  void setFile(String? name, String? path, int? size) {
    state = state.copyWith(
      fileName: name,
      filePath: path,
      fileSize: size,
      clearFileName: name == null,
      clearFilePath: path == null,
    );
  }

  void setFilterCategory(String? category) =>
      state = state.copyWith(filterCategory: category, clearFilterCategory: category == null);
  void setFilterSeverity(String? severity) =>
      state = state.copyWith(filterSeverity: severity, clearFilterSeverity: severity == null);
  void setFilterStatus(String status) =>
      state = state.copyWith(filterStatus: status);
  void setCurrentSuggestionIndex(int index) =>
      state = state.copyWith(currentSuggestionIndex: index);

  // ─── 建议操作 ───

  void acceptSuggestion(String id) {
    final idx = state.suggestions.indexWhere((s) => s.id == id);
    if (idx < 0) return;

    final previousStatus = state.suggestions[idx].status;
    final newUndoStack = state.undoStack.sublist(0, state.undoStackPointer).toList()
      ..add(PolishUndoAction(
        action: 'accept',
        suggestionId: id,
        previousStatus: previousStatus,
      ));

    final newSuggestions = List<PolishSuggestion>.from(state.suggestions);
    newSuggestions[idx] = newSuggestions[idx].copyWith(status: 'accepted');

    state = state.copyWith(
      suggestions: newSuggestions,
      undoStack: newUndoStack,
      undoStackPointer: newUndoStack.length,
    );
  }

  void rejectSuggestion(String id) {
    final idx = state.suggestions.indexWhere((s) => s.id == id);
    if (idx < 0) return;

    final previousStatus = state.suggestions[idx].status;
    final newUndoStack = state.undoStack.sublist(0, state.undoStackPointer).toList()
      ..add(PolishUndoAction(
        action: 'reject',
        suggestionId: id,
        previousStatus: previousStatus,
      ));

    final newSuggestions = List<PolishSuggestion>.from(state.suggestions);
    newSuggestions[idx] = newSuggestions[idx].copyWith(status: 'rejected');

    state = state.copyWith(
      suggestions: newSuggestions,
      undoStack: newUndoStack,
      undoStackPointer: newUndoStack.length,
    );
  }

  void acceptAll() {
    final newSuggestions = state.suggestions
        .map((s) => s.status == 'pending' ? s.copyWith(status: 'accepted') : s)
        .toList();
    state = state.copyWith(suggestions: newSuggestions);
  }

  void rejectAll() {
    final newSuggestions = state.suggestions
        .map((s) => s.status == 'pending' ? s.copyWith(status: 'rejected') : s)
        .toList();
    state = state.copyWith(suggestions: newSuggestions);
  }

  void undo() {
    if (!state.canUndo) return;
    final pointer = state.undoStackPointer - 1;
    final action = state.undoStack[pointer];
    final idx = state.suggestions.indexWhere((s) => s.id == action.suggestionId);
    if (idx >= 0) {
      final newSuggestions = List<PolishSuggestion>.from(state.suggestions);
      newSuggestions[idx] = newSuggestions[idx].copyWith(status: action.previousStatus);
      state = state.copyWith(suggestions: newSuggestions, undoStackPointer: pointer);
    }
  }

  void redo() {
    if (!state.canRedo) return;
    final action = state.undoStack[state.undoStackPointer];
    final idx = state.suggestions.indexWhere((s) => s.id == action.suggestionId);
    if (idx >= 0) {
      final newSuggestions = List<PolishSuggestion>.from(state.suggestions);
      final newStatus = action.action == 'accept' ? 'accepted' : 'rejected';
      newSuggestions[idx] = newSuggestions[idx].copyWith(status: newStatus);
      state = state.copyWith(
        suggestions: newSuggestions,
        undoStackPointer: state.undoStackPointer + 1,
      );
    }
  }

  // ─── 开始精修 ───

  Future<void> startPolish() async {
    final text = state.textContent;
    final hasFile = state.filePath != null && state.filePath!.isNotEmpty;

    if (!hasFile && (text == null || text.trim().isEmpty)) {
      state = state.copyWith(errorMessage: '请输入或上传需要审阅的文本');
      return;
    }

    _progressSub?.cancel();
    state = state.copyWith(
      isProcessing: true,
      stage: PolishStage.reviewing,
      clearError: true,
    );

    try {
      final request = PolishRequest(
        text: text,
        filePath: state.filePath,
        inputMode: state.inputMode,
        level: state.level,
        docType: state.docType,
        fileName: state.fileName,
      );

      final taskId = await _dataSource.submitPolishTask(request);
      state = state.copyWith(taskId: taskId);
      _listenProgress(taskId);
    } catch (e) {
      debugPrint('[Polish] submit error: $e');
      state = state.copyWith(
        isProcessing: false,
        stage: PolishStage.input,
        errorMessage: '提交失败: $e',
      );
    }
  }

  void _listenProgress(int taskId) {
    _progressSub?.cancel();

    final stream = _dataSource.polishProgressStream(taskId);
    _progressSub = stream.listen(
      (update) {
        if (!mounted) return;

        final detail = update.detail;
        if (detail != null) {
          _handleDetail(detail);
        }

        state = state.copyWith(
          progress: update.progress,
          progressMsg: update.message,
        );
      },
      onDone: () {
        if (!mounted) return;
        _onStreamDone(taskId);
      },
      onError: (e) {
        if (!mounted) return;
        debugPrint('[Polish] progress error: $e');
        state = state.copyWith(
          isProcessing: false,
          stage: PolishStage.input,
          errorMessage: '审阅失败，请重试',
        );
      },
    );
  }

  void _handleDetail(Map<String, dynamic> detail) {
    // 建议更新
    final suggestionsUpdate = detail['suggestions_update'] as Map<String, dynamic>?;
    if (suggestionsUpdate != null) {
      final rawSuggestions = suggestionsUpdate['suggestions'] as List<dynamic>? ?? [];
      final newItems = rawSuggestions
          .map((s) => PolishSuggestion.fromJson(s as Map<String, dynamic>))
          .toList();

      // 追加到现有建议列表
      final allSuggestions = [...state.suggestions, ...newItems];
      state = state.copyWith(suggestions: allSuggestions);

      // 首批建议到达后提前进入 ReviewStage
      if (state.stage == PolishStage.reviewing && allSuggestions.isNotEmpty) {
        state = state.copyWith(stage: PolishStage.review);
      }
    }

    // 章节大纲
    final outlineData = detail['outline'] as Map<String, dynamic>?;
    if (outlineData != null) {
      final sections = outlineData['sections'] as List<dynamic>? ?? [];
      final items = sections
          .map((s) => OutlineItem.fromJson(s as Map<String, dynamic>))
          .toList();
      state = state.copyWith(outline: items);
    }

    // 审阅完成
    final reviewComplete = detail['review_complete'] as Map<String, dynamic>?;
    if (reviewComplete != null) {
      // 从进度流中我们已经收集了建议，无需额外处理
      debugPrint('[Polish] review complete: ${reviewComplete['total_suggestions']} suggestions');
    }
  }

  Future<void> _onStreamDone(int taskId) async {
    try {
      final status = await _dataSource.getTaskStatus(taskId);
      if (status.status == TaskStatus.completed) {
        // 从 dsl_content 提取 PolishResult
        final dslContent = status.resultData;
        if (dslContent != null) {
          _parsePolishResult(dslContent);
        }

        state = state.copyWith(
          isProcessing: false,
          stage: PolishStage.review,
          documentId: taskId,
        );
      } else if (status.status == TaskStatus.failed) {
        state = state.copyWith(
          isProcessing: false,
          stage: PolishStage.input,
          errorMessage: status.errorMsg ?? '审阅失败',
        );
      }
    } catch (e) {
      debugPrint('[Polish] onStreamDone error: $e');
      if (state.suggestions.isNotEmpty) {
        state = state.copyWith(isProcessing: false, stage: PolishStage.review);
      } else {
        state = state.copyWith(
          isProcessing: false,
          stage: PolishStage.input,
          errorMessage: '审阅失败，未收到结果',
        );
      }
    }
  }

  void _parsePolishResult(Map<String, dynamic> data) {
    if (data['source_type'] != 'polish') return;

    final rawParagraphs = data['original_paragraphs'] as List<dynamic>? ?? [];
    final paragraphs = rawParagraphs
        .map((p) => SourceParagraph.fromJson(p as Map<String, dynamic>))
        .toList();

    // 如果 SSE 流已经推送了建议，则不重复添加
    final existingIds = state.suggestions.map((s) => s.id).toSet();
    final rawSuggestions = data['suggestions'] as List<dynamic>? ?? [];
    final extraSuggestions = rawSuggestions
        .map((s) => PolishSuggestion.fromJson(s as Map<String, dynamic>))
        .where((s) => !existingIds.contains(s.id))
        .toList();

    final allSuggestions = [...state.suggestions, ...extraSuggestions];

    state = state.copyWith(
      originalParagraphs: paragraphs,
      suggestions: allSuggestions,
      sourceFileUrl: data['source_file_url'] as String?,
    );
  }

  // ─── 导出 ───

  Future<void> exportDocument(ExportMode mode) async {
    final documentId = state.documentId;
    if (documentId == null) return;

    state = state.copyWith(isProcessing: true);
    try {
      final response = await _dataSource.exportWord(
        documentId: documentId,
        exportMode: mode,
        suggestions: state.suggestions,
      );

      final bytes = response.data is List<int>
          ? Uint8List.fromList(response.data as List<int>)
          : response.data as Uint8List;

      final title = state.suggestions.isNotEmpty
          ? '精修文档'
          : '审阅报告';
      final modeSuffix = mode == ExportMode.report ? '_报告' : '';
      await FileExporter.saveAndOpen(
        bytes: bytes,
        fileName: '$title$modeSuffix.docx',
      );

      state = state.copyWith(isProcessing: false);
    } catch (e) {
      debugPrint('[Polish] export error: $e');
      if (mounted) {
        state = state.copyWith(
          isProcessing: false,
          errorMessage: '导出失败：$e',
        );
      }
    }
  }

  // ─── 导航 ───

  void goBackToInput() {
    _progressSub?.cancel();
    state = state.copyWith(
      stage: PolishStage.input,
      isProcessing: false,
      suggestions: [],
      outline: [],
      originalParagraphs: [],
      undoStack: [],
      undoStackPointer: 0,
      progress: 0,
      clearError: true,
    );
  }
}

final polishDataSourceProvider = Provider<PolishRemoteDataSource>((ref) {
  return PolishRemoteDataSource();
});

final polishProvider = StateNotifierProvider<PolishNotifier, PolishState>((ref) {
  return PolishNotifier(dataSource: ref.read(polishDataSourceProvider));
});
