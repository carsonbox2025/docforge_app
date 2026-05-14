// 章节编号工具 — 对齐 web 端 chapterNumbering.ts

const _chineseDigits = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];

String toChineseNum(int n) {
  if (n <= 0) return '';
  if (n <= 10) return _chineseDigits[n];
  if (n < 20) return '十${_chineseDigits[n - 10]}';
  final tens = n ~/ 10;
  final ones = n % 10;
  if (ones == 0) return '${_chineseDigits[tens]}十';
  return '${_chineseDigits[tens]}十${_chineseDigits[ones]}';
}

final _titleNumberRegex = RegExp(r'^[一二三四五六七八九十百]+、\s*');
final _digitTitleRegex = RegExp(r'^\d+[.、]\s*');

String stripTitleNumber(String title) {
  return title.replaceFirst(_titleNumberRegex, '').replaceFirst(_digitTitleRegex, '');
}

final _headingNumberRegex = RegExp(r'^\d+(?:\.\d+)*\s+');

String stripHeadingNumber(String text) {
  return text.replaceFirst(_headingNumberRegex, '');
}

final _dslBlockStartRegex = RegExp(r'\[BLOCK_START[^\]]*\]');
final _dslImageTagRegex = RegExp(r'<<<IMAGE[^>]*>>>');
final _dslChartTagRegex = RegExp(r'<<<CHART[^>]*>>>');

String stripDslTags(String text) {
  return text.replaceAll(_dslBlockStartRegex, '').replaceAll(_dslImageTagRegex, '').replaceAll(_dslChartTagRegex, '');
}

/// 从 chapterId 解析章节号（如 "ch-1" → 1, "ch-2.1" → (2, "1")）
({int top, String? sub})? parseChapterId(String chapterId) {
  final match = RegExp(r'^ch-?(\d+)(?:\.([\d.]+))?$').firstMatch(chapterId);
  if (match == null) return null;
  return (top: int.parse(match.group(1)!), sub: match.group(2));
}
