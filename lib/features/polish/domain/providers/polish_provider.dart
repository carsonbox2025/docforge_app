import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/polish_models.dart';
import '../../data/polish_data_source.dart';
import '../../../generate/data/task_data_source.dart';
import '../../../../shared/models/dsl/dsl_node.dart' show DslNode;

enum PolishStage { input, result }

class PolishState {
  final PolishStage stage;
  final InputMode inputMode;
  final PolishLevel level;
  final String docType;
  final ExportFormat exportFormat;
  final CompareTab compareTab;
  final String? fileName;
  final String? textContent;
  final bool isProcessing;
  final String streamingText;
  final PolishResult? result;
  final String? errorMessage;

  // 进度
  final double progress;
  final String progressMsg;

  // DSL 状态
  final List<DslNode> dslNodes;
  final int? taskId;

  // 模式
  final String mode; // quick / professional

  const PolishState({
    this.stage = PolishStage.input,
    this.inputMode = InputMode.upload,
    this.level = PolishLevel.medium,
    this.docType = '自动检测',
    this.exportFormat = ExportFormat.docx,
    this.compareTab = CompareTab.diff,
    this.fileName,
    this.textContent,
    this.isProcessing = false,
    this.streamingText = '',
    this.result,
    this.errorMessage,
    this.progress = 0,
    this.progressMsg = '',
    this.dslNodes = const [],
    this.taskId,
    this.mode = 'quick',
  });

  PolishState copyWith({
    PolishStage? stage,
    InputMode? inputMode,
    PolishLevel? level,
    String? docType,
    ExportFormat? exportFormat,
    CompareTab? compareTab,
    String? fileName,
    String? textContent,
    bool? isProcessing,
    String? streamingText,
    PolishResult? result,
    String? errorMessage,
    double? progress,
    String? progressMsg,
    List<DslNode>? dslNodes,
    int? taskId,
    String? mode,
    bool clearResult = false,
    bool clearError = false,
    bool clearFileName = false,
    bool clearTextContent = false,
    bool clearStreamingText = false,
    bool clearTaskId = false,
  }) {
    return PolishState(
      stage: stage ?? this.stage,
      inputMode: inputMode ?? this.inputMode,
      level: level ?? this.level,
      docType: docType ?? this.docType,
      exportFormat: exportFormat ?? this.exportFormat,
      compareTab: compareTab ?? this.compareTab,
      fileName: clearFileName ? null : (fileName ?? this.fileName),
      textContent: clearTextContent ? null : (textContent ?? this.textContent),
      isProcessing: isProcessing ?? this.isProcessing,
      streamingText: clearStreamingText ? '' : (streamingText ?? this.streamingText),
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      progress: progress ?? this.progress,
      progressMsg: progressMsg ?? this.progressMsg,
      dslNodes: dslNodes ?? this.dslNodes,
      taskId: clearTaskId ? null : (taskId ?? this.taskId),
      mode: mode ?? this.mode,
    );
  }
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

  void setInputMode(InputMode mode) => state = state.copyWith(inputMode: mode);
  void setLevel(PolishLevel level) => state = state.copyWith(level: level);
  void setDocType(String docType) => state = state.copyWith(docType: docType);
  void setExportFormat(ExportFormat format) => state = state.copyWith(exportFormat: format);
  void setCompareTab(CompareTab tab) => state = state.copyWith(compareTab: tab);
  void setFileName(String? name) => state = state.copyWith(fileName: name ?? '', clearFileName: name == null);
  void setTextContent(String text) => state = state.copyWith(textContent: text);
  void setMode(String mode) => state = state.copyWith(mode: mode);

  /// 开始润色（通过统一任务服务）
  Future<void> startPolish() async {
    final text = state.textContent;
    if (text == null || text.trim().isEmpty) {
      state = state.copyWith(errorMessage: '请输入或上传需要润色的文本');
      return;
    }

    _progressSub?.cancel();
    state = state.copyWith(isProcessing: true, clearError: true, clearStreamingText: true);

    try {
      final request = PolishRequest(
        text: text,
        inputMode: state.inputMode,
        level: state.level,
        docType: state.docType,
        fileName: state.fileName,
        mode: state.mode,
      );

      final taskId = await _dataSource.submitPolishTask(request);
      state = state.copyWith(taskId: taskId);

      _listenProgress(taskId, text);
    } catch (e) {
      debugPrint('[Polish] submit error: $e');
      state = state.copyWith(
        isProcessing: false,
        errorMessage: '润色提交失败: $e',
      );
    }
  }

  void _listenProgress(int taskId, String originalText) {
    _progressSub?.cancel();
    final buffer = StringBuffer();

    final stream = _dataSource.polishProgressStream(taskId);
    _progressSub = stream.listen(
      (update) {
        if (!mounted) return;

        // 解析 DSL 更新
        final detail = update.detail;
        if (detail != null) {
          _handleDslUpdate(detail, buffer);
        }

        state = state.copyWith(
          progress: update.progress,
          progressMsg: update.message,
        );
      },
      onDone: () {
        if (!mounted) return;
        _onStreamDone(taskId, originalText);
      },
      onError: (e) {
        if (!mounted) return;
        debugPrint('[Polish] progress error: $e');
        state = state.copyWith(
          isProcessing: false,
          errorMessage: '润色失败，请重试',
        );
      },
    );
  }

  void _handleDslUpdate(Map<String, dynamic> detail, StringBuffer buffer) {
    final dslUpdate = detail['dsl_update'] as Map<String, dynamic>?;
    if (dslUpdate == null) return;

    // 从 DSL nodes 中提取文本
    final nodeUpdates = dslUpdate['node_updates'] as List<dynamic>?;
    if (nodeUpdates != null) {
      var allNodes = <DslNode>[...state.dslNodes];

      for (final update in nodeUpdates) {
        final u = update as Map<String, dynamic>;
        final op = u['op'] as String? ?? 'append';

        if (op == 'replace_all') {
          final rawNodes = u['nodes'] as List<dynamic>? ?? [];
          allNodes = rawNodes.map((n) => DslNode.fromJson(n as Map<String, dynamic>)).toList();
        } else if (op == 'append') {
          final rawNode = u['node'] as Map<String, dynamic>?;
          if (rawNode != null) {
            allNodes.add(DslNode.fromJson(rawNode));
          }
        }
      }

      // 从 nodes 提取文本用于 streamingText
      final texts = allNodes
          .where((n) => n.text != null && n.text!.isNotEmpty)
          .map((n) => n.text!)
          .join('\n\n');

      state = state.copyWith(
        dslNodes: allNodes,
        streamingText: texts,
      );
    }
  }

  Future<void> _onStreamDone(int taskId, String originalText) async {
    try {
      final status = await _dataSource.getTaskStatus(taskId);
      if (status.status == TaskStatus.completed) {
        String polished = state.streamingText;

        // 从 dsl_content 提取润色结果
        final dslContent = status.resultData;
        if (dslContent != null) {
          final extracted = _extractTextFromDsl(dslContent);
          if (extracted.isNotEmpty) {
            polished = extracted;
          }
        }

        state = state.copyWith(
          isProcessing: false,
          stage: PolishStage.result,
          result: _buildResult(polished, originalText),
        );
      } else if (status.status == TaskStatus.failed) {
        state = state.copyWith(
          isProcessing: false,
          errorMessage: status.errorMsg ?? '润色失败',
        );
      } else {
        state = state.copyWith(
          isProcessing: false,
          errorMessage: '润色超时',
        );
      }
    } catch (e) {
      final polished = state.streamingText;
      if (polished.isNotEmpty) {
        state = state.copyWith(
          isProcessing: false,
          stage: PolishStage.result,
          result: _buildResult(polished, originalText),
        );
      } else {
        state = state.copyWith(
          isProcessing: false,
          errorMessage: '润色失败，未收到结果',
        );
      }
    }
  }

  String _extractTextFromDsl(Map<String, dynamic> dsl) {
    final children = dsl['children'] as List<dynamic>? ?? [];
    final texts = <String>[];
    for (final section in children) {
      final nodes = section['children'] as List<dynamic>? ?? [];
      for (final node in nodes) {
        final text = node['text'] as String?;
        if (text != null && text.isNotEmpty) {
          texts.add(text);
        }
      }
    }
    return texts.join('\n\n');
  }

  PolishResult _buildResult(String polishedText, String originalText) {
    final paragraphs = _generateDiffParagraphs(originalText, polishedText);
    return PolishResult(
      title: state.fileName ?? '文档润色',
      level: state.level,
      changeCount: _countChanges(paragraphs),
      acceptedCount: _countChanges(paragraphs),
      pendingCount: 0,
      paragraphs: paragraphs,
      originalText: originalText,
      polishedText: polishedText,
    );
  }

  List<PolishParagraph> _generateDiffParagraphs(String original, String polished) {
    final originalLines = original.split(RegExp(r'\n')).where((l) => l.trim().isNotEmpty).toList();
    final polishedLines = polished.split(RegExp(r'\n')).where((l) => l.trim().isNotEmpty).toList();
    final paragraphs = <PolishParagraph>[];
    final maxLen = originalLines.length > polishedLines.length ? originalLines.length : polishedLines.length;

    for (var i = 0; i < maxLen; i++) {
      final segments = <DiffSegment>[];
      if (i < originalLines.length && i < polishedLines.length) {
        if (originalLines[i].trim() == polishedLines[i].trim()) {
          segments.add(DiffSegment(type: 'equal', text: originalLines[i].trim()));
        } else {
          segments.add(DiffSegment(type: 'delete', text: originalLines[i].trim()));
          segments.add(DiffSegment(type: 'insert', text: polishedLines[i].trim()));
        }
      } else if (i < originalLines.length) {
        segments.add(DiffSegment(type: 'delete', text: originalLines[i].trim()));
      } else {
        segments.add(DiffSegment(type: 'insert', text: polishedLines[i].trim()));
      }
      if (segments.isNotEmpty) paragraphs.add(PolishParagraph(segments: segments));
    }
    return paragraphs;
  }

  int _countChanges(List<PolishParagraph> paragraphs) {
    int count = 0;
    for (final para in paragraphs) {
      for (final seg in para.segments) {
        if (seg.type == 'delete' || seg.type == 'insert') count++;
      }
    }
    return count;
  }

  void goBackToInput() {
    _progressSub?.cancel();
    state = state.copyWith(stage: PolishStage.input, clearResult: true, clearStreamingText: true);
  }

  void rePolish() {
    _progressSub?.cancel();
    state = state.copyWith(stage: PolishStage.input, clearResult: true, clearStreamingText: true);
  }

  Future<void> exportResult() async {
    final result = state.result;
    if (result == null) return;
    state = state.copyWith(isProcessing: true);
    try {
      await _dataSource.exportResult(taskId: result.title, format: state.exportFormat);
      state = state.copyWith(isProcessing: false);
    } catch (e) {
      debugPrint('[Polish] Export error: $e');
      state = state.copyWith(isProcessing: false, errorMessage: '导出失败');
    }
  }
}

final polishDataSourceProvider = Provider<PolishRemoteDataSource>((ref) {
  return PolishRemoteDataSource();
});

final polishProvider = StateNotifierProvider<PolishNotifier, PolishState>((ref) {
  return PolishNotifier(dataSource: ref.read(polishDataSourceProvider));
});
