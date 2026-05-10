import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/polish_models.dart';
import '../../data/polish_data_source.dart';

/// 页面阶段
enum PolishStage {
  input,
  result,
}

/// 页面状态
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
  final String streamingText; // SSE 流式文本（逐字显示）
  final PolishResult? result;
  final String? errorMessage;

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
    bool clearResult = false,
    bool clearError = false,
    bool clearFileName = false,
    bool clearTextContent = false,
    bool clearStreamingText = false,
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
    );
  }
}

class PolishNotifier extends StateNotifier<PolishState> {
  final PolishRemoteDataSource _dataSource;
  StreamSubscription? _sseSubscription;

  PolishNotifier({required PolishRemoteDataSource dataSource})
      : _dataSource = dataSource,
        super(const PolishState());

  @override
  void dispose() {
    _sseSubscription?.cancel();
    super.dispose();
  }

  void setInputMode(InputMode mode) {
    state = state.copyWith(inputMode: mode);
  }

  void setLevel(PolishLevel level) {
    state = state.copyWith(level: level);
  }

  void setDocType(String docType) {
    state = state.copyWith(docType: docType);
  }

  void setExportFormat(ExportFormat format) {
    state = state.copyWith(exportFormat: format);
  }

  void setCompareTab(CompareTab tab) {
    state = state.copyWith(compareTab: tab);
  }

  void setFileName(String? name) {
    if (name == null) {
      state = state.copyWith(clearFileName: true);
    } else {
      state = state.copyWith(fileName: name);
    }
  }

  void setTextContent(String text) {
    state = state.copyWith(textContent: text);
  }

  /// 开始润色（调用后端 SSE 流式接口）
  Future<void> startPolish() async {
    // 获取输入文本
    final text = state.textContent;
    if (text == null || text.trim().isEmpty) {
      state = state.copyWith(errorMessage: '请输入或上传需要润色的文本');
      return;
    }

    _sseSubscription?.cancel();
    state = state.copyWith(isProcessing: true, clearError: true, clearStreamingText: true);

    try {
      final request = PolishRequest(
        text: text,
        inputMode: state.inputMode,
        level: state.level,
        docType: state.docType,
        fileName: state.fileName,
      );

      final buffer = StringBuffer();
      final stream = _dataSource.submitPolish(request);

      _sseSubscription = stream.listen(
        (event) {
          final json = event.dataAsJson;
          if (json == null) return;

          final type = json['type'] as String?;
          if (type == 'delta') {
            buffer.write(json['text'] as String? ?? '');
            state = state.copyWith(streamingText: buffer.toString());
          } else if (type == 'done') {
            // 用 done 事件中的完整文本覆盖 buffer
            final polishedText = json['text'] as String? ?? buffer.toString();
            state = state.copyWith(
              streamingText: polishedText,
              isProcessing: false,
              stage: PolishStage.result,
              result: _buildResult(polishedText, text),
            );
          } else if (type == 'error') {
            debugPrint('[Polish] Backend error: ${json['message']}');
            state = state.copyWith(
              isProcessing: false,
              errorMessage: json['message'] as String? ?? '润色失败，请重试',
            );
          }
        },
        onError: (e) {
          debugPrint('[Polish] SSE error: $e');
          state = state.copyWith(
            isProcessing: false,
            errorMessage: '润色失败，请检查网络连接',
          );
        },
        onDone: () {
          if (state.isProcessing) {
            // 流结束但未收到 done 事件，使用已收到的内容
            final polished = buffer.toString();
            if (polished.isNotEmpty) {
              state = state.copyWith(
                isProcessing: false,
                stage: PolishStage.result,
                result: _buildResult(polished, text),
              );
            } else {
              state = state.copyWith(
                isProcessing: false,
                errorMessage: '润色失败，未收到结果',
              );
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[Polish] Error: $e');
      state = state.copyWith(
        isProcessing: false,
        errorMessage: '润色失败，请重试',
      );
    }
  }

  /// 根据润色后文本构建 PolishResult
  PolishResult _buildResult(String polishedText, String originalText) {
    // 将原文与润色文本做简单对比，生成 diff segments
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

  /// 生成 diff 段落列表（按行对比）
  List<PolishParagraph> _generateDiffParagraphs(String original, String polished) {
    final originalLines = original.split(RegExp(r'\n')).where((l) => l.trim().isNotEmpty).toList();
    final polishedLines = polished.split(RegExp(r'\n')).where((l) => l.trim().isNotEmpty).toList();

    final paragraphs = <PolishParagraph>[];
    final maxLen = originalLines.length > polishedLines.length
        ? originalLines.length
        : polishedLines.length;

    for (var i = 0; i < maxLen; i++) {
      final segments = <DiffSegment>[];

      if (i < originalLines.length && i < polishedLines.length) {
        final origLine = originalLines[i].trim();
        final polLine = polishedLines[i].trim();

        if (origLine == polLine) {
          // 完全相同
          segments.add(DiffSegment(type: 'equal', text: origLine));
        } else {
          // 有差异：显示删除原文 + 插入润色
          segments.add(DiffSegment(type: 'delete', text: origLine));
          segments.add(DiffSegment(type: 'insert', text: polLine));
        }
      } else if (i < originalLines.length) {
        // 仅原文有此行（被删除）
        segments.add(DiffSegment(type: 'delete', text: originalLines[i].trim()));
      } else {
        // 仅润色有此行（新增）
        segments.add(DiffSegment(type: 'insert', text: polishedLines[i].trim()));
      }

      if (segments.isNotEmpty) {
        paragraphs.add(PolishParagraph(segments: segments));
      }
    }

    return paragraphs;
  }

  /// 统计变更数量
  int _countChanges(List<PolishParagraph> paragraphs) {
    int count = 0;
    for (final para in paragraphs) {
      for (final seg in para.segments) {
        if (seg.type == 'delete' || seg.type == 'insert') {
          count++;
        }
      }
    }
    return count;
  }

  /// 回到输入阶段
  void goBackToInput() {
    _sseSubscription?.cancel();
    state = state.copyWith(
      stage: PolishStage.input,
      clearResult: true,
      clearStreamingText: true,
    );
  }

  /// 重新润色（保留输入内容）
  void rePolish() {
    _sseSubscription?.cancel();
    state = state.copyWith(
      stage: PolishStage.input,
      clearResult: true,
      clearStreamingText: true,
    );
  }

  /// 导出润色结果
  Future<void> exportResult() async {
    final result = state.result;
    if (result == null) return;

    state = state.copyWith(isProcessing: true);
    try {
      await _dataSource.exportResult(
        taskId: result.title, // 使用标题作为标识
        format: state.exportFormat,
      );
      state = state.copyWith(isProcessing: false);
    } catch (e) {
      debugPrint('[Polish] Export error: $e');
      state = state.copyWith(
        isProcessing: false,
        errorMessage: '导出失败，请重试',
      );
    }
  }
}

// ── Providers ──

final polishDataSourceProvider = Provider<PolishRemoteDataSource>((ref) {
  return PolishRemoteDataSource();
});

final polishProvider =
    StateNotifierProvider<PolishNotifier, PolishState>((ref) {
  return PolishNotifier(
    dataSource: ref.read(polishDataSourceProvider),
  );
});
