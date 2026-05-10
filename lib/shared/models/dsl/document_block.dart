import 'dart:convert';

/// Block DSL 数据模型 — 对齐 web 端 docGeneration.ts

// ============================================================================
// Block 类型与数据模型
// ============================================================================

enum BlockType {
  heading,
  paragraph,
  table,
  image,
  quote,
  list,
  callout,
  chart,
  code;

  static BlockType fromString(String s) {
    return BlockType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => BlockType.paragraph,
    );
  }
}

enum RenderStatus { pending, rendering, done, failed }

class DocumentBlock {
  final String id;
  final BlockType type;
  final String? text;
  final int? level;
  final List<String>? headers;
  final List<List<String>>? rows;
  final String? caption;
  final String? url;
  final String? prompt;
  final String? source;
  final List<String>? items;
  final List<List<String>>? children;
  final String? style;
  final String? icon;
  final Map<String, dynamic>? chartConfig;
  final String? language;
  final RenderStatus? renderStatus;
  final Map<String, dynamic>? metadata;

  const DocumentBlock({
    required this.id,
    required this.type,
    this.text,
    this.level,
    this.headers,
    this.rows,
    this.caption,
    this.url,
    this.prompt,
    this.source,
    this.items,
    this.children,
    this.style,
    this.icon,
    this.chartConfig,
    this.language,
    this.renderStatus,
    this.metadata,
  });

  DocumentBlock copyWith({
    String? text,
    int? level,
    List<String>? headers,
    List<List<String>>? rows,
    String? caption,
    String? url,
    String? prompt,
    String? source,
    List<String>? items,
    List<List<String>>? children,
    String? style,
    String? icon,
    Map<String, dynamic>? chartConfig,
    String? language,
    RenderStatus? renderStatus,
    Map<String, dynamic>? metadata,
  }) {
    return DocumentBlock(
      id: id,
      type: type,
      text: text ?? this.text,
      level: level ?? this.level,
      headers: headers ?? this.headers,
      rows: rows ?? this.rows,
      caption: caption ?? this.caption,
      url: url ?? this.url,
      prompt: prompt ?? this.prompt,
      source: source ?? this.source,
      items: items ?? this.items,
      children: children ?? this.children,
      style: style ?? this.style,
      icon: icon ?? this.icon,
      chartConfig: chartConfig ?? this.chartConfig,
      language: language ?? this.language,
      renderStatus: renderStatus ?? this.renderStatus,
      metadata: metadata ?? this.metadata,
    );
  }
}

// ============================================================================
// 流式 Block（实时累积状态）
// ============================================================================

class StreamingBlock {
  final String id;
  final String type;
  String content;
  String status; // streaming | complete
  Map<String, dynamic>? data;
  Map<String, String>? attrs;
  String? url;
  String? renderStatus;

  StreamingBlock({
    required this.id,
    required this.type,
    this.content = '',
    this.status = 'streaming',
    this.data,
    this.attrs,
    this.url,
    this.renderStatus,
  });

  DocumentBlock toDocumentBlock() {
    // 从 attrs 解析
    int? level;
    String? style;
    String? icon;
    if (attrs != null) {
      if (attrs!['level'] != null) level = int.tryParse(attrs!['level']!);
      if (attrs!['style'] != null) style = attrs!['style'];
      if (attrs!['icon'] != null) icon = attrs!['icon'];
    }

    // 从 data 解析
    List<String>? headers;
    List<List<String>>? rows;
    String? caption;
    String? url;
    String? source;
    List<String>? items;
    List<List<String>>? children;
    Map<String, dynamic>? chartConfig;
    String? language;
    RenderStatus? renderStatus;

    if (data != null) {
      final d = data!;
      if (d['headers'] != null) headers = List<String>.from(d['headers']);
      if (d['rows'] != null) rows = (d['rows'] as List).map((r) => List<String>.from(r)).toList();
      if (d['caption'] != null) caption = d['caption'] as String;
      if (d['url'] != null) url = d['url'] as String;
      if (d['prompt'] != null) caption ??= d['prompt'] as String;
      if (d['source'] != null) source = d['source'] as String;
      if (d['items'] != null) items = List<String>.from(d['items']);
      if (d['children'] != null) children = (d['children'] as List).map((r) => List<String>.from(r)).toList();
      if (d['chart_config'] != null) {
        if (d['chart_config'] is Map<String, dynamic>) {
          chartConfig = Map<String, dynamic>.from(d['chart_config']);
        } else if (d['chart_config'] is String) {
          try {
            chartConfig = jsonDecode(d['chart_config'] as String) as Map<String, dynamic>;
          } catch (_) {
            chartConfig = <String, dynamic>{'raw': d['chart_config']};
          }
        }
      }
      if (d['language'] != null) language = d['language'] as String;
      if (d['render_status'] != null) {
        renderStatus = RenderStatus.values.firstWhere(
          (e) => e.name == d['render_status'],
          orElse: () => RenderStatus.pending,
        );
      }
      if (d['style'] != null) style ??= d['style'] as String;
    }
    if (this.url != null) url ??= this.url;
    if (this.renderStatus != null) {
      renderStatus ??= RenderStatus.values.firstWhere(
        (e) => e.name == this.renderStatus,
        orElse: () => RenderStatus.pending,
      );
    }

    return DocumentBlock(
      id: id,
      type: BlockType.fromString(type),
      text: (content.trim().isEmpty && (data?['text'] as String?)?.trim().isEmpty != false)
          ? null
          : (content.isNotEmpty ? content : data?['text'] as String?),
      level: level,
      headers: headers,
      rows: rows,
      caption: caption,
      url: url,
      prompt: null,
      source: source,
      items: items,
      children: children,
      style: style,
      icon: icon,
      chartConfig: chartConfig,
      language: language,
      renderStatus: renderStatus,
    );
  }
}

// ============================================================================
// 章节与文档结果
// ============================================================================

class ChapterDoc {
  final String chapterId;
  final String title;
  final List<DocumentBlock> blocks;
  final int wordCount;
  final List<String>? dataSources;

  const ChapterDoc({
    required this.chapterId,
    required this.title,
    required this.blocks,
    this.wordCount = 0,
    this.dataSources,
  });
}

class DocumentResult {
  final String documentTitle;
  final List<ChapterDoc> chapters;
  final int? totalWordCount;
  final int? totalBlocks;

  const DocumentResult({
    required this.documentTitle,
    required this.chapters,
    this.totalWordCount,
    this.totalBlocks,
  });

  factory DocumentResult.fromJson(Map<String, dynamic> json) {
    return DocumentResult(
      documentTitle: json['document_title'] as String? ?? '',
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((ch) => ChapterDoc(
                    chapterId: ch['chapter_id'] as String? ?? '',
                    title: ch['title'] as String? ?? '',
                    blocks: (ch['blocks'] as List<dynamic>?)
                            ?.map((b) => _parseBlock(b as Map<String, dynamic>))
                            .toList() ??
                        [],
                    wordCount: ch['word_count'] as int? ?? 0,
                    dataSources: (ch['data_sources'] as List<dynamic>?)
                        ?.map((e) => e.toString())
                        .toList(),
                  ))
              .toList() ??
          [],
      totalWordCount: json['total_word_count'] as int?,
      totalBlocks: json['total_blocks'] as int?,
    );
  }
}

DocumentBlock _parseBlock(Map<String, dynamic> b) {
  return DocumentBlock(
    id: b['id'] as String? ?? '',
    type: BlockType.fromString(b['type'] as String? ?? 'paragraph'),
    text: b['text'] as String?,
    level: b['level'] as int?,
    headers: (b['headers'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    rows: (b['rows'] as List<dynamic>?)
        ?.map((r) => (r as List<dynamic>).map((c) => c.toString()).toList())
        .toList(),
    caption: b['caption'] as String?,
    url: b['url'] as String?,
    items: (b['items'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    children: (b['children'] as List<dynamic>?)
        ?.map((r) => (r as List<dynamic>).map((c) => c.toString()).toList())
        .toList(),
    style: b['style'] as String?,
    chartConfig: b['chart_config'] is Map<String, dynamic> ? b['chart_config'] : null,
    language: b['language'] as String?,
    icon: b['icon'] as String?,
    renderStatus: b['render_status'] != null
        ? RenderStatus.values.firstWhere(
            (e) => e.name == b['render_status'],
            orElse: () => RenderStatus.pending,
          )
        : null,
  );
}

// ============================================================================
// 大纲与状态类型
// ============================================================================

enum GenerationStatus { idle, planning, generating, aggregating, complete, error }

enum ChapterStatus { pending, generating, completed, failed, retrying }

enum PlanningPhase { analyzing, structuring, detailing, optimizing, complete }

class OutlineItem {
  final String chapterId;
  final String title;
  ChapterStatus status;
  String? taskId;
  String? agentName;
  String? agentStatusMsg;

  OutlineItem({
    required this.chapterId,
    required this.title,
    this.status = ChapterStatus.pending,
    this.taskId,
    this.agentName,
    this.agentStatusMsg,
  });
}
