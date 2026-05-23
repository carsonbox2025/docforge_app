import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/storage/local_cache.dart';
import '../../data/search_data_source.dart';
import '../../../document/data/models/document_models.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _dataSource = SearchDataSource();

  String _query = '';
  List<String> _searchHistory = [];
  List<DocForgeDocument> _results = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  int _page = 1;
  int _total = 0;

  static const _historyKey = 'search_history';
  static const _maxHistoryItems = 12;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadHistory() async {
    try {
      final saved = await LocalCache.instance.get(_historyKey);
      if (saved != null && mounted) {
        setState(() {
          _searchHistory = List<String>.from(saved as List);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    // 去重 + 限制数量
    final cleaned = <String>[];
    for (final h in [_query, ..._searchHistory]) {
      if (!cleaned.contains(h)) cleaned.add(h);
    }
    if (cleaned.length > _maxHistoryItems) {
      cleaned.removeRange(_maxHistoryItems, cleaned.length);
    }
    _searchHistory = cleaned;
    try {
      await LocalCache.instance.set(_historyKey, cleaned);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _results = [];
        _isSearching = false;
        _page = 1;
        _total = 0;
      });
      return;
    }
    if (q == _query) return;

    setState(() {
      _query = q;
      _isSearching = true;
      _page = 1;
      _results = [];
      _total = 0;
    });

    _performSearch(q);
  }

  Future<void> _performSearch(String query) async {
    try {
      final response = await _dataSource.searchDocuments(query: query, page: _page);
      if (!mounted) return;

      final items = response['items'] as List<dynamic>? ?? [];
      final results = items.map((e) => DocForgeDocument.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        if (_page == 1) {
          _results = results;
        } else {
          _results.addAll(results);
        }
        _total = response['total'] as int? ?? 0;
        _isSearching = false;
        _isLoadingMore = false;
      });

      _saveHistory();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    if (_results.length >= _total) return;

    setState(() {
      _page++;
      _isLoadingMore = true;
    });
    await _performSearch(_query);
  }

  void _useHistoryTag(String tag) {
    _searchController.text = tag;
    _onSearch(tag);
  }

  void _clearHistory() {
    setState(() => _searchHistory = []);
    LocalCache.instance.set(_historyKey, []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _buildSearchAppBar(),
          Expanded(
            child: _query.isEmpty
                ? _buildSearchHistory()
                : _isSearching
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _results.isEmpty
                        ? _buildNoResult()
                        : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAppBar() {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.text),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    autofocus: true,
                    onSubmitted: _onSearch,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: '搜索文档...',
                      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _onSearch('');
                              },
                              child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('搜索文档', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            const Text('输入关键词搜索历史文档', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('搜索历史', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
              const Spacer(),
              GestureDetector(
                onTap: _clearHistory,
                child: const Text('清空', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _searchHistory.map((tag) {
              return GestureDetector(
                onTap: () => _useHistoryTag(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 5),
                      Text(tag, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResult() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('未找到"$_query"相关文档', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('请尝试其他关键词', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification && notification.metrics.pixels >= notification.metrics.maxScrollExtent - 100) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        itemCount: _results.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _results.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            );
          }
          final doc = _results[index];
          return GestureDetector(
            onTap: () => context.push('/documents/${doc.id}'),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: doc.docType.bgColor,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(doc.docType.icon, size: 22, color: doc.docType.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(doc.docType.label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(width: 8),
                            Text('·', style: TextStyle(fontSize: 12, color: AppColors.textMuted.withValues(alpha: 0.5))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(doc.createdAt ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: doc.status.bgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(doc.status.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: doc.status.color)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
