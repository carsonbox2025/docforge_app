import 'dart:convert';

import '../../../../core/storage/local_cache.dart';
import 'models/draft_model.dart';

/// 草稿本地数据源 — 使用 Hive LocalCache 持久化
class DraftLocalDataSource {
  static const _draftsKey = 'drafts_list';

  final LocalCache _cache;

  DraftLocalDataSource({LocalCache? cache})
      : _cache = cache ?? LocalCache.instance;

  // ---- Read ----

  /// 获取所有草稿（按 updatedAt 降序）
  Future<List<Draft>> getAllDrafts() async {
    final raw = _cache.get<String>(_draftsKey);
    if (raw == null) return [];
    final List<dynamic> jsonList = jsonDecode(raw);
    final drafts = jsonList
        .map((e) => Draft.fromJson(e as Map<String, dynamic>))
        .toList();
    // 按 updatedAt 降序排列
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  /// 获取单个草稿
  Future<Draft?> getDraft(String id) async {
    final drafts = await getAllDrafts();
    return drafts.where((d) => d.id == id).firstOrNull;
  }

  // ---- Write ----

  /// 保存草稿（新增或更新）
  Future<Draft> saveDraft(Draft draft) async {
    final drafts = await getAllDrafts();
    final index = drafts.indexWhere((d) => d.id == draft.id);

    final updated = draft.updatedAt.isEmpty
        ? draft.copyWith(updatedAt: DateTime.now().toIso8601String())
        : draft;

    if (index >= 0) {
      drafts[index] = updated;
    } else {
      drafts.insert(0, updated);
    }

    await _cache.set(_draftsKey, jsonEncode(drafts.map((d) => d.toJson()).toList()));
    return updated;
  }

  /// 创建新草稿
  Future<Draft> createDraft({
    required String title,
    String content = '',
    String docType = 'default',
  }) async {
    final draft = Draft(
      id: _generateId(),
      title: title,
      content: content,
      docType: docType,
      updatedAt: DateTime.now().toIso8601String(),
    );
    return saveDraft(draft);
  }

  // ---- Delete ----

  /// 删除草稿
  Future<bool> deleteDraft(String id) async {
    final drafts = await getAllDrafts();
    final filtered = drafts.where((d) => d.id != id).toList();
    if (filtered.length == drafts.length) return false;
    await _cache.set(
        _draftsKey, jsonEncode(filtered.map((d) => d.toJson()).toList()));
    return true;
  }

  // ---- Helpers ----

  String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = DateTime.now().microsecond;
    return 'draft_${ts}_$rand';
  }
}
