import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_interceptor.dart';
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

  final List<DslNode> translatedNodes;
  final int? taskId;

  // 翻译参数
  final String docType;
  final String industry;
  final String customRequirements;

  // 多阶段进度
  final double progress;
  final String progressMessage;
  final List<ExtractedTerm> extractedTerms;
  final List<ParagraphProgress> paragraphProgress;
  final String? detectedDocType;

  // 双语对照
  final List<BilingualParagraph> bilingualParagraphs;
  final int autoSavedTermCount;

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
    this.docType = 'generic',
    this.industry = 'general',
    this.customRequirements = '',
    this.progress = 0,
    this.progressMessage = '',
    this.extractedTerms = const [],
    this.paragraphProgress = const [],
    this.detectedDocType,
    this.bilingualParagraphs = const [],
    this.autoSavedTermCount = 0,
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
    String? docType,
    String? industry,
    String? customRequirements,
    double? progress,
    String? progressMessage,
    List<ExtractedTerm>? extractedTerms,
    List<ParagraphProgress>? paragraphProgress,
    String? detectedDocType,
    List<BilingualParagraph>? bilingualParagraphs,
    int? autoSavedTermCount,
    bool clearError = false,
    bool clearDocument = false,
    bool clearDetectedDocType = false,
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
      docType: docType ?? this.docType,
      industry: industry ?? this.industry,
      customRequirements: customRequirements ?? this.customRequirements,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
      extractedTerms: extractedTerms ?? this.extractedTerms,
      paragraphProgress: paragraphProgress ?? this.paragraphProgress,
      detectedDocType: clearDetectedDocType ? null : (detectedDocType ?? this.detectedDocType),
      bilingualParagraphs: bilingualParagraphs ?? this.bilingualParagraphs,
      autoSavedTermCount: autoSavedTermCount ?? this.autoSavedTermCount,
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
  void setDocType(String docType) => state = state.copyWith(docType: docType);
  void setIndustry(String industry) => state = state.copyWith(industry: industry);
  void setCustomRequirements(String req) => state = state.copyWith(customRequirements: req);

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
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      translatedText: '',
      stage: TranslateStage.translating,
      progress: 0,
      progressMessage: '正在上传文件...',
    );

    try {
      // 1. 上传文件到服务器，获取服务器端 file_path
      final serverResult = await _dataSource.uploadFile(state.documentFilePath!);
      final serverFilePath = serverResult['file_path'] as String?;
      if (serverFilePath == null || serverFilePath.isEmpty) {
        throw Exception('服务器未返回文件路径');
      }

      state = state.copyWith(progressMessage: '正在提交翻译任务...');

      // 2. 提交翻译任务（file_path 传给后端，后端自行解析文件内容）
      final fileName = state.documentFileName ?? '未命名';
      final taskId = await _dataSource.submitTranslateDocumentTask(
        serverFilePath: serverFilePath,
        fileName: fileName,
        sourceLang: state.sourceLang,
        targetLang: state.targetLang,
        docType: state.docType,
        industry: state.industry,
        customRequirements: state.customRequirements,
      );
      state = state.copyWith(taskId: taskId);

      _listenProgress(taskId);
    } on DioException catch (e) {
      final isQuotaExceeded = e.error is QuotaExceededException;
      debugPrint('[Translate] Document error: $e (quota=$isQuotaExceeded)');
      state = state.copyWith(
        isLoading: false,
        stage: TranslateStage.input,
        errorMessage: isQuotaExceeded ? 'QUOTA_EXCEEDED' : '文档翻译失败：${e.message}',
      );
    } catch (e) {
      debugPrint('[Translate] Document error: $e');
      state = state.copyWith(isLoading: false, stage: TranslateStage.input, errorMessage: '文档翻译失败：$e');
    }
  }

  Future<void> _translateText() async {
    if (state.inputText.trim().isEmpty) return;
    _progressSub?.cancel();
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      translatedText: '',
      stage: TranslateStage.translating,
      progress: 0,
      progressMessage: '正在提交...',
    );

    try {
      final request = TranslateRequest(
        text: state.inputText,
        sourceLang: state.sourceLang,
        targetLang: state.targetLang,
        glossary: state.glossary,
        docType: state.docType,
        industry: state.industry,
        customRequirements: state.customRequirements,
      );

      final taskId = await _dataSource.submitTranslateTask(request);
      state = state.copyWith(taskId: taskId);

      _listenProgress(taskId);
    } on DioException catch (e) {
      final isQuotaExceeded = e.error is QuotaExceededException;
      debugPrint('[Translate] submit error: $e (quota=$isQuotaExceeded)');
      state = state.copyWith(
        isLoading: false,
        stage: TranslateStage.input,
        errorMessage: isQuotaExceeded ? 'QUOTA_EXCEEDED' : '翻译提交失败：${e.message}',
      );
    } catch (e) {
      debugPrint('[Translate] submit error: $e');
      state = state.copyWith(isLoading: false, stage: TranslateStage.input, errorMessage: '翻译提交失败');
    }
  }

  void _listenProgress(int taskId) {
    _progressSub?.cancel();
    final stream = _dataSource.translateProgressStream(taskId);
    _progressSub = stream.listen(
      (update) {
        if (!mounted) return;

        state = state.copyWith(
          progress: update.progress,
          progressMessage: update.message,
        );

        final detail = update.detail;
        if (detail != null) {
          _handleProgressDetail(detail);
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

  void _handleProgressDetail(Map<String, dynamic> detail) {
    // 文档分析事件
    final docAnalyzed = detail['doc_analyzed'] as Map<String, dynamic>?;
    if (docAnalyzed != null) {
      state = state.copyWith(
        detectedDocType: docAnalyzed['doc_type'] as String?,
      );
    }

    // 术语提取事件
    final termsExtracted = detail['terms_extracted'] as Map<String, dynamic>?;
    if (termsExtracted != null) {
      final rawTerms = (termsExtracted['terms'] as List<dynamic>?)
              ?.map((e) => ExtractedTerm.fromJson(e as Map<String, dynamic>))
              .toList() ?? [];
      state = state.copyWith(extractedTerms: rawTerms);
    }

    // 段落开始事件
    final paragraphStart = detail['paragraph_start'] as Map<String, dynamic>?;
    if (paragraphStart != null) {
      final index = paragraphStart['index'] as int? ?? 0;
      final total = paragraphStart['total'] as int? ?? 1;
      final preview = paragraphStart['preview'] as String? ?? '';
      final fullSource = paragraphStart['full_source'] as String? ?? '';
      final updated = [...state.paragraphProgress];
      while (updated.length <= index) {
        updated.add(ParagraphProgress(
          index: updated.length,
          total: total,
        ));
      }
      updated[index] = ParagraphProgress(
        index: index,
        total: total,
        preview: preview,
        fullSource: fullSource,
      );
      state = state.copyWith(paragraphProgress: updated);
    }

    // 段落 delta 事件（流式译文）
    final paragraphDelta = detail['paragraph_delta'] as Map<String, dynamic>?;
    if (paragraphDelta != null) {
      final index = paragraphDelta['index'] as int? ?? 0;
      final text = paragraphDelta['text'] as String? ?? '';
      final updated = [...state.paragraphProgress];
      if (index < updated.length) {
        updated[index] = updated[index].copyWith(translated: text);
        state = state.copyWith(paragraphProgress: updated);
      }
    }

    // 段落完成事件
    final paragraphDone = detail['paragraph_done'] as Map<String, dynamic>?;
    if (paragraphDone != null) {
      final index = paragraphDone['index'] as int? ?? 0;
      final updated = [...state.paragraphProgress];
      if (index < updated.length) {
        updated[index] = updated[index].copyWith(isComplete: true);
        state = state.copyWith(paragraphProgress: updated);
      }
    }

    // DSL 更新
    final dslUpdate = detail['dsl_update'] as Map<String, dynamic>?;
    if (dslUpdate != null) {
      _handleDslUpdate(detail);
    }
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
        String translated = state.translatedText;

        final dslContent = status.resultData;
        if (dslContent != null) {
          final extracted = _extractTextFromDsl(dslContent);
          if (extracted.isNotEmpty) {
            translated = extracted;
          }
        }

        // 构建双语对照：优先从 DSL metadata 获取完整原文
        List<BilingualParagraph> bilingual = [];
        final metadata = dslContent?['metadata'] as Map<String, dynamic>?;
        final translateData = metadata?['translate_data'] as Map<String, dynamic>?;
        if (translateData != null) {
          final sourceParas = (translateData['source_paragraphs'] as List<dynamic>?)
                  ?.cast<String>() ?? [];
          final translatedParas = (translateData['translated_paragraphs'] as List<dynamic>?)
                  ?.cast<String>() ?? [];
          if (sourceParas.isNotEmpty) {
            bilingual = buildBilingualParagraphs(sourceParas, translatedParas, state.extractedTerms);
          }
        }
        if (bilingual.isEmpty && state.paragraphProgress.isNotEmpty) {
          final sources = state.paragraphProgress.map((p) => p.fullSource.isNotEmpty ? p.fullSource : p.preview).toList();
          final translateds = state.paragraphProgress.map((p) => p.translated).toList();
          bilingual = buildBilingualParagraphs(sources, translateds, state.extractedTerms);
        }

        state = state.copyWith(
          translatedText: translated,
          isLoading: false,
          stage: TranslateStage.result,
          previewResults: [TranslateResult(translatedText: translated)],
          bilingualParagraphs: bilingual,
          progress: 1.0,
          progressMessage: '翻译完成',
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
          progress: 1.0,
          progressMessage: '翻译完成',
        );
      } else {
        state = state.copyWith(isLoading: false, errorMessage: '翻译失败');
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

  Future<void> export() async {
    final taskId = state.taskId;
    if (taskId == null) {
      state = state.copyWith(errorMessage: '无文档ID，无法导出');
      return;
    }
    state = state.copyWith(isLoading: true);
    try {
      final bytes = await _dataSource.exportDocument(taskId);
      await FileExporter.saveAndShare(
        bytes: Uint8List.fromList(bytes),
        fileName: 'translated.docx',
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('[Translate] Export error: $e');
      state = state.copyWith(isLoading: false, errorMessage: '导出失败');
    }
  }

  Future<void> cancel() async {
    _progressSub?.cancel();
    final taskId = state.taskId;
    if (taskId != null) {
      try {
        await _dataSource.cancelTask(taskId);
      } catch (e) {
        debugPrint('[Translate] cancel task error: $e');
      }
    }
    state = state.copyWith(
      stage: TranslateStage.input,
      isLoading: false,
      progress: 0,
      progressMessage: '',
    );
  }

  void reset() {
    _progressSub?.cancel();
    state = const TranslateState();
  }
}
