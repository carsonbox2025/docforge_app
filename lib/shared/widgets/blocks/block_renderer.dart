import 'package:flutter/material.dart';
import '../../models/dsl/document_block.dart';
import '../../../core/constants/app_colors.dart';

class BlockRenderer extends StatelessWidget {
  final DocumentBlock block;
  final bool isStreaming;
  final int chapterIndex;
  final int h3Counter;
  final int h4Counter;

  const BlockRenderer({
    super.key,
    required this.block,
    this.isStreaming = false,
    this.chapterIndex = 0,
    this.h3Counter = 0,
    this.h4Counter = 0,
  });

  @override
  Widget build(BuildContext context) {
    return switch (block.type) {
      BlockType.heading => _HeadingBlock(
          block: block,
          isStreaming: isStreaming,
          chapterIndex: chapterIndex,
          h3Counter: h3Counter,
          h4Counter: h4Counter,
        ),
      BlockType.paragraph => _ParagraphBlock(block: block, isStreaming: isStreaming),
      BlockType.table => _TableBlock(block: block),
      BlockType.list => _ListBlock(block: block),
      BlockType.quote => _QuoteBlock(block: block, isStreaming: isStreaming),
      BlockType.callout => _CalloutBlock(block: block),
      BlockType.code => _CodeBlock(block: block, isStreaming: isStreaming),
      BlockType.image => _ImageBlock(block: block),
      BlockType.chart => _ChartBlock(block: block),
    };
  }
}

// ============================================================================
// Heading
// ============================================================================

class _HeadingBlock extends StatelessWidget {
  final DocumentBlock block;
  final bool isStreaming;
  final int chapterIndex;
  final int h3Counter;
  final int h4Counter;

  const _HeadingBlock({
    required this.block,
    this.isStreaming = false,
    this.chapterIndex = 0,
    this.h3Counter = 0,
    this.h4Counter = 0,
  });

  @override
  Widget build(BuildContext context) {
    final level = block.level ?? 2;
    final rawText = block.text ?? '';

    // 构建编号前缀（仅在 h3/h4 且有 counter 时添加）
    final prefix = _buildPrefix(level);
    final displayText = prefix.isNotEmpty ? '$prefix $rawText' : rawText;

    final style = switch (level) {
      1 => const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text, height: 1.5),
      2 => const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.5),
      3 => const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.4),
      _ => const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.4),
    };

    final padding = switch (level) {
      1 => const EdgeInsets.only(top: 16, bottom: 8),
      2 => const EdgeInsets.only(top: 12, bottom: 6),
      _ => const EdgeInsets.only(top: 8, bottom: 4),
    };

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(displayText, style: style)),
          if (isStreaming) const _StreamingCursor(),
        ],
      ),
    );
  }

  String _buildPrefix(int level) {
    // h3: chapterIndex.1, chapterIndex.2, ...
    // h4: chapterIndex.h3Counter.1, chapterIndex.h3Counter.2, ...
    if (level == 3 && h3Counter > 0) {
      return '$chapterIndex.$h3Counter';
    }
    if (level == 4 && h3Counter > 0) {
      return '$chapterIndex.$h3Counter.$h4Counter';
    }
    return '';
  }
}

// ============================================================================
// Paragraph
// ============================================================================

class _ParagraphBlock extends StatelessWidget {
  final DocumentBlock block;
  final bool isStreaming;

  const _ParagraphBlock({required this.block, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final text = block.text ?? '';
    if (text.trim().isEmpty && !isStreaming) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.7),
            ),
          ),
          if (isStreaming) const _StreamingCursor(),
        ],
      ),
    );
  }
}

// ============================================================================
// Table
// ============================================================================

class _TableBlock extends StatelessWidget {
  final DocumentBlock block;
  const _TableBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final headers = block.headers ?? [];
    final rows = block.rows ?? [];
    if (headers.isEmpty && rows.isEmpty) return const SizedBox.shrink();

    final allCols = headers.isNotEmpty ? headers.length : (rows.isNotEmpty ? rows[0].length : 0);
    if (allCols == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Table(
          columnWidths: {for (var i = 0; i < allCols; i++) i: const FlexColumnWidth()},
          children: [
            if (headers.isNotEmpty)
              TableRow(
                decoration: const BoxDecoration(color: AppColors.surface),
                children: headers.map((h) => _cell(h, isHeader: true)).toList(),
              ),
            ...rows.map((row) => TableRow(
                  children: [
                    ...row.map((c) => _cell(c)),
                    if (row.length < allCols) ...List.generate(allCols - row.length, (_) => _cell('')),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.text,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

// ============================================================================
// List
// ============================================================================

class _ListBlock extends StatelessWidget {
  final DocumentBlock block;
  const _ListBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final items = block.items ?? [];
    final isOrdered = block.style == 'ordered';
    final subChildren = block.children;

    if (items.isEmpty) return const SizedBox.shrink();

    final List<Widget> widgets = [];
    for (var i = 0; i < items.length; i++) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOrdered ? '${i + 1}. ' : '• ',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            Expanded(
              child: Text(items[i], style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.5)),
            ),
          ],
        ),
      ));
      if (subChildren != null && i < subChildren.length && subChildren[i].isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: subChildren[i]
                .map((sub) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          Expanded(child: Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.text, height: 1.4))),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets),
    );
  }
}

// ============================================================================
// Quote
// ============================================================================

class _QuoteBlock extends StatelessWidget {
  final DocumentBlock block;
  final bool isStreaming;
  const _QuoteBlock({required this.block, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final text = block.text ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
        color: AppColors.surface,
        borderRadius: BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.6, fontStyle: FontStyle.italic)),
          ),
          if (isStreaming) const _StreamingCursor(),
        ],
      ),
    );
  }
}

// ============================================================================
// Callout
// ============================================================================

class _CalloutBlock extends StatelessWidget {
  final DocumentBlock block;
  const _CalloutBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final text = block.text ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡 ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Code
// ============================================================================

class _CodeBlock extends StatelessWidget {
  final DocumentBlock block;
  final bool isStreaming;
  const _CodeBlock({required this.block, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final text = block.text ?? '';
    if (text.trim().isEmpty && !isStreaming) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFFD4D4D4), fontFamily: 'monospace', height: 1.5),
            ),
          ),
          if (isStreaming) const _StreamingCursor(color: Color(0xFFD4D4D4)),
        ],
      ),
    );
  }
}

// ============================================================================
// Image
// ============================================================================

class _ImageBlock extends StatelessWidget {
  final DocumentBlock block;
  const _ImageBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final url = block.url;
    final caption = block.caption;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (url != null && url.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(url, fit: BoxFit.contain),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border, style: BorderStyle.solid),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined, size: 28, color: AppColors.textMuted),
                    SizedBox(height: 4),
                    Text('图片加载中...', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(caption, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// Chart
// ============================================================================

class _ChartBlock extends StatelessWidget {
  final DocumentBlock block;
  const _ChartBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final url = block.url;
    final caption = block.caption;

    final isFailed = block.renderStatus == RenderStatus.failed;
    final isRendering = block.renderStatus == RenderStatus.rendering || (url == null && block.chartConfig != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (url != null && url.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(url, fit: BoxFit.contain),
            )
          else if (isFailed)
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 24, color: Color(0xFFEF4444)),
                    SizedBox(height: 4),
                    Text('图表渲染失败', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                  ],
                ),
              ),
            )
          else if (isRendering)
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(height: 6),
                    Text('图表渲染中...', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(caption, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 流式光标
// ============================================================================

class _StreamingCursor extends StatefulWidget {
  final Color color;
  const _StreamingCursor({this.color = AppColors.primary});

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 530))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Text('▌', style: TextStyle(fontSize: 14, color: widget.color, fontWeight: FontWeight.w400)),
    );
  }
}
