import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/utils/file_export.dart';
import '../../../../shared/models/dsl/dsl_node.dart';
import '../../../../shared/widgets/dsl/dsl_renderer.dart';
import '../../data/document_data_source.dart';
import '../../data/models/document_models.dart';
import '../../domain/providers/document_provider.dart';

class DocumentDetailPage extends ConsumerStatefulWidget {
  final int docId;
  const DocumentDetailPage({super.key, required this.docId});

  @override
  ConsumerState<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends ConsumerState<DocumentDetailPage> {
  List<DslNode> _nodes = [];
  List<DslOutline> _outline = [];
  bool _isStreaming = false;
  bool _initialized = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // 从当前缓存状态主动解析（Provider 可能已有缓存数据）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(documentDetailProvider(widget.docId));
      final doc = state.document;
      if (doc != null && !_initialized) {
        _initialized = true;
        _updateFromDocument(doc);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentDetailProvider(widget.docId));
    final doc = state.document;

    ref.listen(documentDetailProvider(widget.docId), (prev, next) {
      final d = next.document;
      if (d == null) return;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted) _updateFromDocument(d);
      });
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          doc?.title ?? '文档详情',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (doc != null) ..._buildActions(doc),
        ],
      ),
      body: _buildBody(state, doc),
    );
  }

  List<Widget> _buildActions(DocForgeDocument doc) {
    final actions = <Widget>[];
    if (doc.status == DocStatus.running || doc.status == DocStatus.pending) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error),
          onPressed: () => _confirmCancel(doc.id),
        ),
      );
    }
    if (doc.status == DocStatus.completed) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.download_outlined, color: AppColors.textSecondary),
          onPressed: () => _export(doc.id),
        ),
      );
      actions.add(
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: () => _confirmDelete(doc.id),
        ),
      );
    }
    return actions;
  }

  Widget _buildBody(DocumentDetailState state, DocForgeDocument? doc) {
    if (state.isLoading && doc == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && doc == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(state.error!, style: const TextStyle(fontSize: 14, color: AppColors.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(documentDetailProvider(widget.docId).notifier).load(widget.docId),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (doc == null) return const SizedBox.shrink();

    // 失败状态
    if (doc.status == DocStatus.failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('生成失败', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 8),
              Text(doc.errorMsg ?? '未知错误', style: const TextStyle(fontSize: 13, color: AppColors.textMuted), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/generate'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('重新创建'),
              ),
            ],
          ),
        ),
      );
    }

    // 进度条（进行中）
    if (doc.status == DocStatus.running || doc.status == DocStatus.pending) {
      return Column(
        children: [
          _buildProgressHeader(doc),
          Expanded(child: _buildContent()),
        ],
      );
    }

    // 已完成 / 已取消
    return _buildContent();
  }

  Widget _buildProgressHeader(DocForgeDocument doc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: doc.progress.clamp(0.0, 1.0),
                    backgroundColor: AppColors.borderLight,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${(doc.progress.clamp(0.0, 1.0) * 100).round()}%',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
          if (doc.progressMsg != null) ...[
            const SizedBox(height: 6),
            Text(doc.progressMsg!,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_nodes.isEmpty && _outline.isEmpty) {
      if (_isStreaming) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 12),
              Text('AI 正在思考...', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ],
          ),
        );
      }
      return const Center(
        child: Text('暂无内容', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DslRenderer(nodes: _nodes, isStreaming: _isStreaming),
    );
  }

  void _updateFromDocument(DocForgeDocument doc) {
    _isStreaming = doc.status == DocStatus.running || doc.status == DocStatus.pending;

    // 已完成：从 dslContent 提取（优先用最终数据）
    if (doc.status.isTerminal && doc.dslContent != null) {
      _sectionNodes.clear();
      _sectionTitles.clear();
      _parseDslContent(doc.dslContent);
      setState(() {});
      return;
    }

    // 进行中：从 progressDetail 中提取 dsl_update
    final detail = doc.progressDetail;
    if (detail != null) {
      final dslUpdate = detail['dsl_update'] as Map<String, dynamic>?;
      if (dslUpdate != null) {
        _applyDslUpdate(dslUpdate);
      }
    }

    setState(() {});
  }

  /// section_id → nodes 累积器
  final Map<String, List<DslNode>> _sectionNodes = {};
  final Map<String, String> _sectionTitles = {};

  void _applyDslUpdate(Map<String, dynamic> update) {
    // outline
    final outlineRaw = update['outline'] as List<dynamic>?;
    if (outlineRaw != null) {
      _outline = outlineRaw.map((e) => DslOutline.fromJson(e as Map<String, dynamic>)).toList();
      for (final o in _outline) {
        _sectionTitles.putIfAbsent(o.id, () => o.title);
      }
    }

    // node_updates 是一个 List
    final nodeUpdates = update['node_updates'] as List<dynamic>?;
    if (nodeUpdates == null) return;

    for (final entry in nodeUpdates) {
      if (entry is! Map<String, dynamic>) continue;
      final op = entry['op'] as String?;
      final sid = entry['section'] as String? ?? 'main';

      if (op == 'replace_all') {
        final nodesRaw = entry['nodes'] as List<dynamic>? ?? [];
        _sectionNodes[sid] = nodesRaw
            .map((e) => DslNode.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (op == 'append') {
        final node = entry['node'] as Map<String, dynamic>?;
        if (node != null) {
          _sectionNodes.putIfAbsent(sid, () => []);
          _sectionNodes[sid]!.add(DslNode.fromJson(node));
        }
      }
    }

    _rebuildNodes();
  }

  void _rebuildNodes() {
    final result = <DslNode>[];

    // 如果只有一个 section 且是 main，扁平输出
    if (_sectionNodes.length == 1 && _sectionNodes.containsKey('main')) {
      result.addAll(_sectionNodes['main']!);
    } else if (_outline.isNotEmpty) {
      // 按 outline 顺序输出 section
      for (final o in _outline) {
        final nodes = _sectionNodes[o.id];
        if (nodes != null && nodes.isNotEmpty) {
          result.add(DslNode(
            type: DslNodeType.section,
            id: o.id,
            title: _sectionTitles[o.id] ?? o.title,
            children: nodes,
          ));
        }
      }
      // 补充 outline 之外的 section
      for (final sid in _sectionNodes.keys) {
        if (_outline.any((o) => o.id == sid)) continue;
        final nodes = _sectionNodes[sid]!;
        if (nodes.isNotEmpty) {
          result.add(DslNode(
            type: DslNodeType.section,
            id: sid,
            title: _sectionTitles[sid] ?? '',
            children: nodes,
          ));
        }
      }
    } else {
      // 无 outline，按插入顺序输出
      for (final entry in _sectionNodes.entries) {
        if (entry.value.isNotEmpty) {
          result.add(DslNode(
            type: DslNodeType.section,
            id: entry.key,
            title: _sectionTitles[entry.key] ?? '',
            children: entry.value,
          ));
        }
      }
    }

    _nodes = result;
  }

  void _parseDslContent(dynamic dslContent) {
    if (dslContent == null) return;
    try {
      Map<String, dynamic> dsl;
      if (dslContent is String) {
        dsl = jsonDecode(dslContent) as Map<String, dynamic>;
      } else {
        dsl = dslContent as Map<String, dynamic>;
      }

      // 后端 _build_document_node 输出 children（不是 sections）
      final childrenRaw = dsl['children'] as List<dynamic>? ?? [];
      final allNodes = <DslNode>[];
      for (final child in childrenRaw) {
        final c = child as Map<String, dynamic>;
        allNodes.add(DslNode.fromJson(c));
      }
      _nodes = allNodes;
    } catch (e) {
      debugPrint('[DocumentDetail] parseDslContent error: $e');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _confirmCancel(int docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消任务'),
        content: const Text('确定要取消当前文档生成吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('继续')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(documentDetailProvider(widget.docId).notifier).cancel(docId);
            },
            child: const Text('取消任务', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文档'),
        content: const Text('确定要删除此文档吗？删除后无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref.read(documentDetailProvider(widget.docId).notifier).delete(docId);
              if (ok && mounted) context.pop();
            },
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _export(int docId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在导出...'), duration: Duration(seconds: 30)),
      );

      final ds = DocumentDataSource();
      final bytes = await ds.exportWord(docId);

      final doc = ref.read(documentDetailProvider(widget.docId)).document;
      final fileName = '${doc?.title ?? '文档'}$docId.docx';

      final result = await FileExporter.saveAndOpen(bytes: Uint8List.fromList(bytes), fileName: fileName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result.openResult.type == ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出成功，已打开'), duration: Duration(seconds: 2)),
        );
      } else {
        // 无法打开（如模拟器无 Office 应用），弹出分享
        await FileExporter.saveAndShare(
          bytes: Uint8List.fromList(bytes),
          fileName: fileName,
          subject: doc?.title ?? '文档',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导出失败，请检查网络后重试')),
      );
    }
  }
}
