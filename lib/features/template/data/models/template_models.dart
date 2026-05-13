import 'package:flutter/material.dart';

/// 模板分类
enum TemplateCategory {
  all('全部', Icons.apps),
  contract('合同', Icons.description_outlined),
  official('公文', Icons.account_balance_outlined),
  report('报告', Icons.insert_chart_outlined),
  paper('论文', Icons.menu_book_outlined),
  resume('简历', Icons.person_outline),
  bid('标书', Icons.bar_chart_outlined),
  minutes('纪要', Icons.groups_outlined);

  const TemplateCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 模板缩略图颜色配置
class TemplateColorScheme {
  final Color primary;
  final Color light;
  final Color bg;

  const TemplateColorScheme({
    required this.primary,
    required this.light,
    required this.bg,
  });

  static const List<TemplateColorScheme> schemes = [
    TemplateColorScheme(primary: Color(0xFF2563EB), light: Color(0xFF3B82F6), bg: Color(0xFFDBEAFE)),
    TemplateColorScheme(primary: Color(0xFF10B981), light: Color(0xFF34D399), bg: Color(0xFFD1FAE5)),
    TemplateColorScheme(primary: Color(0xFFF97316), light: Color(0xFFFB923C), bg: Color(0xFFFED7AA)),
    TemplateColorScheme(primary: Color(0xFF7C3AED), light: Color(0xFF8B5CF6), bg: Color(0xFFDDD6FE)),
    TemplateColorScheme(primary: Color(0xFFEF4444), light: Color(0xFFF87171), bg: Color(0xFFFECACA)),
    TemplateColorScheme(primary: Color(0xFF06B6D4), light: Color(0xFF22D3EE), bg: Color(0xFFA5F3FC)),
    TemplateColorScheme(primary: Color(0xFFF59E0B), light: Color(0xFFFBBF24), bg: Color(0xFFFDE68A)),
    TemplateColorScheme(primary: Color(0xFFEC4899), light: Color(0xFFF472B6), bg: Color(0xFFFBCFE8)),
  ];
}

/// 模板模型
class Template {
  final String id;
  final String name;
  final TemplateCategory category;
  final int documentCount;
  final String description;
  final TemplateColorScheme colorScheme;
  final List<String> tags;
  final bool requirePro;

  const Template({
    required this.id,
    required this.name,
    required this.category,
    required this.documentCount,
    this.description = '',
    required this.colorScheme,
    this.tags = const [],
    this.requirePro = false,
  });
}
