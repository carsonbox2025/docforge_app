import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../scene/data/models/scene_models.dart';

/// 场景动态表单 — 根据后端 SceneConfig.formFields 动态渲染
class SceneDynamicForm extends StatelessWidget {
  final SceneConfig scene;
  final Map<String, String> fieldValues;
  final void Function(String key, String value) onChanged;

  const SceneDynamicForm({
    super.key,
    required this.scene,
    required this.fieldValues,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: scene.formFields.map((field) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _buildField(field),
        );
      }).toList(),
    );
  }

  Widget _buildField(FormFieldDef field) {
    switch (field.type) {
      case 'select':
        return _SelectField(
          key: ValueKey(field.name),
          field: field,
          value: fieldValues[field.name] ?? '',
          onChanged: (v) => onChanged(field.name, v),
        );
      case 'date':
        return _DateField(
          key: ValueKey(field.name),
          field: field,
          value: fieldValues[field.name] ?? '',
          onChanged: (v) => onChanged(field.name, v),
        );
      case 'textarea':
        return _TextAreaField(
          key: ValueKey(field.name),
          field: field,
          value: fieldValues[field.name] ?? '',
          onChanged: (v) => onChanged(field.name, v),
        );
      default:
        return _TextField(
          key: ValueKey(field.name),
          field: field,
          value: fieldValues[field.name] ?? '',
          onChanged: (v) => onChanged(field.name, v),
        );
    }
  }
}

/// 文本输入字段
class _TextField extends StatefulWidget {
  final FormFieldDef field;
  final String value;
  final ValueChanged<String> onChanged;

  const _TextField({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _TextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      final sel = _controller.selection;
      _controller.text = widget.value;
      if (sel.start >= 0) {
        _controller.selection = sel;
      }
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
        _FieldLabel(label: widget.field.label, required: widget.field.required),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: TextField(
            controller: _controller,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: widget.field.placeholder ?? '请输入${widget.field.label}',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );
  }
}

/// 多行文本字段
class _TextAreaField extends StatefulWidget {
  final FormFieldDef field;
  final String value;
  final ValueChanged<String> onChanged;

  const _TextAreaField({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_TextAreaField> createState() => _TextAreaFieldState();
}

class _TextAreaFieldState extends State<_TextAreaField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _TextAreaField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      final sel = _controller.selection;
      _controller.text = widget.value;
      if (sel.start >= 0) {
        _controller.selection = sel;
      }
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
        _FieldLabel(label: widget.field.label, required: widget.field.required, fontSize: 15),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 180),
          child: TextField(
            controller: _controller,
            maxLines: null,
            minLines: 6,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.6),
            decoration: InputDecoration(
              hintText: widget.field.placeholder ?? '请描述${widget.field.label}',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.6),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );
  }
}

/// 下拉选择字段
class _SelectField extends StatelessWidget {
  final FormFieldDef field;
  final String value;
  final ValueChanged<String> onChanged;

  const _SelectField({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: field.label, required: field.required),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value.isEmpty ? null : value,
              hint: Text(
                '请选择${field.label}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.textMuted),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text),
              items: (field.options ?? []).map((opt) {
                return DropdownMenuItem(value: opt, child: Text(opt));
              }).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 日期选择字段
class _DateField extends StatelessWidget {
  final FormFieldDef field;
  final String value;
  final ValueChanged<String> onChanged;

  const _DateField({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: field.label, required: field.required),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final initial = value.isNotEmpty
                ? DateTime.tryParse(value) ?? DateTime.now()
                : DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              locale: const Locale('zh', 'CN'),
            );
            if (picked != null) {
              onChanged('${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
            }
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? (field.placeholder ?? '请选择${field.label}') : value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: value.isEmpty ? AppColors.textMuted : AppColors.text,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 字段标签
class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  final double fontSize;

  const _FieldLabel({required this.label, required this.required, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        if (required)
          Text(' *', style: TextStyle(fontSize: fontSize, color: AppColors.error)),
      ],
    );
  }
}
