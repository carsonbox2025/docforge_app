/// 流式大纲解析器 — 从不完整的 LLM JSON 输出中增量提取任务信息
///
/// LLM 规划阶段输出 JSON 结构（逐 token 流式到达）：
/// {"tasks": [{"task_id": "task_1", "description": "...",
///   "chapter_meta": {"title": "...", "key_points": [...]}}]}
///
/// 本模块用正则从任意截断位置提取已完成的字段，无需等待完整 JSON。

class ParsedPlanItem {
  final String taskId;
  final String title;
  final String description;
  final List<String> keyPoints;
  final bool streaming;

  const ParsedPlanItem({
    required this.taskId,
    this.title = '',
    this.description = '',
    this.keyPoints = const [],
    this.streaming = false,
  });
}

/// 从流式文本中增量解析任务列表
List<ParsedPlanItem> parseStreamingPlanContent(String buffer) {
  if (buffer.isEmpty || buffer.length < 10) return [];

  final items = <ParsedPlanItem>[];
  final taskBlocks = _splitTaskBlocks(buffer);

  for (int i = 0; i < taskBlocks.length; i++) {
    final block = taskBlocks[i];
    final isLast = i == taskBlocks.length - 1;

    final taskId = _extractFirstMatch(block, RegExp(r'"task_id"\s*:\s*"([^"]+)"'));
    final title = _unescapeJson(
        _extractFirstMatch(block, RegExp(r'"title"\s*:\s*"((?:[^"\\]|\\.)*)"')) ?? '');
    final description = _unescapeJson(
        _extractFirstMatch(block, RegExp(r'"description"\s*:\s*"((?:[^"\\]|\\.)*)"')) ?? '');
    final keyPoints = _extractKeyPoints(block).map(_unescapeJson).toList();

    if (taskId != null) {
      items.add(ParsedPlanItem(
        taskId: taskId,
        title: title,
        description: description,
        keyPoints: keyPoints,
        streaming: isLast,
      ));
    }
  }

  return items;
}

/// 将文本按 task 对象边界切分
List<String> _splitTaskBlocks(String text) {
  final blocks = <String>[];
  final regex = RegExp(r'"task_id"\s*:\s*"');
  final positions = <int>[];

  for (final match in regex.allMatches(text)) {
    positions.add(_findObjectStart(text, match.start));
  }

  if (positions.isEmpty) {
    return text.length > 5 ? [text] : [];
  }

  for (int i = 0; i < positions.length; i++) {
    final start = positions[i];
    final end = i + 1 < positions.length ? positions[i + 1] : text.length;
    blocks.add(text.substring(start, end));
  }

  return blocks;
}

/// 从 "task_id" 位置向前搜索最近的 {
int _findObjectStart(String text, int pos) {
  int depth = 0;
  int i = pos;
  while (i >= 0) {
    if (text[i] == '}') {
      depth++;
    } else if (text[i] == '{') {
      if (depth == 0) return i;
      depth--;
    }
    i--;
  }
  return pos;
}

String? _extractFirstMatch(String text, RegExp regex) {
  final match = regex.firstMatch(text);
  return match?.group(1);
}

/// 提取 key_points 数组中的字符串
List<String> _extractKeyPoints(String text) {
  final points = <String>[];
  final kpStart = text.indexOf('"key_points"');
  if (kpStart == -1) return points;

  final bracketStart = text.indexOf('[', kpStart);
  if (bracketStart == -1) return points;

  final remaining = text.substring(bracketStart + 1);
  final stringRegex = RegExp(r'"((?:[^"\\]|\\.)*)"');

  for (final match in stringRegex.allMatches(remaining)) {
    final value = match.group(1) ?? '';
    final cleaned = value.replaceFirst(RegExp(r'^要点\d+[：:]\s*'), '').trim();
    if (cleaned.isNotEmpty) {
      points.add(cleaned);
    }
    final afterIdx = match.end;
    if (afterIdx < remaining.length) {
      final after = remaining.substring(afterIdx).trim();
      if (after.startsWith(']') || after.startsWith('}')) break;
      if (after.contains('"data_sources"') || after.contains('"target_words"')) break;
    }
  }

  return points;
}

/// 反转义 JSON 字符串中的转义字符
String _unescapeJson(String str) {
  if (str.isEmpty) return str;
  return str
      .replaceAll(r'\\', '\x00')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\t', '\t')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\"', '"')
      .replaceAll('\x00', '\\');
}
