import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/template_data_source.dart';
import '../../data/models/template_models.dart';

class TemplateGalleryState {
  final TemplateCategory activeCategory;
  final List<Template> templates;
  final bool isLoading;
  final String? error;

  const TemplateGalleryState({
    this.activeCategory = TemplateCategory.all,
    this.templates = const [],
    this.isLoading = false,
    this.error,
  });

  List<Template> get filteredTemplates {
    if (activeCategory == TemplateCategory.all) return templates;
    return templates.where((t) => t.category == activeCategory).toList();
  }

  TemplateGalleryState copyWith({
    TemplateCategory? activeCategory,
    List<Template>? templates,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TemplateGalleryState(
      activeCategory: activeCategory ?? this.activeCategory,
      templates: templates ?? this.templates,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TemplateGalleryNotifier extends StateNotifier<TemplateGalleryState> {
  final TemplateDataSource _dataSource;

  TemplateGalleryNotifier(this._dataSource) : super(const TemplateGalleryState()) {
    loadTemplates();
  }

  void setCategory(TemplateCategory category) {
    state = state.copyWith(activeCategory: category);
  }

  Future<void> loadTemplates() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final templates = await _dataSource.getTemplates();
      if (!mounted) return;
      state = state.copyWith(templates: templates, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final templates = await _dataSource.getTemplates();
      if (!mounted) return;
      state = state.copyWith(templates: templates, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> reload() => refresh();
}

final templateDataSourceProvider = Provider<TemplateDataSource>((ref) {
  return TemplateDataSource();
});

final templateProvider =
    StateNotifierProvider<TemplateGalleryNotifier, TemplateGalleryState>((ref) {
  return TemplateGalleryNotifier(ref.read(templateDataSourceProvider));
});
