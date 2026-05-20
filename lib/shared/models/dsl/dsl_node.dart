/// DocDSL 节点数据模型 — 与后端 DocDSL 15 种节点对齐
library;

/// DSL 节点类型
enum DslNodeType {
  heading,
  paragraph,
  list,
  table,
  image,
  chart,
  code,
  quote,
  divider,
  field,
  signature,
  officialHeader,
  referenceList,
  section,
  document;

  static DslNodeType fromString(String s) {
    return DslNodeType.values.firstWhere(
      (e) => e.name == s || e.name == _nameMap[s],
      orElse: () => DslNodeType.paragraph,
    );
  }

  static const _nameMap = <String, String>{
    'official_header': 'officialHeader',
    'reference_list': 'referenceList',
  };
}

/// DocDSL 节点 — 通用数据类，支持所有 15 种节点类型
class DslNode {
  final DslNodeType type;

  // heading
  final int? level;

  // heading / paragraph / quote / code
  final String? text;

  // paragraph
  final bool bold;
  final bool italic;

  // list
  final String? style; // ordered / unordered / definition
  final List<dynamic>? items;

  // table
  final List<String>? headers;
  final List<List<String>>? rows;
  final List<Map<String, int>>? merges;

  // image / chart
  final String? url;
  final String? caption;
  final double? width;
  final double? height;
  final Map<String, dynamic>? chartConfig;

  // code
  final String? language;

  // quote
  final String? attribution;

  // divider
  final String? dividerType; // horizontal_rule / page_break

  // field
  final String? name;
  final String? label;
  final String? fieldType;
  final String? defaultValue;
  final bool required;

  // signature
  final List<Map<String, dynamic>>? parties;
  final String? layout;

  // official_header
  final String? issuer;
  final String? docNumber;

  // reference_list
  final List<String>? refItems;
  final String? refStyle;

  // section / document
  final String? id;
  final String? semanticType;
  final String? title;
  final List<DslNode>? children;

  // style hint
  final String? styleHint;

  const DslNode({
    required this.type,
    this.level,
    this.text,
    this.bold = false,
    this.italic = false,
    this.style,
    this.items,
    this.headers,
    this.rows,
    this.merges,
    this.url,
    this.caption,
    this.width,
    this.height,
    this.chartConfig,
    this.language,
    this.attribution,
    this.dividerType,
    this.name,
    this.label,
    this.fieldType,
    this.defaultValue,
    this.required = false,
    this.parties,
    this.layout,
    this.issuer,
    this.docNumber,
    this.refItems,
    this.refStyle,
    this.id,
    this.semanticType,
    this.title,
    this.children,
    this.styleHint,
  });

  /// 创建副本并替换指定字段（用于 update_text 的 O(1) 更新）
  DslNode copyWith({
    String? text,
  }) {
    return DslNode(
      type: type,
      level: level,
      text: text ?? this.text,
      bold: bold,
      italic: italic,
      style: style,
      items: items,
      headers: headers,
      rows: rows,
      merges: merges,
      url: url,
      caption: caption,
      width: width,
      height: height,
      chartConfig: chartConfig,
      language: language,
      attribution: attribution,
      dividerType: dividerType,
      name: name,
      label: label,
      fieldType: fieldType,
      defaultValue: defaultValue,
      required: required,
      parties: parties,
      layout: layout,
      issuer: issuer,
      docNumber: docNumber,
      refItems: refItems,
      refStyle: refStyle,
      id: id,
      semanticType: semanticType,
      title: title,
      children: children,
      styleHint: styleHint,
    );
  }

  factory DslNode.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? 'paragraph';
    final type = DslNodeType.fromString(rawType);

    List<DslNode>? children;
    if (json['children'] != null) {
      children = (json['children'] as List)
          .map((c) => DslNode.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    List<dynamic>? items;
    if (json['items'] != null) {
      items = json['items'] as List;
    }

    List<String>? headers;
    if (json['headers'] != null) {
      headers = List<String>.from(json['headers'] as List);
    }

    List<List<String>>? rows;
    if (json['rows'] != null) {
      rows = (json['rows'] as List)
          .map((r) => List<String>.from(r as List))
          .toList();
    }

    return DslNode(
      type: type,
      level: json['level'] as int?,
      text: json['text'] as String?,
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      style: json['style'] as String?,
      items: items,
      headers: headers,
      rows: rows,
      merges: json['merges'] != null
          ? (json['merges'] as List)
              .map((m) => Map<String, int>.from(m as Map))
              .toList()
          : null,
      url: json['url'] as String?,
      caption: json['caption'] as String?,
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      chartConfig: json['chart_config'] as Map<String, dynamic>?,
      language: json['language'] as String?,
      attribution: json['attribution'] as String?,
      dividerType: json['divider_type'] as String?,
      name: json['name'] as String?,
      label: json['label'] as String?,
      fieldType: json['field_type'] as String?,
      defaultValue: json['default'] as String?,
      required: json['required'] as bool? ?? false,
      parties: json['parties'] != null
          ? (json['parties'] as List).map((p) => Map<String, dynamic>.from(p as Map)).toList()
          : null,
      layout: json['layout'] as String?,
      issuer: json['issuer'] as String?,
      docNumber: json['doc_number'] as String?,
      refItems: json['items'] != null ? List<String>.from(json['items'] as List) : null,
      refStyle: json['style'] as String?,
      id: json['id'] as String?,
      semanticType: json['semantic_type'] as String?,
      title: json['title'] as String?,
      children: children,
      styleHint: json['style_hint'] as String?,
    );
  }

  /// 是否有实际内容可渲染
  bool get hasContent =>
      (text != null && text!.isNotEmpty) ||
      (headers != null && headers!.isNotEmpty) ||
      (items != null && items!.isNotEmpty) ||
      (url != null && url!.isNotEmpty) ||
      (children != null && children!.isNotEmpty);
}

/// DSL Outline 条目
class DslOutline {
  final String id;
  final String title;
  final String status; // pending / generating / completed / failed

  const DslOutline({
    required this.id,
    required this.title,
    this.status = 'pending',
  });

  factory DslOutline.fromJson(Map<String, dynamic> json) => DslOutline(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
      );
}
