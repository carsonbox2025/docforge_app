import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/glossary_data_source.dart';
import '../../data/models/glossary_models.dart';

class GlossaryState {
  final String? selectedLanguagePair;
  final List<GlossaryEntry> entries;
  final bool isLoading;

  const GlossaryState({
    this.selectedLanguagePair,
    this.entries = const [],
    this.isLoading = false,
  });

  List<GlossaryEntry> get filteredEntries {
    if (selectedLanguagePair == null || selectedLanguagePair == '全部') {
      return entries;
    }
    return entries.where((e) => e.languagePairLabel == selectedLanguagePair).toList();
  }

  GlossaryState copyWith({
    String? selectedLanguagePair,
    List<GlossaryEntry>? entries,
    bool? isLoading,
    bool clearLanguagePair = false,
  }) {
    return GlossaryState(
      selectedLanguagePair: clearLanguagePair ? null : (selectedLanguagePair ?? this.selectedLanguagePair),
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class GlossaryNotifier extends StateNotifier<GlossaryState> {
  final GlossaryDataSource _dataSource;

  GlossaryNotifier(this._dataSource) : super(const GlossaryState()) {
    loadEntries();
  }

  void setLanguagePair(String? pair) {
    state = state.copyWith(selectedLanguagePair: pair);
  }

  Future<void> loadEntries() async {
    state = state.copyWith(isLoading: true);
    final entries = await _dataSource.getGlossaryList();
    if (!mounted) return;
    state = state.copyWith(entries: entries, isLoading: false);
  }

  Future<void> addEntry(GlossaryEntry entry) async {
    final newEntry = await _dataSource.addEntry(entry);
    if (newEntry != null && mounted) {
      state = state.copyWith(entries: [...state.entries, newEntry]);
    }
  }

  Future<void> updateEntry(GlossaryEntry entry) async {
    await _dataSource.updateEntry(entry);
    if (mounted) {
      state = state.copyWith(
        entries: state.entries.map((e) => e.id == entry.id ? entry : e).toList(),
      );
    }
  }

  Future<void> deleteEntry(int id) async {
    final success = await _dataSource.deleteEntry(id);
    if (success && mounted) {
      state = state.copyWith(
        entries: state.entries.where((e) => e.id != id).toList(),
      );
    }
  }
}

final glossaryDataSourceProvider = Provider<GlossaryDataSource>((ref) {
  return GlossaryDataSource();
});

final glossaryProvider =
    StateNotifierProvider<GlossaryNotifier, GlossaryState>((ref) {
  return GlossaryNotifier(ref.read(glossaryDataSourceProvider));
});
