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
    PolishResult? result,
    String? errorMessage,
    bool clearResult = false,
    bool clearError = false,
    bool clearFileName = false,
    bool clearTextContent = false,
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
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PolishNotifier extends StateNotifier<PolishState> {
  final PolishRemoteDataSource _dataSource;

  PolishNotifier({required PolishRemoteDataSource dataSource})
      : _dataSource = dataSource,
        super(const PolishState());

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

  /// 开始润色（使用 mock 数据进行演示）
  Future<void> startPolish() async {
    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      // 模拟网络延迟
      await Future.delayed(const Duration(seconds: 2));

      // 从 DataSource 获取 mock 结果
      final result = _dataSource.getMockPolishResult(state.level);

      state = state.copyWith(
        stage: PolishStage.result,
        isProcessing: false,
        result: result,
      );
    } catch (e) {
      debugPrint('[Polish] Error: $e');
      state = state.copyWith(
        isProcessing: false,
        errorMessage: '润色失败，请重试',
      );
    }
  }

  /// 回到输入阶段
  void goBackToInput() {
    state = state.copyWith(
      stage: PolishStage.input,
      clearResult: true,
    );
  }

  /// 重新润色（保留输入内容）
  void rePolish() {
    state = state.copyWith(
      stage: PolishStage.input,
      clearResult: true,
    );
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
