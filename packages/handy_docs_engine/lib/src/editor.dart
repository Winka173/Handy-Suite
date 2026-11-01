import 'dart:convert';

String _bounded(String value, [int limit = 1000000]) {
  if (value.length > limit || utf8.encode(value).length > limit)
    throw FormatException('Document limit: $limit UTF-8 bytes');
  return value;
}

class LiteralMatches {
  final int count;
  final ({int line, int column})? first;
  const LiteralMatches(this.count, this.first);
}

LiteralMatches findMarkdownLiteral(String source, String needle) {
  _bounded(source);
  _bounded(needle, 10000);
  if (needle.isEmpty)
    throw const FormatException('Search text must not be empty');
  var offset = 0, first = -1, count = 0;
  while (offset <= source.length - needle.length) {
    final next = source.indexOf(needle, offset);
    if (next < 0) break;
    if (first < 0) first = next;
    count++;
    offset = next + needle.length;
  }
  if (count == 0) return const LiteralMatches(0, null);
  final lines = source.substring(0, first).split(RegExp(r'\r\n|\r|\n'));
  return LiteralMatches(count, (
    line: lines.length,
    column: lines.last.runes.length + 1,
  ));
}

String replaceMarkdownLiteral(
  String source,
  String needle,
  String replacement,
) {
  final found = findMarkdownLiteral(source, needle);
  _bounded(replacement, 100000);
  if (source.length + found.count * (replacement.length - needle.length) >
      1000000)
    throw const FormatException('Replacement exceeds document limit');
  return _bounded(
    found.count == 0 ? source : source.replaceAll(needle, replacement),
  );
}

String insertMarkdownTemplate(
  String source,
  String template, {
  String locale = 'en',
}) {
  _bounded(source);
  const templates = {
    'en': {
      'heading': '## Heading\n',
      'checklist': '- [ ] Task\n- [ ] Another task\n',
      'table': '| Column 1 | Column 2 |\n| --- | --- |\n| Value | Value |\n',
    },
    'vi': {
      'heading': '## Tiêu đề\n',
      'checklist': '- [ ] Việc cần làm\n- [ ] Việc tiếp theo\n',
      'table': '| Cột 1 | Cột 2 |\n| --- | --- |\n| Giá trị | Giá trị |\n',
    },
  };
  final snippet = templates[locale]?[template];
  if (snippet == null)
    throw const FormatException('Unknown Markdown template or locale');
  final newline = source.contains('\r\n') ? '\r\n' : '\n';
  final separator = source.isEmpty || source.endsWith('$newline$newline')
      ? ''
      : source.endsWith(newline)
      ? newline
      : '$newline$newline';
  return _bounded(source + separator + snippet.replaceAll('\n', newline));
}

List<int> pageRange(String source, int count) {
  if (count < 1) throw const FormatException('Empty PDF');
  _bounded(source, 10000);
  final out = <int>[];
  for (final part in source.split(',')) {
    final m = RegExp(r'^(\d+)(?:-(\d+))?$').firstMatch(part.trim());
    if (m == null) throw const FormatException('Use 1,3-5; pages start at 1');
    final a = int.tryParse(m[1]!), b = int.tryParse(m[2] ?? m[1]!);
    if (a == null || b == null || a < 1 || b < a || b > count || b - a > 500)
      throw const FormatException('Page range out of bounds');
    if (out.length + b - a + 1 > 500)
      throw const FormatException('Page selection limit: 500');
    for (var n = a; n <= b; n++) {
      out.add(n - 1);
    }
  }
  return out;
}
