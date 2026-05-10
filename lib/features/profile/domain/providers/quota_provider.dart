import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/quota_data_source.dart';

class QuotaState {
  final QuotaUsage? data;
  final bool isLoading;
  final String? error;

  const QuotaState({
    this.data,
    this.isLoading = false,
    this.error,
  });

  QuotaState copyWith({
    QuotaUsage? data,
    bool? isLoading,
    String? error,
  }) {
    return QuotaState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class QuotaNotifier extends StateNotifier<QuotaState> {
  final QuotaDataSource _dataSource;

  QuotaNotifier(this._dataSource) : super(const QuotaState()) {
    loadQuota();
  }

  Future<void> loadQuota() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final usage = await _dataSource.getQuotaUsage();
      if (!mounted) return;
      state = state.copyWith(data: usage, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadQuota();
  }
}

final quotaDataSourceProvider = Provider<QuotaDataSource>((ref) {
  return QuotaDataSource();
});

final quotaProvider = StateNotifierProvider<QuotaNotifier, QuotaState>((ref) {
  return QuotaNotifier(ref.read(quotaDataSourceProvider));
});
