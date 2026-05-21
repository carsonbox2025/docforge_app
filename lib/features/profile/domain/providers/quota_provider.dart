import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/quota_data_source.dart';
import '../../../payment/data/models/payment_models.dart';

class QuotaState {
  final QuotaInfo? data;
  final bool isLoading;
  final String? error;

  const QuotaState({
    this.data,
    this.isLoading = false,
    this.error,
  });

  QuotaState copyWith({
    QuotaInfo? data,
    bool? isLoading,
    String? error,
  }) {
    return QuotaState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isPro => data?.isPro ?? false;
}

class QuotaNotifier extends StateNotifier<QuotaState> {
  final QuotaDataSource _dataSource;

  QuotaNotifier(this._dataSource) : super(const QuotaState()) {
    loadQuota();
  }

  Future<void> loadQuota() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final quota = await _dataSource.getQuota();
      if (!mounted) return;
      state = state.copyWith(data: quota, isLoading: false);
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
