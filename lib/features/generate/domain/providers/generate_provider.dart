import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/generate_data_source.dart';
import '../../data/models/generate_models.dart';

final generateProvider =
    StateNotifierProvider<GenerateNotifier, GenerateState>((ref) {
  return GenerateNotifier(GenerateDataSource());
});

class GenerateNotifier extends StateNotifier<GenerateState> {
  final GenerateDataSource _dataSource;
  CancelToken? _cancelToken;

  GenerateNotifier(this._dataSource) : super(const GenerateState());

  /// 选择文档类型
  void selectDocType(DocType type) {
    state = state.copyWith(selectedType: type);
  }

  /// 选择语言
  void selectLanguage(DocLanguage lang) {
    state = state.copyWith(selectedLanguage: lang);
  }

  /// 更新输入内容
  void updateContent(String content) {
    state = state.copyWith(content: content);
  }

  /// 选择导出格式
  void selectExportFormat(ExportFormat fmt) {
    state = state.copyWith(selectedFormat: fmt);
  }

  /// 开始生成
  Future<void> startGenerate({bool outlineOnly = false}) async {
    if (state.content.trim().isEmpty) return;

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    state = state.copyWith(
      stage: GenerateStage.generating,
      generatedContent: '',
      progress: 0,
      outlineOnly: outlineOnly,
      clearResult: true,
      clearError: true,
    );

    final request = GenerateRequest(
      docType: state.selectedType,
      content: state.content,
      language: state.selectedLanguage,
      outlineOnly: outlineOnly,
    );

    try {
      final stream = _dataSource.generateStream(request, cancelToken: _cancelToken);

      await for (final event in stream) {
        if (!mounted) return;
        _handleEvent(event);
      }

      if (!mounted) return;
      // 流结束，进入审校阶段
      _buildResultFromDataSource();
      state = state.copyWith(
        stage: GenerateStage.review,
        progress: 1.0,
      );
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      debugPrint('[Generate] Error: $e');
      // 开发模式使用模拟数据
      _simulateGeneration();
    }
  }

  void _handleEvent(GenerateEvent event) {
    final data = event.dataAsJson;
    if (data == null) return;

    switch (event.event) {
      case 'progress':
        final pct = (data['progress'] as num?)?.toDouble() ?? 0.0;
        state = state.copyWith(progress: pct.clamp(0.0, 1.0));
        break;
      case 'content':
        final text = data['text'] as String? ?? '';
        state = state.copyWith(generatedContent: state.generatedContent + text);
        break;
      case 'chapter':
        final title = data['title'] as String? ?? '';
        final order = data['order'] as int? ?? state.chapters.length;
        state = state.copyWith(
          chapters: [...state.chapters, ChapterMeta(title: title, order: order)],
        );
        break;
      case 'title':
        state = state.copyWith(docTitle: data['title'] as String? ?? '');
        break;
    }
  }

  /// 模拟生成过程（开发/演示用）
  void _simulateGeneration() async {
    state = state.copyWith(
      stage: GenerateStage.generating,
      generatedContent: '',
      progress: 0,
      docTitle: '租房协议',
    );

    final sections = GenerateDataSource.mockSections;

    int i = 0;
    for (final section in sections) {
      if (!mounted) return;
      final heading = section['heading']!;
      final body = section['body']!;

      // 写入标题
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      state = state.copyWith(
        generatedContent: state.generatedContent + '\n### $heading\n\n',
        chapters: [...state.chapters, ChapterMeta(title: heading, order: i + 1)],
      );

      // 写入段落
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      state = state.copyWith(
        generatedContent: state.generatedContent + '$body\n\n',
        progress: ((i + 1) / sections.length).clamp(0.0, 0.95),
      );
      i++;
    }

    if (!mounted) return;
    _buildResultFromDataSource();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    state = state.copyWith(
      stage: GenerateStage.review,
      progress: 1.0,
    );
  }

  void _buildResultFromDataSource() {
    state = state.copyWith(
      result: _dataSource.buildMockResult(
        docTitle: state.docTitle,
        chapters: state.chapters,
        generatedContent: state.generatedContent,
      ),
    );
  }

  /// 返回输入页
  void backToInput() {
    _cancelToken?.cancel();
    state = state.copyWith(stage: GenerateStage.input);
  }

  /// 返回生成页
  void backToGenerating() {
    state = state.copyWith(stage: GenerateStage.generating);
  }

  /// 导出
  Future<void> exportDocument() async {
    if (state.result == null) return;
    try {
      await _dataSource.exportDocument(
        'current',
        state.selectedFormat,
      );
    } catch (e) {
      debugPrint('[Generate] Export error: $e');
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

  // 生成中状态
  final String docTitle;
  final String generatedContent;
  final double progress;
  final List<ChapterMeta> chapters;

  // 结果
  final GenerateResult? result;
  final String? error;

  const GenerateState({
    this.stage = GenerateStage.input,
    this.selectedType = DocType.contract,
    this.selectedLanguage = DocLanguage.zhCN,
    this.content = '',
    this.selectedFormat = ExportFormat.docx,
    this.outlineOnly = false,
    this.docTitle = '',
    this.generatedContent = '',
    this.progress = 0,
    this.chapters = const [],
    this.result,
    this.error,
  });

  GenerateState copyWith({
    GenerateStage? stage,
    DocType? selectedType,
    DocLanguage? selectedLanguage,
    String? content,
    ExportFormat? selectedFormat,
    bool? outlineOnly,
    String? docTitle,
    String? generatedContent,
    double? progress,
    List<ChapterMeta>? chapters,
    GenerateResult? result,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) =>
      GenerateState(
        stage: stage ?? this.stage,
        selectedType: selectedType ?? this.selectedType,
        selectedLanguage: selectedLanguage ?? this.selectedLanguage,
        content: content ?? this.content,
        selectedFormat: selectedFormat ?? this.selectedFormat,
        outlineOnly: outlineOnly ?? this.outlineOnly,
        docTitle: docTitle ?? this.docTitle,
        generatedContent: generatedContent ?? this.generatedContent,
        progress: progress ?? this.progress,
        chapters: chapters ?? this.chapters,
        result: clearResult ? null : (result ?? this.result),
        error: clearError ? null : (error ?? this.error),
      );
}
