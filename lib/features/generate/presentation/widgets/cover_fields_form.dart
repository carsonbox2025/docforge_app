import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../scene/data/models/scene_models.dart';

/// Layer 2 封面字段表单 — 论文/技术方案的元数据输入
class CoverFieldsForm extends StatelessWidget {
  final List<FieldRegion> fieldRegions;
  final Map<String, String> fieldValues;
  final void Function(String key, String value) onChanged;

  const CoverFieldsForm({
    super.key,
    required this.fieldRegions,
    required this.fieldValues,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (fieldRegions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 折叠标题
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Icon(Icons.article_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                '封面信息',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
              const SizedBox(width: 4),
              Text(
                '（${fieldRegions.where((r) => r.required).length}项必填）',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 封面字段网格（两列布局）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: fieldRegions.map((region) {
              final width = _isLongField(region.regionId) ? double.infinity : (MediaQuery.of(context).size.width - 40) / 2;
              return SizedBox(
                width: width,
                child: _CoverField(
                  label: _fieldLabel(region.regionId),
                  required: region.required,
                  value: fieldValues[region.regionId] ?? '',
                  onChanged: (v) => onChanged(region.regionId, v),
                ),
              );
            }).toList(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Divider(height: 1, thickness: 1, color: AppColors.borderLight),
        ),
      ],
    );
  }

  bool _isLongField(String regionId) {
    return regionId == 'title' || regionId == 'project_name';
  }

  String _fieldLabel(String regionId) => switch (regionId) {
        'title' => '论文标题',
        'subtitle' => '副标题',
        'author' => '作者姓名',
        'student_id' => '学号',
        'supervisor' => '指导教师',
        'major' => '专业',
        'date' => '提交日期',
        'declaration_date' => '声明日期',
        'project_name' => '项目名称',
        'version' => '版本号',
        'reviewer' => '审核人',
        _ => regionId,
      };
}

class _CoverField extends StatefulWidget {
  final String label;
  final bool required;
  final String value;
  final ValueChanged<String> onChanged;

  const _CoverField({
    required this.label,
    required this.required,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_CoverField> createState() => _CoverFieldState();
}

class _CoverFieldState extends State<_CoverField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _CoverField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      final sel = _controller.selection;
      _controller.text = widget.value;
      if (sel.start >= 0) _controller.selection = sel;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
            if (widget.required)
              const Text(' *', style: TextStyle(fontSize: 12, color: AppColors.error)),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: TextField(
            controller: _controller,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );
  }
}
