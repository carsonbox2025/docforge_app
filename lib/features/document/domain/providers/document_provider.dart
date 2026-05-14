import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/document_data_source.dart';
import '../../data/models/document_models.dart';

final _ds = DocumentDataSource();

// ─── 文档列表 ───

class DocumentListState {
  final List<DocForgeDocument> items;
  final int total;
  final bool isLoading;
  final String? error;
  final DocCenterTab tab;
  final int currentPage;
  final bool hasMore;
  final int? runningTotal;
  final int? pendingTotal;

  const DocumentListState({
    this.items = const [],
    this.total = 0,
    this.isLoading = false,
    this.error,
    this.tab = DocCenterTab.all,
    this.currentPage = 1,
    this.hasMore = true,
    this.runningTotal,
    this.pendingTotal,
  });

  int get effectiveTotal {
    if (tab == DocCenterTab.running) {
      return (runningTotal ?? 0) + (pendingTotal ?? 0);
    }
    return total;
  }

  DocumentListState copyWith({
    List<DocForgeDocument>? items,
    int? total,
    bool? isLoading,
    String? error,
    DocCenterTab? tab,
    int? currentPage,
    bool? hasMore,
    int? runningTotal,
    int? pendingTotal,
    bool clearError = false,
  }) =>
      DocumentListState(
        items: items ?? this.items,
        total: total ?? this.total,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        tab: tab ?? this.tab,
        currentPage: currentPage ?? this.currentPage,
        hasMore: hasMore ?? this.hasMore,
        runningTotal: runningTotal ?? this.runningTotal,
        pendingTotal: pendingTotal ?? this.pendingTotal,
      );
}

class DocumentListNotifier extends StateNotifier<DocumentListState> {
  DocumentListNotifier() : super(const DocumentListState());

  DocStatus? _statusForTab() {
    if (state.tab == DocCenterTab.running) return DocStatus.running;
    if (state.tab == DocCenterTab.completed) return DocStatus.completed;
    return null;
  }

  /// 加载 pending 文档并合并排序（running Tab 专用）
  Future<({List<DocForgeDocument> docs, int? pendingTotal})> _loadPendingDocs(int page) async {
    try {
      final pendingResult = await _ds.listDocuments(status: DocStatus.pending, page: page);
      final pendingRaw = pendingResult['items'] as List<dynamic>? ?? [];
      final pendingDocs = pendingRaw
          .map((e) => DocForgeDocument.fromJson(e as Map<String, dynamic>))
          .toList();
      return (
        docs: pendingDocs,
        pendingTotal: pendingResult['total'] as int?,
      );
    } catch (e) {
      debugPrint('[DocumentList] load pending error: $e');
      return (docs: <DocForgeDocument>[], pendingTotal: null as int?);
    }
  }

  Future<void> load({DocCenterTab? tab, int page = 1}) async {
    state = state.copyWith(isLoading: true, clearError: true, tab: tab ?? state.tab);
    try {
      final status = _statusForTab();
      final result = await _ds.listDocuments(status: status, page: page);
      final rawItems = result['items'] as List<dynamic>? ?? [];
      final docs = rawItems
          .map((e) => DocForgeDocument.fromJson(e as Map<String, dynamic>))
          .toList();

      int? pendingTotal;
      if (state.tab == DocCenterTab.running) {
        final pending = await _loadPendingDocs(page);
        pendingTotal = pending.pendingTotal;
        docs.addAll(pending.docs);
        docs.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      }

      final totalCount = result['total'] as int? ?? 0;
      state = state.copyWith(
        items: docs,
        total: totalCount,
        isLoading: false,
        currentPage: page,
        runningTotal: state.tab == DocCenterTab.running ? totalCount : null,
        pendingTotal: pendingTotal,
        hasMore: docs.length < (state.tab == DocCenterTab.running ? totalCount + (pendingTotal ?? 0) : totalCount),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoading: true);
    final nextPage = state.currentPage + 1;
    try {
      final status = _statusForTab();
      final result = await _ds.listDocuments(status: status, page: nextPage);
      final rawItems = result['items'] as List<dynamic>? ?? [];
      final newDocs = rawItems
          .map((e) => DocForgeDocument.fromJson(e as Map<String, dynamic>))
          .toList();

      int? pendingTotal;
      if (state.tab == DocCenterTab.running) {
        final pending = await _loadPendingDocs(nextPage);
        pendingTotal = pending.pendingTotal;
        newDocs.addAll(pending.docs);
        newDocs.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      }

      final runningTotal = result['total'] as int? ?? 0;
      final totalCount = state.tab == DocCenterTab.running
          ? runningTotal + (pendingTotal ?? state.pendingTotal ?? 0)
          : runningTotal;
      final allItems = [...state.items, ...newDocs];
      state = state.copyWith(
        items: allItems,
        total: runningTotal,
        isLoading: false,
        currentPage: nextPage,
        runningTotal: state.tab == DocCenterTab.running ? runningTotal : null,
        pendingTotal: pendingTotal ?? state.pendingTotal,
        hasMore: allItems.length < totalCount,
      );
    } catch (e) {
      debugPrint('[DocumentList] loadMore error: $e');
      state = state.copyWith(isLoading: false, error: '加载更多失败，请重试');
    }
  }
}

final documentListProvider =
    StateNotifierProvider<DocumentListNotifier, DocumentListState>(
  (ref) => DocumentListNotifier(),
);

// ─── 文档详情 ───

class DocumentDetailState {
  final DocForgeDocument? document;
  final bool isLoading;
  final String? error;

  const DocumentDetailState({this.document, this.isLoading = false, this.error});

  DocumentDetailState copyWith({DocForgeDocument? document, bool? isLoading, String? error}) =>
      DocumentDetailState(
        document: document ?? this.document,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class DocumentDetailNotifier extends StateNotifier<DocumentDetailState> {
  DocumentDetailNotifier() : super(const DocumentDetailState());

  StreamSubscription<DocProgress>? _streamSub;
  CancelToken? _cancelToken;
  int _sseRetryCount = 0;
  static const _maxSseRetry = 3;

  Future<void> load(int docId) async {
    state = const DocumentDetailState(isLoading: true);
    try {
      final doc = await _ds.getDocument(docId);
      state = DocumentDetailState(document: doc);

      // 运行中/排队中 → 自动连 SSE（仅初次加载重置重试计数）
      if (doc.status == DocStatus.running || doc.status == DocStatus.pending) {
        _connectStream(docId);
      }
    } catch (e) {
      state = DocumentDetailState(error: e.toString());
    }
  }

  /// 静默刷新 — 不设置 isLoading，避免 UI 闪屏
  Future<void> _silentRefresh(int docId) async {
    try {
      final doc = await _ds.getDocument(docId);
      if (mounted) state = DocumentDetailState(document: doc);
    } catch (e) {
      debugPrint('[DocumentDetail] silentRefresh error: $e');
    }
  }

  void _connectStream(int docId) {
    _cancelToken?.cancel();
    _streamSub?.cancel();
    _cancelToken = CancelToken();
    _streamSub = _ds.progressStream(docId, cancelToken: _cancelToken).listen(
      (progress) {
        final doc = state.document;
        if (doc == null) return;
        state = DocumentDetailState(
          document: doc.copyWith(
            progress: progress.progress,
            progressMsg: progress.message,
            progressDetail: progress.detail,
          ),
        );
      },
      onDone: () async {
        if (!mounted) return;
        // 先刷新获取最新状态，判断任务是否已终态
        await _silentRefresh(docId);
        final doc = state.document;
        if (doc != null && doc.status != DocStatus.running && doc.status != DocStatus.pending) {
          return;
        }
        _sseRetryCount++;
        if (_sseRetryCount <= _maxSseRetry) {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) _connectStream(docId);
        }
      },
      onError: (e) async {
        if (!mounted) return;
        _sseRetryCount++;
        if (_sseRetryCount <= _maxSseRetry) {
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) _connectStream(docId);
        }
      },
    );
  }

  Future<void> cancel(int docId) async {
    await _ds.cancelDocument(docId);
    _streamSub?.cancel();
    await load(docId);
  }

  Future<bool> delete(int docId) async {
    return _ds.deleteDocument(docId);
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _streamSub?.cancel();
    super.dispose();
  }
}

final documentDetailProvider =
    StateNotifierProvider.family.autoDispose<DocumentDetailNotifier, DocumentDetailState, int>(
  (ref, docId) {
    final notifier = DocumentDetailNotifier();
    notifier.load(docId);
    return notifier;
  },
);
