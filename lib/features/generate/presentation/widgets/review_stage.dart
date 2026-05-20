import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/models/generate_models.dart';
import '../../domain/providers/generate_provider.dart';
import '../../../../shared/widgets/feature_header.dart';
import '../../../../shared/widgets/review_report.dart';
import '../../../../shared/widgets/dsl/dsl_renderer.dart';
import '../../../../shared/models/dsl/dsl_node.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReviewStage extends ConsumerStatefulWidget {
  const ReviewStage({super.key});

  @override
  ConsumerState<ReviewStage> createState() => _ReviewStageState();
}

class _ReviewStageState extends ConsumerState<ReviewStage> {
  WebViewController? _webViewController;
  bool _isWebViewLoading = false;
  String? _previewUrl;
  bool _webViewReady = false;

  // 选中状态
  int? _selectedFindingIndex;
  ReviewFinding? _pendingHighlight; // WebView 加载完后待高亮的 finding

  static const double _wideBreakpoint = 768;

  bool get _showPreview => _selectedFindingIndex != null;

  @override
  void initState() {
    super.initState();
    // 不预加载 WebView，等用户点击 finding 再懒加载
  }

  /// 点击 finding：切换预览 + 触发高亮
  void _onFindingTap(int index, ReviewFinding finding) {
    setState(() {
      if (_selectedFindingIndex == index) {
        // 再次点击同一条 → 关闭预览
        _selectedFindingIndex = null;
      } else {
        _selectedFindingIndex = index;
      }
    });

    if (_selectedFindingIndex == null) return;

    if (_webViewController == null && !_webViewReady) {
      // 首次打开：懒加载 WebView
      _pendingHighlight = finding;
      _setupPreview();
    } else if (_webViewReady && _webViewController != null) {
      // WebView 已就绪：直接高亮
      _highlightInWebView(finding);
    } else {
      // WebView 正在加载：存为 pending
      _pendingHighlight = finding;
    }
  }

  // ─── WebView 生命周期（懒加载） ───

  void _setupPreview() {
    final notifier = ref.read(generateProvider.notifier);
    final url = notifier.getPreviewUrl();
    if (url != null && url != _previewUrl) {
      _previewUrl = url;
      setState(() => _isWebViewLoading = true);
      _initWebView(url);
    }
  }

  Future<void> _initWebView(String url) async {
    final token = await SecureStorage.instance.getToken();

    Uri previewUri = Uri.parse(url);
    if (token != null) {
      previewUri = previewUri.replace(queryParameters: {
        ...previewUri.queryParameters,
        'token': token,
      });
    }

    final allowedHost = previewUri.host;

    try {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (request) {
            final reqHost = Uri.parse(request.url).host;
            if (reqHost != allowedHost && reqHost.isNotEmpty) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) {
            _injectHighlightScript();
            if (mounted) {
              setState(() {
                _isWebViewLoading = false;
                _webViewReady = true;
              });
            }
            // 处理等待中的高亮
            if (_pendingHighlight != null) {
              _highlightInWebView(_pendingHighlight!);
              _pendingHighlight = null;
            }
          },
          onWebResourceError: (e) {
            if (mounted) setState(() => _isWebViewLoading = false);
          },
        ))
        ..loadRequest(previewUri);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[ReviewStage] WebView init failed: $e');
      _webViewController = null;
      if (mounted) setState(() => _isWebViewLoading = false);
    }
  }

  /// 注入高亮 CSS 和搜索函数
  void _injectHighlightScript() {
    _webViewController?.runJavaScript('''
      (function() {
        var style = document.createElement('style');
        style.textContent = '.review-hl { background: #FEF08A; border-radius: 2px; padding: 1px 2px; box-shadow: 0 0 0 2px #F59E0B; transition: background 3s ease; }';
        document.head.appendChild(style);
      })();
    ''');
  }

  /// 在 WebView 中定位并高亮 finding 对应文本
  void _highlightInWebView(ReviewFinding finding) {
    if (_webViewController == null || !_webViewReady) return;

    // 优先用 location，否则用 message 中的关键短语
    final location = finding.location;
    String searchText = '';

    if (location.startsWith('heading:')) {
      searchText = location.substring(8);
    } else if (location.startsWith('section:')) {
      searchText = location.substring(8);
    } else if (location == 'paragraph') {
      searchText = _extractQuotedText(finding.message);
    } else if (location == 'document') {
      // 文档级别 finding：尝试从 message 提取关键词，否则滚动到顶部
      searchText = _extractQuotedText(finding.message);
    } else if (location.isNotEmpty) {
      searchText = location;
    }

    if (searchText.isEmpty) {
      searchText = _extractQuotedText(finding.message);
    }

    if (searchText.isEmpty) {
      // 无法提取搜索词：滚动到文档顶部
      _webViewController?.runJavaScript('window.scrollTo({top:0,behavior:"smooth"})');
      return;
    }

    final escaped = jsonEncode(searchText);
    _webViewController?.runJavaScript('''
      (function() {
        var prev = document.querySelectorAll('.review-hl');
        for (var i = 0; i < prev.length; i++) {
          var p = prev[i].parentNode;
          p.replaceChild(document.createTextNode(prev[i].textContent), prev[i]);
          p.normalize();
        }
        var target = $escaped;
        var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        var node;
        while (node = walker.nextNode()) {
          var idx = node.textContent.indexOf(target);
          if (idx >= 0 && target.length > 0) {
            try {
              var range = document.createRange();
              range.setStart(node, idx);
              range.setEnd(node, idx + target.length);
              var span = document.createElement('span');
              span.className = 'review-hl';
              range.surroundContents(span);
              span.scrollIntoView({ behavior: 'smooth', block: 'center' });
              setTimeout(function(){ span.style.background = 'transparent'; span.style.boxShadow = 'none'; }, 3500);
            } catch(e) {}
            return;
          }
        }
      })();
    ''');
  }

  /// 从 message 中提取引号内的文本（审校意见常引用原文）
  String _extractQuotedText(String message) {
    // 匹配 「xxx」、《xxx》、"xxx" 中的内容
    final patterns = [
      // 中文引号
      RegExp(r'「(.{2,50}?)」'),
      RegExp(r'『(.{2,50}?)』'),
      // 书名号
      RegExp(r'《(.{2,50}?)》'),
      // 中文双引号
      RegExp(r'“(.{2,50}?)”'),
      // 直引号
      RegExp(r'"(.{2,50}?)"'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(message);
      if (m != null) return m.group(1)!;
    }
    // 兜底：取 message 中冒号后的片段
    final afterColon = RegExp(r'[：:]\s*(.{2,30})').firstMatch(message);
    if (afterColon != null) return afterColon.group(1)!.trim();
    return '';
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final headerInfo = ref.watch(generateProvider.select((s) => (
      s.docTitle,
      s.selectedScene?.name,
      s.resultData?['word_count'],
      s.resultData?['chapter_count'],
      s.outline.length,
    )));
    final notifier = ref.read(generateProvider.notifier);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= _wideBreakpoint;

    final title = headerInfo.$1.isNotEmpty ? headerInfo.$1 : (headerInfo.$2 ?? '文档');
    final wordCount = headerInfo.$3 ?? '--';
    final chapterCount = headerInfo.$4 ?? headerInfo.$5;

    return Column(
      children: [
        FeatureHeader(
          color: AppColors.success,
          title: '生成完成',
          subtitle: '$title · 共 $chapterCount 章节 · 约 $wordCount 字',
          showBackButton: true,
          onBack: () => notifier.backToInput(),
        ),
        _buildSteps(),
        Expanded(
          child: isWide
              ? _buildWideBody(notifier)
              : _buildNarrowBody(notifier),
        ),
        const _ActionButtons(),
      ],
    );
  }

  // ─── 宽屏：左侧报告（可展开预览） ───

  Widget _buildWideBody(GenerateNotifier notifier) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _showPreview
          ? Row(
              key: const ValueKey('split'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左侧：报告
                SizedBox(
                  width: (MediaQuery.of(context).size.width * 0.38).clamp(320.0, 480.0),
                  child: _buildReportPanel(),
                ),
                Container(width: 1, color: AppColors.border),
                // 右侧：预览
                Expanded(child: _buildPreviewArea()),
              ],
            )
          : SingleChildScrollView(
              key: const ValueKey('report-only'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildReportCard(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  // ─── 窄屏：报告 + 可展开预览 ───

  Widget _buildNarrowBody(GenerateNotifier notifier) {
    return Column(
      children: [
        // 报告区（固定显示，可滚动）
        Flexible(child: _buildReportPanel()),
        // 预览区（点击 finding 展开）
        if (_showPreview)
          Expanded(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              alignment: Alignment.topCenter,
              child: _buildPreviewArea(),
            ),
          ),
      ],
    );
  }

  // ─── 报告面板（带 finding 点击） ───

  Widget _buildReportPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          _buildReportCard(),
        ],
      ),
    );
  }

  Widget _buildReportCard() {
    // 读取 resultData 中的 review_result
    final resultData = ref.watch(generateProvider.select((s) => s.resultData));
    if (resultData == null) return const SizedBox.shrink();
    final reviewData = resultData['review_result'];
    if (reviewData == null) return const SizedBox.shrink();

    final findingsRaw = reviewData['findings'] as List<dynamic>?;
    final findings = findingsRaw
            ?.whereType<Map<String, dynamic>>()
            .map((f) => ReviewFinding.fromJson(f))
            .toList() ??
        [];

    return ReviewReportCard(
      passed: findings.isEmpty,
      findings: findings,
      fixedCount: reviewData['fixed_count'] as int? ?? 0,
      selectedIndex: _selectedFindingIndex,
      onFindingTap: _onFindingTap,
    );
  }

  // ─── 预览区（WebView 或 DSL 回退） ───

  Widget _buildPreviewArea() {
    return Column(
      children: [
        // 顶部栏：关闭按钮 + loading 指示
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.find_in_page, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('文档定位', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
              if (_isWebViewLoading)
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _selectedFindingIndex = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text('关闭预览', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // 预览内容
        Expanded(child: _buildPreviewContent()),
      ],
    );
  }

  Widget _buildPreviewContent() {
    if (_webViewController != null) {
      return RepaintBoundary(
        child: WebViewWidget(controller: _webViewController!),
      );
    }

    // 无 WebView：DSL 回退
    return _buildFallbackPreview();
  }

  Widget _buildFallbackPreview() {
    final dslData = ref.watch(generateProvider.select((s) => (s.dslNodes, s.outline)));
    final nodes = dslData.$1;
    final outline = dslData.$2;
    final hasNodes = nodes.isNotEmpty && nodes.values.any((l) => l.isNotEmpty);

    if (hasNodes) {
      final allNodes = <DslNode>[];
      for (final section in outline) {
        final sectionNodes = nodes[section.id] ?? [];
        if (sectionNodes.isNotEmpty) allNodes.addAll(sectionNodes);
      }
      if (allNodes.isEmpty) {
        final mainNodes = nodes['main'] ?? nodes.values.first;
        allNodes.addAll(mainNodes);
      }

      return Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: DslRenderer(nodes: allNodes),
        ),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('文档预览加载中...', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  // ─── 步骤条 ───

  Widget _buildSteps() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepDot(StepStatus.done), _stepLine(true),
          _stepDot(StepStatus.done), _stepLine(true),
          _stepDot(StepStatus.active),
        ],
      ),
    );
  }

  Widget _stepDot(StepStatus status) {
    final color = switch (status) {
      StepStatus.done => AppColors.success,
      StepStatus.active => AppColors.primary,
      StepStatus.pending => AppColors.border,
    };
    return Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  Widget _stepLine(bool done) {
    return Container(width: 32, height: 2, color: done ? AppColors.success : AppColors.border);
  }
}

// ═══════════════════════════════════════════════════════════
// 操作按钮 — 独立组件，精确订阅
// ═══════════════════════════════════════════════════════════

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canExport = ref.watch(generateProvider.select((s) =>
        s.documentId != null && !s.isExporting));
    final isExporting = ref.watch(generateProvider.select((s) => s.isExporting));
    final notifier = ref.read(generateProvider.notifier);

    ref.listen(generateProvider.select((s) => (s.exportSuccess, s.error)), (prev, next) {
      final prevSuccess = prev?.$1 ?? false;
      final prevError = prev?.$2;
      if (next.$1 && !prevSuccess) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('文档导出成功'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      if (next.$2 != null && next.$2 != prevError) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.$2!),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '重试',
              textColor: Colors.white,
              onPressed: () {
                notifier.selectExportFormat(ExportFormat.docx);
                notifier.exportDocument();
              },
            ),
          ),
        );
      }
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => notifier.backToInput(),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_note, size: 16, color: AppColors.text),
                    SizedBox(width: 4),
                    Text('重新编辑', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: canExport
                    ? () {
                        notifier.selectExportFormat(ExportFormat.docx);
                        notifier.exportDocument();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  elevation: 0,
                ),
                child: isExporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text('导出文档', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
