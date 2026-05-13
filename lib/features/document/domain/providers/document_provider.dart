import 'dart:async';
import 'package:dio/dio.dart';
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

  const DocumentListState({
    this.items = const [],
    this.total = 0,
    this.isLoading = false,
    this.error,
    this.tab = DocCenterTab.all,
    this.currentPage = 1,
    this.hasMore = true,
  });

  DocumentListState copyWith({
    List<DocForgeDocument>? items,
    int? total,
    bool? isLoading,
    String? error,
    DocCenterTab? tab,
    int? currentPage,
    bool? hasMore,
  }) =>
      DocumentListState(
        items: items ?? this.items,
        total: total ?? this.total,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        tab: tab ?? this.tab,
        currentPage: currentPage ?? this.currentPage,
        hasMore: hasMore ?? this.hasMore,
      );
}

class DocumentListNotifier extends StateNotifier<DocumentListState> {
  DocumentListNotifier() : super(const DocumentListState());

  Future<void> load({DocCenterTab? tab, int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null, tab: tab ?? state.tab);
    try {
      DocStatus? status;
      if (state.tab == DocCenterTab.running) {
        // pending + running 都算进行中，后端暂只支持单一 status 筛选
        // 传 null 由前端过滤，或先查 pending 再查 running
        status = DocStatus.running;
      } else if (state.tab == DocCenterTab.completed) {
        status = DocStatus.completed;
      }

      final result = await _ds.listDocuments(status: status, page: page);
      final rawItems = result['items'] as List<dynamic>? ?? [];
      final docs = rawItems
          .map((e) => DocForgeDocument.fromJson(e as Map<String, dynamic>))
          .toList();

      // 如果 Tab 是进行中，额外加载 pending
      if (state.tab == DocCenterTab.running) {
        try {
          final pendingResult = await _ds.listDocuments(status: DocStatus.pending, page: page);
          final pendingRaw = pendingResult['items'] as List<dynamic>? ?? [];
          final pendingDocs = pendingRaw
              .map((e) => DocForgeDocument.fromJson(e as Map<String, dynamic>))
              .toList();
          docs.addAll(pendingDocs);
          docs.sort((a, b) {
            final ta = a.createdAt ?? '';
            final tb = b.createdAt ?? '';
            return tb.compareTo(ta);
          });
        } catch (_) {}
      }

      state = state.copyWith(
        items: docs,
        total: result['total'] as int? ?? 0,
        isLoading: false,
        currentPage: page,
        hasMore: docs.length < (result['total'] as int? ?? 0),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    final nextPage = state.currentPage + 1;
    try {
      DocStatus? status;
      if (state.tab == DocCenterTab.running) {
        status = DocStatus.running;
      } else if (state.tab == DocCenterTab.completed) {
        status = DocStatus.completed;
      }

      final result = await _ds.listDocuments(status: status, page: nextPage);
      final rawItems = result['items'] as List<dynamic>? ?? [];
      final newDocs = rawItems
          .map((e) => DocForgeDocument.fromJson(e as Map<String, dynamic>))
          .toList();

      if (state.tab == DocCenterTab.running) {
        try {
          final pendingResult = await _ds.listDocuments(status: DocStatus.pending, page: nextPage);
          final pendingRaw = pendingResult['items'] as List<dynamic>? ?? [];
          newDocs.addAll(
            pendingRaw.map((e) => DocForgeDocument.fromJson(e as Map<String, dynamic>)).toList(),
          );
          newDocs.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
        } catch (_) {}
      }

      final total = result['total'] as int? ?? 0;
      state = state.copyWith(
        items: [...state.items, ...newDocs],
        total: total,
        currentPage: nextPage,
        hasMore: state.items.length + newDocs.length < total,
      );
    } catch (_) {}
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

      // 运行中/排队中 → 自动连 SSE
      if (doc.status == DocStatus.running || doc.status == DocStatus.pending) {
        _sseRetryCount = 0;
        _connectStream(docId);
      }
    } catch (e) {
      state = DocumentDetailState(error: e.toString());
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
        final doc = state.document;
        // SSE 正常结束且进度满 → 文档已完成，刷新一次获取最终状态
        if (doc != null && doc.progress >= 1.0) {
          await Future.delayed(const Duration(milliseconds: 500));
          load(docId);
          return;
        }
        _sseRetryCount++;
        if (_sseRetryCount <= _maxSseRetry) {
          await Future.delayed(const Duration(seconds: 1));
          load(docId);
        }
      },
      onError: (e) async {
        _sseRetryCount++;
        if (_sseRetryCount <= _maxSseRetry) {
          await Future.delayed(const Duration(seconds: 2));
          load(docId);
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
    StateNotifierProvider.family<DocumentDetailNotifier, DocumentDetailState, int>(
  (ref, docId) {
    final notifier = DocumentDetailNotifier();
    notifier.load(docId);
    return notifier;
  },
);
