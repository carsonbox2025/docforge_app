/// 行内 Markdown 解析器 — 将 **bold**、*italic*、`code`、[link](url) 解析为 TextSpan
library;

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// 将包含行内 Markdown 的文本解析为 InlineSpan 列表
InlineSpan parseInlineMarkdown(String text, {TextStyle? baseStyle}) {
  baseStyle ??= const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.8, color: AppColors.text);

  final spans = <TextSpan>[];
  final buffer = StringBuffer();
  int i = 0;

  void flushBuffer() {
    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString(), style: baseStyle));
      buffer.clear();
    }
  }

  while (i < text.length) {
    // **bold** or __bold__
    if ((text[i] == '*' && i + 1 < text.length && text[i + 1] == '*') ||
        (text[i] == '_' && i + 1 < text.length && text[i + 1] == '_')) {
      final marker = text.substring(i, i + 2);
      final end = text.indexOf(marker, i + 2);
      if (end != -1) {
        flushBuffer();
        spans.add(TextSpan(
          text: text.substring(i + 2, end),
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ));
        i = end + 2;
        continue;
      }
    }

    // *italic* (single, not preceded/followed by *)
    if (text[i] == '*' && (i + 1 >= text.length || text[i + 1] != '*') &&
        (i == 0 || text[i - 1] != '*')) {
      final end = text.indexOf('*', i + 1);
      if (end != -1 && (end + 1 >= text.length || text[end + 1] != '*')) {
        flushBuffer();
        spans.add(TextSpan(
          text: text.substring(i + 1, end),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
        i = end + 1;
        continue;
      }
    }

    // `inline code`
    if (text[i] == '`') {
      final end = text.indexOf('`', i + 1);
      if (end != -1) {
        flushBuffer();
        spans.add(TextSpan(
          text: text.substring(i + 1, end),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: const Color(0xFFF0F0F0),
            color: const Color(0xFFD63384),
          ),
        ));
        i = end + 1;
        continue;
      }
    }

    // [text](url)
    if (text[i] == '[') {
      final textEnd = text.indexOf('](', i);
      if (textEnd != -1) {
        final urlEnd = text.indexOf(')', textEnd + 2);
        if (urlEnd != -1) {
          flushBuffer();
          final linkText = text.substring(i + 1, textEnd);
          final _ = text.substring(textEnd + 2, urlEnd);
          spans.add(TextSpan(
            text: linkText,
            style: baseStyle.copyWith(color: AppColors.primary, decoration: TextDecoration.underline),
            recognizer: null, // TODO: add tap recognizer if needed
          ));
          i = urlEnd + 1;
          continue;
        }
      }
    }

    buffer.write(text[i]);
    i++;
  }

  flushBuffer();

  if (spans.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }
  if (spans.length == 1) {
    return spans.first;
  }
  return TextSpan(children: spans, style: baseStyle);
}
