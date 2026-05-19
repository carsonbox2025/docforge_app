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
  bool _isLoading = true;
  String? _previewUrl;

  @override
  void initState() {
    super.initState();
    // 延迟一帧，确保 ref 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupPreview();
    });
  }

  void _setupPreview() {
    final notifier = ref.read(generateProvider.notifier);
    final url = notifier.getPreviewUrl();
    if (url != null && url != _previewUrl) {
      _previewUrl = url;
      setState(() => _isLoading = true);
      _initWebView(url);
    }
  }

  Future<void> _initWebView(String url) async {
    final token = await SecureStorage.instance.getToken();
    _isLoading = true;

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
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (request) {
            final reqHost = Uri.parse(request.url).host;
            if (reqHost != allowedHost && reqHost.isNotEmpty) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (e) {
            if (mounted) setState(() => _isLoading = false);
          },
        ))
        ..loadRequest(previewUri);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[ReviewStage] WebView init failed (platform unsupported): $e');
      _webViewController = null;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupPreview();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generateProvider);
    final notifier = ref.read(generateProvider.notifier);

    // 监听导出错误
    ref.listen(generateProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '重试',
              textColor: Colors.white,
              onPressed: () => notifier.exportDocument(),
            ),
          ),
        );
      }
    });

    final title = state.docTitle.isNotEmpty ? state.docTitle : (state.selectedScene?.name ?? '文档');
    final hasResult = state.resultData != null;
    final wordCount = hasResult ? (state.resultData?['word_count'] ?? '--') : '--';
    final chapterCount = hasResult ? (state.resultData?['chapter_count'] ?? state.outline.length) : state.outline.length;

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
        // 审校报告
        _buildReviewReport(state),
        // WebView 预览区
        Expanded(
          child: _buildPreview(state),
        ),
        // 操作按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                    onPressed: state.documentId != null && !state.isExporting
                        ? () => _showExportDialog(context, notifier)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      elevation: 0,
                    ),
                    child: state.isExporting
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
        ),
        const SizedBox(height: 16),
      ],
    );
  }

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

  Widget _buildReviewReport(GenerateState state) {
    final resultData = state.resultData;
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

  Widget _buildPreview(GenerateState state) {
    if (_webViewController == null) {
      // 没有 documentId，显示旧式文本预览 fallback
      return _buildFallbackPreview(state);
    }

    return Stack(
      children: [
        WebViewWidget(controller: _webViewController!),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
      ],
    );
  }

  Widget _buildFallbackPreview(GenerateState state) {
    // 尝试从 dslNodes 渲染内容
    final nodes = state.dslNodes;
    final hasNodes = nodes.isNotEmpty && nodes.values.any((l) => l.isNotEmpty);

    if (hasNodes) {
      final allNodes = <DslNode>[];
      for (final section in state.outline) {
        final sectionNodes = nodes[section.id] ?? [];
        if (sectionNodes.isNotEmpty) {
          allNodes.addAll(sectionNodes);
        }
      }
      // 如果没有 outline 匹配，取 main 或第一个 section
      if (allNodes.isEmpty) {
        final mainNodes = nodes['main'] ?? nodes.values.first;
        allNodes.addAll(mainNodes);
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DslRenderer(nodes: allNodes),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '以上为预览内容，导出 Word 可查看完整排版效果',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 无 DSL 数据时的兜底
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 48, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text('文档已保存，点击导出查看完整排版效果', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context, GenerateNotifier notifier) {
    notifier.selectExportFormat(ExportFormat.docx);
    notifier.exportDocument();
  }
}
