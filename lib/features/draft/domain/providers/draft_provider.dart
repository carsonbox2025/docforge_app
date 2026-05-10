import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/draft_local_data_source.dart';
import '../../data/models/draft_model.dart';

class DraftState {
  final List<Draft> drafts;
  final bool isLoading;

  const DraftState({
    this.drafts = const [],
    this.isLoading = false,
  });

  DraftState copyWith({
    List<Draft>? drafts,
    bool? isLoading,
  }) {
    return DraftState(
      drafts: drafts ?? this.drafts,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DraftNotifier extends StateNotifier<DraftState> {
  final DraftLocalDataSource _dataSource;

  DraftNotifier(this._dataSource) : super(const DraftState()) {
    loadDrafts();
  }

  Future<void> loadDrafts() async {
    state = state.copyWith(isLoading: true);
    final drafts = await _dataSource.getAllDrafts();
    if (!mounted) return;
    state = state.copyWith(drafts: drafts, isLoading: false);
  }

  Future<Draft> createDraft({
    required String title,
    String content = '',
    String docType = 'default',
  }) async {
    final draft = await _dataSource.createDraft(
      title: title,
      content: content,
      docType: docType,
    );
    if (mounted) {
      state = state.copyWith(drafts: [draft, ...state.drafts]);
    }
    return draft;
  }

  Future<Draft> saveDraft(Draft draft) async {
    final saved = await _dataSource.saveDraft(draft);
    if (mounted) {
      final updated = state.drafts.map((d) => d.id == saved.id ? saved : d).toList();
      // 如果是新草稿（不在列表中），插入到头部
      if (!state.drafts.any((d) => d.id == saved.id)) {
        updated.insert(0, saved);
      }
      // 按 updatedAt 降序重排
      updated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = state.copyWith(drafts: updated);
    }
    return saved;
  }

  Future<bool> deleteDraft(String id) async {
    final ok = await _dataSource.deleteDraft(id);
    if (ok && mounted) {
      state = state.copyWith(
        drafts: state.drafts.where((d) => d.id != id).toList(),
      );
    }
    return ok;
  }
}

// --- Providers ---

final draftDataSourceProvider = Provider<DraftLocalDataSource>((ref) {
  return DraftLocalDataSource();
});

final draftProvider =
    StateNotifierProvider<DraftNotifier, DraftState>((ref) {
  return DraftNotifier(ref.read(draftDataSourceProvider));
});
