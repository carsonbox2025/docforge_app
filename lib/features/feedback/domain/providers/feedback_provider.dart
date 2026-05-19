import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/feedback_data_source.dart';
import '../../data/models/feedback_models.dart';

class FeedbackState {
  final bool isSubmitting;
  final String? submitError;
  final bool submitSuccess;
  final List<FeedbackRecord> history;
  final bool isLoadingHistory;

  const FeedbackState({
    this.isSubmitting = false,
    this.submitError,
    this.submitSuccess = false,
    this.history = const [],
    this.isLoadingHistory = false,
  });

  FeedbackState copyWith({
    bool? isSubmitting,
    String? submitError,
    bool? submitSuccess,
    List<FeedbackRecord>? history,
    bool? isLoadingHistory,
  }) {
    return FeedbackState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: submitError,
      submitSuccess: submitSuccess ?? this.submitSuccess,
      history: history ?? this.history,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
    );
  }
}

class FeedbackNotifier extends StateNotifier<FeedbackState> {
  final FeedbackDataSource _dataSource;

  FeedbackNotifier(this._dataSource) : super(const FeedbackState());

  Future<void> submit({
    required FeedbackType type,
    required String content,
    String? contact,
  }) async {
    state = state.copyWith(
        isSubmitting: true, submitError: null, submitSuccess: false);
    try {
      await _dataSource.submit(
        type: type.name,
        content: content,
        contact: contact,
      );
      state = state.copyWith(isSubmitting: false, submitSuccess: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, submitError: e.toString());
    }
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoadingHistory: true);
    try {
      final records = await _dataSource.getMyFeedbacks();
      if (!mounted) return;
      state = state.copyWith(history: records, isLoadingHistory: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  void resetSubmit() {
    state = state.copyWith(submitSuccess: false, submitError: null);
  }
}

final feedbackProvider =
    StateNotifierProvider<FeedbackNotifier, FeedbackState>((ref) {
  return FeedbackNotifier(FeedbackDataSource());
});
