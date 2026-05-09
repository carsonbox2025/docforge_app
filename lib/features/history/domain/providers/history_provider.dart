import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/history_data_source.dart';
import '../../data/models/history_models.dart';

class HistoryState {
  final HistoryFilter activeFilter;
  final List<HistoryDocument> documents;
  final bool isLoading;

  const HistoryState({
    this.activeFilter = HistoryFilter.all,
    this.documents = const [],
    this.isLoading = false,
  });

  List<HistoryDocument> get filteredDocuments {
    if (activeFilter == HistoryFilter.all) return documents;
    return documents.where((d) {
      switch (activeFilter) {
        case HistoryFilter.all:
          return true;
        case HistoryFilter.generated:
          return d.docType == HistoryDocType.generated;
        case HistoryFilter.polished:
          return d.docType == HistoryDocType.polished;
        case HistoryFilter.translated:
          return d.docType == HistoryDocType.translated;
      }
    }).toList();
  }

  HistoryState copyWith({
    HistoryFilter? activeFilter,
    List<HistoryDocument>? documents,
    bool? isLoading,
  }) {
    return HistoryState(
      activeFilter: activeFilter ?? this.activeFilter,
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  final HistoryDataSource _dataSource;

  HistoryNotifier(this._dataSource) : super(const HistoryState()) {
    loadDocuments();
  }

  void setFilter(HistoryFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<void> loadDocuments() async {
    state = state.copyWith(isLoading: true);
    final docs = await _dataSource.getHistoryList();
    if (!mounted) return;
    state = state.copyWith(documents: docs, isLoading: false);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    final docs = await _dataSource.getHistoryList();
    if (!mounted) return;
    state = state.copyWith(documents: docs, isLoading: false);
  }

  Future<bool> deleteDocument(int id) async {
    final success = await _dataSource.deleteDocument(id);
    if (success && mounted) {
      state = state.copyWith(
        documents: state.documents.where((d) => d.id != id).toList(),
      );
    }
    return success;
  }
}

final historyDataSourceProvider = Provider<HistoryDataSource>((ref) {
  return HistoryDataSource();
});

final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier(ref.read(historyDataSourceProvider));
});
