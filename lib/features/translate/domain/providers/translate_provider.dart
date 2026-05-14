import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/translate_data_source.dart';
import '../../data/models/translate_models.dart';
import '../../../generate/data/task_data_source.dart';
import '../../../../shared/models/dsl/dsl_node.dart' show DslNode;
import '../../../../shared/utils/file_export.dart';

final translateProvider =
    StateNotifierProvider<TranslateNotifier, TranslateState>((ref) {
  return TranslateNotifier(TranslateDataSource());
});

class TranslateState {
  final TranslateStage stage;
  final TranslateMode mode;
  final Language sourceLang;
  final Language targetLang;
  final String inputText;
  final String translatedText;
  final String? documentFilePath;
  final String? documentFileName;
  final List<GlossaryTerm> glossary;
  final List<TranslateResult> previewResults;
  final ExportFormat selectedFormat;
  final bool isLoading;
  final String? errorMessage;

  // DSL 状态
  final List<DslNode> translatedNodes;
  final int? taskId;

  // 生成模式
  final String genMode; // quick / professional

  const TranslateState({
    this.stage = TranslateStage.input,
    this.mode = TranslateMode.text,
    this.sourceLang = Language.zhCN,
    this.targetLang = Language.enUS,
    this.inputText = '',
    this.translatedText = '',
    this.documentFilePath,
    this.documentFileName,
    this.glossary = const [],
    this.previewResults = const [],
    this.selectedFormat = ExportFormat.docx,
    this.isLoading = false,
    this.errorMessage,
    this.translatedNodes = const [],
    this.taskId,
    this.genMode = 'quick',
  });

  TranslateState copyWith({
    TranslateStage? stage,
    TranslateMode? mode,
    Language? sourceLang,
    Language? targetLang,
    String? inputText,
    String? translatedText,
    String? documentFilePath,
    String? documentFileName,
    List<GlossaryTerm>? glossary,
    List<TranslateResult>? previewResults,
    ExportFormat? selectedFormat,
    bool? isLoading,
    String? errorMessage,
    List<DslNode>? translatedNodes,
    int? taskId,
    String? genMode,
    bool clearError = false,
    bool clearDocument = false,
  }) {
    return TranslateState(
      stage: stage ?? this.stage,
      mode: mode ?? this.mode,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      inputText: inputText ?? this.inputText,
      translatedText: translatedText ?? this.translatedText,
      documentFilePath: clearDocument ? null : (documentFilePath ?? this.documentFilePath),
      documentFileName: clearDocument ? null : (documentFileName ?? this.documentFileName),
      glossary: glossary ?? this.glossary,
      previewResults: previewResults ?? this.previewResults,
      selectedFormat: selectedFormat ?? this.selectedFormat,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      translatedNodes: translatedNodes ?? this.translatedNodes,
      taskId: taskId ?? this.taskId,
      genMode: genMode ?? this.genMode,
    );
  }
}

class TranslateNotifier extends StateNotifier<TranslateState> {
  final TranslateDataSource _dataSource;
  StreamSubscription? _progressSub;

  TranslateNotifier(this._dataSource) : super(const TranslateState());

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  void setMode(TranslateMode mode) => state = state.copyWith(mode: mode);
  void setSourceLang(Language lang) => state = state.copyWith(sourceLang: lang);
  void setTargetLang(Language lang) => state = state.copyWith(targetLang: lang);
  void swapLanguages() => state = state.copyWith(sourceLang: state.targetLang, targetLang: state.sourceLang);
  void setInputText(String text) => state = state.copyWith(inputText: text);
  void setDocumentFile(String filePath, String fileName) =>
      state = state.copyWith(documentFilePath: filePath, documentFileName: fileName);
  void clearDocumentFile() => state = state.copyWith(clearDocument: true);
  void setExportFormat(ExportFormat format) => state = state.copyWith(selectedFormat: format);
  void goToStage(TranslateStage stage) => state = state.copyWith(stage: stage);
  void updateGlossary(List<GlossaryTerm> glossary) => state = state.copyWith(glossary: glossary);
  void setGenMode(String mode) => state = state.copyWith(genMode: mode);

  Future<void> translate() async {
    if (state.mode == TranslateMode.document) {
      await _translateDocument();
    } else {
      await _translateText();
    }
  }

  Future<void> _translateDocument() async {
    if (state.documentFilePath == null) return;
    _progressSub?.cancel();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _dataSource.translateDocument(
        filePath: state.documentFilePath!,
        sourceLang: state.sourceLang,
        targetLang: state.targetLang,
        glossary: state.glossary,
      );
      final translated = result['translated_text'] as String? ?? '';
      final paragraphs = (result['paragraphs'] as List<dynamic>?)
              ?.map((e) => TranslateResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [TranslateResult(translatedText: translated)];
      state = state.copyWith(
        translatedText: translated,
        previewResults: paragraphs,
        isLoading: false,
        stage: TranslateStage.result,
      );
    } catch (e) {
      debugPrint('[Translate] Document error: $e');
      state = state.copyWith(isLoading: false, errorMessage: '文档翻译失败');
    }
  }

  Future<void> _translateText() async {
    if (state.inputText.trim().isEmpty) return;
    _progressSub?.cancel();
    state = state.copyWith(isLoading: true, clearError: true, translatedText: '');

    try {
      final request = TranslateRequest(
        text: state.inputText,
        sourceLang: state.sourceLang,
        targetLang: state.targetLang,
        glossary: state.glossary,
      );

      final taskId = await _dataSource.submitTranslateTask(request, mode: state.genMode);
      state = state.copyWith(taskId: taskId);

      _listenProgress(taskId);
    } catch (e) {
      debugPrint('[Translate] submit error: $e');
      state = state.copyWith(isLoading: false, errorMessage: '翻译提交失败');
    }
  }

  void _listenProgress(int taskId) {
    _progressSub?.cancel();
    final stream = _dataSource.translateProgressStream(taskId);
    _progressSub = stream.listen(
      (update) {
        if (!mounted) return;

        final detail = update.detail;
        if (detail != null) {
          _handleDslUpdate(detail);
        }
      },
      onDone: () {
        if (!mounted) return;
        _onStreamDone(taskId);
      },
      onError: (e) {
        if (!mounted) return;
        debugPrint('[Translate] progress error: $e');
        state = state.copyWith(isLoading: false, errorMessage: '翻译失败');
      },
    );
  }

  void _handleDslUpdate(Map<String, dynamic> detail) {
    final dslUpdate = detail['dsl_update'] as Map<String, dynamic>?;
    if (dslUpdate == null) return;

    final nodeUpdates = dslUpdate['node_updates'] as List<dynamic>?;
    if (nodeUpdates != null) {
      var allNodes = <DslNode>[...state.translatedNodes];

      for (final update in nodeUpdates) {
        final u = update as Map<String, dynamic>;
        final op = u['op'] as String? ?? 'append';

        if (op == 'replace_all') {
          final rawNodes = u['nodes'] as List<dynamic>? ?? [];
          allNodes = rawNodes.map((n) => DslNode.fromJson(n as Map<String, dynamic>)).toList();
        } else if (op == 'append') {
          final rawNode = u['node'] as Map<String, dynamic>?;
          if (rawNode != null) allNodes.add(DslNode.fromJson(rawNode));
        }
      }

      final texts = allNodes
          .where((n) => n.text != null && n.text!.isNotEmpty)
          .map((n) => n.text!)
          .join('\n\n');

      state = state.copyWith(translatedNodes: allNodes, translatedText: texts);
    }
  }

  Future<void> _onStreamDone(int taskId) async {
    try {
      final status = await _dataSource.getTaskStatus(taskId);
      if (status.status == TaskStatus.completed) {
        final translated = state.translatedText;
        state = state.copyWith(
          translatedText: translated,
          isLoading: false,
          stage: TranslateStage.result,
          previewResults: [TranslateResult(translatedText: translated)],
        );
      } else if (status.status == TaskStatus.failed) {
        state = state.copyWith(isLoading: false, errorMessage: status.errorMsg ?? '翻译失败');
      } else {
        state = state.copyWith(isLoading: false, errorMessage: '翻译超时');
      }
    } catch (e) {
      final translated = state.translatedText;
      if (translated.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          stage: TranslateStage.result,
          previewResults: [TranslateResult(translatedText: translated)],
        );
      } else {
        state = state.copyWith(isLoading: false, errorMessage: '翻译失败');
      }
    }
  }

  Future<void> export() async {
    state = state.copyWith(isLoading: true);
    try {
      final bytes = await _dataSource.exportDocument(
        translatedContent: state.translatedText,
        format: state.selectedFormat,
        sourceLang: state.sourceLang.code,
        targetLang: state.targetLang.code,
      );
      await FileExporter.saveAndShare(
        bytes: Uint8List.fromList(bytes),
        fileName: 'translated.${state.selectedFormat.extension}',
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('[Translate] Export error: $e');
      state = state.copyWith(isLoading: false, errorMessage: '导出失败');
    }
  }

  void reset() {
    _progressSub?.cancel();
    state = const TranslateState();
  }
}
