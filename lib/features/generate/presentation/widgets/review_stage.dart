import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/models/generate_models.dart';
import '../../domain/providers/generate_provider.dart';
import '../../../../shared/widgets/feature_header.dart';
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
      _initWebView(url);
    }
  }

  Future<void> _initWebView(String url) async {
    final token = await SecureStorage.instance.getToken();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
        onWebResourceError: (e) {
          if (mounted) setState(() => _isLoading = false);
        },
      ))
      ..loadRequest(
        Uri.parse(url),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generateProvider);
    final notifier = ref.read(generateProvider.notifier);

    final title = state.docTitle.isNotEmpty ? state.docTitle : state.selectedType.label;
    final wordCount = state.resultData?['word_count'] ?? 0;
    final chapterCount = state.resultData?['chapter_count'] ?? state.outline.length;

    return Column(
      children: [
        FeatureHeader(
          color: AppColors.success,
          title: '生成完成',
          subtitle: '$title · 共 $chapterCount 章节 · 约 $wordCount 字',
          showBackButton: true,
          onBack: () => notifier.backToGenerating(),
        ),
        _buildSteps(),
        // WebView 预览区
        Expanded(
          child: _buildPreview(state),
        ),
        // 导出格式
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('选择导出格式', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
        ),
        _buildFormatGrid(state, notifier),
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
                        ? () => notifier.exportDocument()
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

  Widget _buildFormatGrid(GenerateState state, GenerateNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ExportFormat.values.map((fmt) {
          final isSelected = state.selectedFormat == fmt;
          final (iconBgColor, iconColor) = switch (fmt) {
            ExportFormat.docx => (AppColors.primaryBg, AppColors.primary),
            ExportFormat.pdf => (AppColors.errorBg, AppColors.error),
            ExportFormat.html => (AppColors.ctaBg, AppColors.cta),
          };
          return Expanded(
            child: GestureDetector(
              onTap: () => notifier.selectExportFormat(fmt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryBg : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: 1.5),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Icon(fmt.icon, size: 20, color: iconColor),
                    ),
                    const SizedBox(height: 6),
                    Text(fmt.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
                    Text(fmt.extension, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
