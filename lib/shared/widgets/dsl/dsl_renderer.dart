// DocDSL 统一渲染器 — 将 DslNode 列表渲染为 Flutter Widget 树
//
// 支持流式模式（最后一个 paragraph 显示打字光标）
// 支持所有 15 种节点类型的渲染

import 'package:flutter/material.dart';
import '../../models/dsl/dsl_node.dart';
import '../../../core/constants/app_colors.dart';
import 'inline_markdown.dart';

class DslRenderer extends StatelessWidget {
  final List<DslNode> nodes;
  final bool isStreaming;

  const DslRenderer({
    super.key,
    required this.nodes,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      if (isStreaming) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(),
                SizedBox(height: 12),
                Text('AI 正在思考...', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final widgets = <Widget>[];
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final isLast = i == nodes.length - 1;
      widgets.add(_buildNode(node, isLast: isLast));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildNode(DslNode node, {bool isLast = false}) {
    switch (node.type) {
      case DslNodeType.heading:
        return _HeadingWidget(node: node);
      case DslNodeType.paragraph:
        return _ParagraphWidget(node: node, isStreaming: isLast && isStreaming);
      case DslNodeType.table:
        return _TableWidget(node: node);
      case DslNodeType.list:
        return _ListWidget(node: node, isStreaming: isLast && isStreaming);
      case DslNodeType.code:
        return _CodeWidget(node: node);
      case DslNodeType.quote:
        return _QuoteWidget(node: node);
      case DslNodeType.image:
        return _ImageWidget(node: node);
      case DslNodeType.chart:
        return _ChartWidget(node: node);
      case DslNodeType.divider:
        return const Divider(height: 24, thickness: 1, color: AppColors.border);
      case DslNodeType.section:
        return _SectionWidget(node: node, isStreaming: isStreaming);
      default:
        // fallback: 用 paragraph 渲染
        if (node.text != null && node.text!.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(node.text!, style: const TextStyle(fontSize: 13, height: 1.8, color: AppColors.text)),
          );
        }
        return const SizedBox.shrink();
    }
  }
}

// ─── Heading ───

class _HeadingWidget extends StatelessWidget {
  final DslNode node;
  const _HeadingWidget({required this.node});

  @override
  Widget build(BuildContext context) {
    final level = node.level ?? 2;
    final style = switch (level) {
      1 => const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text, height: 1.4),
      2 => const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.4),
      3 => const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.5),
      _ => const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.5),
    };
    return Padding(
      padding: EdgeInsets.only(top: level <= 2 ? 16 : 12, bottom: 8),
      child: Text(node.text ?? '', style: style),
    );
  }
}

// ─── Paragraph ───

class _ParagraphWidget extends StatefulWidget {
  final DslNode node;
  final bool isStreaming;
  const _ParagraphWidget({required this.node, this.isStreaming = false});

  @override
  State<_ParagraphWidget> createState() => _ParagraphWidgetState();
}

class _ParagraphWidgetState extends State<_ParagraphWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorCtrl;

  String? _cachedText;
  InlineSpan? _cachedSpan;

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat();
  }

  @override
  void dispose() {
    _cursorCtrl.dispose();
    super.dispose();
  }

  InlineSpan _parseWithCache(String text, TextStyle baseStyle) {
    if (text == _cachedText && _cachedSpan != null) {
      return _cachedSpan!;
    }
    _cachedText = text;
    _cachedSpan = parseInlineMarkdown(text, baseStyle: baseStyle);
    return _cachedSpan!;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.node.text ?? '';
    if (text.isEmpty && !widget.isStreaming) return const SizedBox.shrink();

    final baseStyle = TextStyle(
      fontSize: 13,
      fontWeight: widget.node.bold ? FontWeight.w600 : FontWeight.w500,
      fontStyle: widget.node.italic ? FontStyle.italic : FontStyle.normal,
      height: 1.8,
      color: AppColors.text,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: RichText(
              text: _parseWithCache(text, baseStyle),
            ),
          ),
          if (widget.isStreaming)
            FadeTransition(
              opacity: TweenSequence<double>([
                TweenSequenceItem(tween: ConstantTween(1.0), weight: 0.5),
                TweenSequenceItem(tween: ConstantTween(0.0), weight: 0.5),
              ]).animate(_cursorCtrl),
              child: Container(
                width: 2,
                height: 14,
                margin: const EdgeInsets.only(left: 2),
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Table ───

class _TableWidget extends StatelessWidget {
  final DslNode node;
  const _TableWidget({required this.node});

  @override
  Widget build(BuildContext context) {
    final headers = node.headers ?? [];
    final rows = node.rows ?? [];
    if (headers.isEmpty && rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: {
          for (int i = 0; i < headers.length; i++)
            i: const FlexColumnWidth(),
        },
        children: [
          if (headers.isNotEmpty)
            TableRow(
              decoration: const BoxDecoration(color: AppColors.surfaceHover),
              children: headers.map((h) => _cell(h, isHeader: true)).toList(),
            ),
          ...rows.map((row) => TableRow(
                children: row.map((c) => _cell(c)).toList(),
              )),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool isHeader = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.text,
          ),
        ),
      );
}

// ─── List ───

class _ListWidget extends StatelessWidget {
  final DslNode node;
  final bool isStreaming;
  const _ListWidget({required this.node, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final items = node.items ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

    final isOrdered = node.style == 'ordered';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOrdered ? '${i + 1}. ' : '• ',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  Expanded(
                    child: Text(
                      items[i].toString(),
                      style: const TextStyle(fontSize: 13, height: 1.7, color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Code ───

class _CodeWidget extends StatelessWidget {
  final DslNode node;
  const _CodeWidget({required this.node});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        node.text ?? '',
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.6,
          color: AppColors.text,
        ),
      ),
    );
  }
}

// ─── Quote ───

class _QuoteWidget extends StatelessWidget {
  final DslNode node;
  const _QuoteWidget({required this.node});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.border, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            node.text ?? '',
            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.textSecondary, height: 1.7),
          ),
          if (node.attribution != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '— ${node.attribution}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Image ───

class _ImageWidget extends StatelessWidget {
  final DslNode node;
  const _ImageWidget({required this.node});

  @override
  Widget build(BuildContext context) {
    final url = node.url;
    final hasUrl = url != null && url.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: AppColors.surfaceHover,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasUrl
                ? Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _imagePlaceholder(Icons.broken_image, '图片加载失败'),
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      final total = loadingProgress.expectedTotalBytes;
                      return _imagePlaceholder(
                        Icons.hourglass_top,
                        '加载中 ${total != null ? "${(loadingProgress.cumulativeBytesLoaded / total * 100).round()}%" : ""}',
                      );
                    },
                  )
                : _imagePlaceholder(Icons.image_outlined, '图片生成中...'),
          ),
          if (node.caption != null && node.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(node.caption!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(IconData icon, String text) {
    return Container(
      height: 120,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: AppColors.textMuted),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ─── Chart ───

class _ChartWidget extends StatelessWidget {
  final DslNode node;
  const _ChartWidget({required this.node});

  @override
  Widget build(BuildContext context) {
    final url = node.url;
    final hasUrl = url != null && url.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceHover,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasUrl
                ? Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _chartPlaceholder(),
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _chartPlaceholder();
                    },
                  )
                : _chartPlaceholder(),
          ),
          if (node.caption != null && node.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(node.caption!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }

  Widget _chartPlaceholder() {
    return Container(
      height: 160,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart_outlined, size: 32, color: AppColors.textMuted),
          const SizedBox(height: 4),
          Text(node.caption ?? '图表', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ─── Section ───

class _SectionWidget extends StatelessWidget {
  final DslNode node;
  final bool isStreaming;
  const _SectionWidget({required this.node, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final children = node.children ?? [];
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (node.title != null && node.title!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              node.title!,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
        DslRenderer(nodes: children, isStreaming: isStreaming),
      ],
    );
  }
}

// ─── Pulse Dot ───

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 0.5),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: 0.5),
      ]).animate(_controller),
      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
    );
  }
}
