import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/translate_data_source.dart';
import '../../data/models/translate_models.dart';

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
  final List<GlossaryTerm> glossary;
  final List<TranslateResult> previewResults;
  final ExportFormat selectedFormat;
  final bool isLoading;
  final String? errorMessage;

  const TranslateState({
    this.stage = TranslateStage.input,
    this.mode = TranslateMode.text,
    this.sourceLang = Language.zhCN,
    this.targetLang = Language.enUS,
    this.inputText = '',
    this.translatedText = '',
    this.glossary = const [],
    this.previewResults = const [],
    this.selectedFormat = ExportFormat.docx,
    this.isLoading = false,
    this.errorMessage,
  });

  TranslateState copyWith({
    TranslateStage? stage,
    TranslateMode? mode,
    Language? sourceLang,
    Language? targetLang,
    String? inputText,
    String? translatedText,
    List<GlossaryTerm>? glossary,
    List<TranslateResult>? previewResults,
    ExportFormat? selectedFormat,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TranslateState(
      stage: stage ?? this.stage,
      mode: mode ?? this.mode,
      sourceLang: sourceLang ?? this.sourceLang,
      targetLang: targetLang ?? this.targetLang,
      inputText: inputText ?? this.inputText,
      translatedText: translatedText ?? this.translatedText,
      glossary: glossary ?? this.glossary,
      previewResults: previewResults ?? this.previewResults,
      selectedFormat: selectedFormat ?? this.selectedFormat,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TranslateNotifier extends StateNotifier<TranslateState> {
  final TranslateDataSource _dataSource;
  StreamSubscription? _sseSubscription;

  TranslateNotifier(this._dataSource) : super(const TranslateState());

  @override
  void dispose() {
    _sseSubscription?.cancel();
    super.dispose();
  }

  void setMode(TranslateMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setSourceLang(Language lang) {
    state = state.copyWith(sourceLang: lang);
  }

  void setTargetLang(Language lang) {
    state = state.copyWith(targetLang: lang);
  }

  void swapLanguages() {
    state = state.copyWith(
      sourceLang: state.targetLang,
      targetLang: state.sourceLang,
    );
  }

  void setInputText(String text) {
    state = state.copyWith(inputText: text);
  }

  void setExportFormat(ExportFormat format) {
    state = state.copyWith(selectedFormat: format);
  }

  void goToStage(TranslateStage stage) {
    state = state.copyWith(stage: stage);
  }

  void updateGlossary(List<GlossaryTerm> glossary) {
    state = state.copyWith(glossary: glossary);
  }

  Future<void> translate() async {
    if (state.inputText.trim().isEmpty) return;

    _sseSubscription?.cancel();
    state = state.copyWith(isLoading: true, clearError: true, translatedText: '');

    try {
      final request = TranslateRequest(
        text: state.inputText,
        sourceLang: state.sourceLang,
        targetLang: state.targetLang,
        glossary: state.glossary,
      );

      final buffer = StringBuffer();
      final stream = _dataSource.translateTextStream(request);

      _sseSubscription = stream.listen(
        (event) {
          final json = event.dataAsJson;
          if (json == null) return;

          final type = json['type'] as String?;
          if (type == 'delta') {
            buffer.write(json['text'] as String? ?? '');
            state = state.copyWith(translatedText: buffer.toString());
          } else if (type == 'done') {
            final translated = buffer.toString();
            state = state.copyWith(
              translatedText: translated,
              isLoading: false,
              stage: TranslateStage.result,
              previewResults: [
                TranslateResult(translatedText: translated),
              ],
            );
          }
        },
        onError: (e) {
          debugPrint('[Translate] SSE error: $e');
          state = state.copyWith(
            isLoading: false,
            errorMessage: '翻译失败，请稍后重试',
          );
        },
        onDone: () {
          if (state.isLoading) {
            // 流结束但未收到 done 事件，仍然用已收到的内容
            final translated = buffer.toString();
            if (translated.isNotEmpty) {
              state = state.copyWith(
                isLoading: false,
                stage: TranslateStage.result,
                previewResults: [
                  TranslateResult(translatedText: translated),
                ],
              );
            } else {
              state = state.copyWith(
                isLoading: false,
                errorMessage: '翻译失败，未收到结果',
              );
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[Translate] Error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '翻译失败，请稍后重试',
      );
    }
  }

  Future<void> export() async {
    state = state.copyWith(isLoading: true);
    try {
      await _dataSource.exportDocument(
        translatedContent: state.translatedText,
        format: state.selectedFormat,
        sourceLang: state.sourceLang.code,
        targetLang: state.targetLang.code,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('[Translate] Export error: $e');
      state = state.copyWith(isLoading: false, errorMessage: '导出失败');
    }
  }

  void reset() {
    _sseSubscription?.cancel();
    state = const TranslateState();
  }
}
