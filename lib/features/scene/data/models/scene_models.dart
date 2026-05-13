/// 场景模块数据模型 — 对接后端 SceneConfig

/// 表单字段定义（后端 SceneConfig.form_fields 驱动）
class FormFieldDef {
  final String name;
  final String label;
  final String type; // text / textarea / select / date
  final bool required;
  final List<String>? options;
  final String? placeholder;

  const FormFieldDef({
    required this.name,
    required this.label,
    required this.type,
    this.required = true,
    this.options,
    this.placeholder,
  });

  factory FormFieldDef.fromJson(Map<String, dynamic> json) => FormFieldDef(
        name: json['name'] as String? ?? '',
        label: json['label'] as String? ?? '',
        type: json['type'] as String? ?? 'text',
        required: json['required'] as bool? ?? true,
        options: (json['options'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
        placeholder: json['placeholder'] as String?,
      );
}

/// 定价信息
class PricingInfo {
  final String type; // free / per_doc
  final double price;

  const PricingInfo({required this.type, this.price = 0});

  factory PricingInfo.fromJson(Map<String, dynamic> json) => PricingInfo(
        type: json['type'] as String? ?? 'free',
        price: (json['price'] as num?)?.toDouble() ?? 0,
      );

  bool get isFree => type == 'free';
  String get displayPrice => isFree ? '免费' : '¥${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 1)}';
}

/// 封面字段区域（从模板配置的 regions 中提取 type=field 的条目）
class FieldRegion {
  final String regionId;
  final String bookmark;
  final bool required;

  const FieldRegion({
    required this.regionId,
    required this.bookmark,
    this.required = true,
  });

  factory FieldRegion.fromJson(String id, Map<String, dynamic> json) =>
      FieldRegion(
        regionId: id,
        bookmark: json['bookmark'] as String? ?? '',
        required: json['required'] as bool? ?? true,
      );

  /// 从 regions 中提取所有 field 类型的区域
  static List<FieldRegion> fromRegions(Map<String, dynamic> regions) {
    return regions.entries
        .where((e) {
          final v = e.value;
          if (v is Map<String, dynamic>) return v['type'] == 'field';
          return false;
        })
        .map((e) => FieldRegion.fromJson(e.key, e.value as Map<String, dynamic>))
        .toList();
  }
}

/// 场景配置（对应后端 SceneConfig）
class SceneConfig {
  final String sceneId;
  final String name;
  final String docType;
  final String templateId;
  final int layer; // 1=标准文档, 2=长文档
  final PricingInfo pricing;
  final List<FormFieldDef> formFields;
  final List<String> reviewRules;

  const SceneConfig({
    required this.sceneId,
    required this.name,
    required this.docType,
    required this.templateId,
    this.layer = 1,
    this.pricing = const PricingInfo(type: 'free'),
    this.formFields = const [],
    this.reviewRules = const [],
    this.coverFieldRegions = const [],
  });

  factory SceneConfig.fromJson(Map<String, dynamic> json) {
    final pricingRaw = json['pricing'];
    final PricingInfo pricing;
    if (pricingRaw is Map<String, dynamic>) {
      pricing = PricingInfo.fromJson(pricingRaw);
    } else {
      pricing = const PricingInfo(type: 'free');
    }

    // 解析封面字段：优先从 cover_field_regions，否则从 regions 中提取
    List<FieldRegion> coverRegions = [];
    final coverRaw = json['cover_field_regions'];
    if (coverRaw is List) {
      coverRegions = coverRaw
          .map((e) => FieldRegion.fromJson(
                e['region_id'] as String? ?? '',
                e as Map<String, dynamic>,
              ))
          .toList();
    } else {
      final regionsRaw = json['regions'];
      if (regionsRaw is Map<String, dynamic>) {
        coverRegions = FieldRegion.fromRegions(regionsRaw);
      }
    }

    return SceneConfig(
      sceneId: json['scene_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      docType: json['doc_type'] as String? ?? 'generic',
      templateId: json['template_id'] as String? ?? '',
      layer: json['layer'] as int? ?? 1,
      pricing: pricing,
      formFields: (json['form_fields'] as List<dynamic>?)
              ?.map((e) => FormFieldDef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      reviewRules: (json['review_rules'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      coverFieldRegions: coverRegions,
    );
  }

  bool get isLayer2 => layer == 2;

  /// 封面字段列表（Layer 2 场景专用）
  /// 从后端模板 regions 中动态获取 type=field 的条目
  final List<FieldRegion> coverFieldRegions;

  Map<String, dynamic> toJson() => {
        'scene_id': sceneId,
        'name': name,
        'doc_type': docType,
        'template_id': templateId,
        'layer': layer,
        'pricing': {'type': pricing.type, 'price': pricing.price},
        'form_fields': formFields.map((f) => {
              'name': f.name,
              'label': f.label,
              'type': f.type,
              'required': f.required,
              if (f.options != null) 'options': f.options,
              if (f.placeholder != null) 'placeholder': f.placeholder,
            }).toList(),
        'review_rules': reviewRules,
      };
}
