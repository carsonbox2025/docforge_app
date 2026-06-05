import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../shared/utils/file_export.dart';
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
  WebViewController? _webViewController;
  bool _webViewLoading = true;
  bool _webViewError = false;
  bool _initialized = false;
  String? _htmlContent;
  bool _htmlLoading = false;

  bool get _useWebView =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(documentDetailProvider(widget.docId));
      final doc = state.document;
      if (doc != null && doc.status == DocStatus.completed) {
        if (_useWebView) {
          _initWebView();
        } else {
          _loadHtmlContent();
        }
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
      if (d.status == DocStatus.completed) {
        if (_useWebView) {
          if (_webViewController == null) _initWebView();
        } else {
          if (_htmlContent == null && !_htmlLoading) _loadHtmlContent();
        }
      }
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
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 12),
                  Text('AI 正在处理...', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 已完成 / 已取消 — WebView HTML 预览
    return _buildWebViewContent();
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

  Widget _buildWebViewContent() {
    if (_useWebView) {
      return _buildNativeWebView();
    }
    return _buildHtmlWidget();
  }

  Widget _buildHtmlWidget() {
    if (_htmlLoading || _htmlContent == null && !_webViewError) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text('正在加载预览...', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      );
    }
    if (_webViewError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('预览加载失败', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() { _webViewError = false; });
                _loadHtmlContent();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HtmlWidget(
        _htmlContent!,
        textStyle: const TextStyle(fontSize: 15, height: 1.8, color: AppColors.text),
      ),
    );
  }

  Widget _buildNativeWebView() {
    if (_webViewController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text('正在加载预览...', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _webViewController!),
        if (_webViewError)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                const Text('预览加载失败', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() { _webViewError = false; _webViewLoading = true; });
                    _initWebView();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        if (_webViewLoading && !_webViewError)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Future<void> _loadHtmlContent() async {
    if (_htmlContent != null || _htmlLoading) return;
    setState(() { _htmlLoading = true; _webViewError = false; });
    try {
      final html = await DocumentDataSource().fetchPreviewHtml(widget.docId);
      if (!mounted) return;
      if (html.isEmpty) {
        setState(() { _htmlLoading = false; _webViewError = true; });
        return;
      }
      setState(() { _htmlContent = html; _htmlLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _htmlLoading = false; _webViewError = true; });
    }
  }

  // SECURITY DEBT: token 通过 URL query 参数传递，会被 WebView 缓存和服务器 access log 记录。
  // 短期方案：当前 WebView 已限制导航域。长期应改为后端短期一次性 ticket 或 cookie 注入。
  Future<void> _initWebView() async {
    if (_initialized) return;

    final token = await SecureStorage.instance.getToken();
    final baseUrl = '${AppConstants.apiBasePath}/preview/${widget.docId}/html';
    Uri uri = Uri.parse(baseUrl);
    if (token != null) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, 'token': token});
    }

    final allowedHost = uri.host;
    try {
      _initialized = true;
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (request) {
            try {
              final reqHost = Uri.parse(request.url).host;
              if (reqHost != allowedHost && reqHost.isNotEmpty) {
                return NavigationDecision.prevent;
              }
            } catch (_) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _webViewLoading = false);
          },
          onWebResourceError: (e) {
            if (mounted) setState(() {
              _webViewLoading = false;
              _webViewError = true;
              _initialized = false;
            });
          },
        ))
        ..loadRequest(uri);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() { _webViewLoading = false; _webViewError = true; _initialized = false; });
    }
  }

  @override
  void dispose() {
    _webViewController = null;
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
