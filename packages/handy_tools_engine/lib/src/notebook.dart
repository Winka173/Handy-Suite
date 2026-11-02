part of '../handy_tools_engine.dart';

/// One line of a calc notebook as worked out: its result, why it has
/// none, and whether it is a total of the lines above it.
class NotebookLine {
  /// The exact result (what Copy takes), and the same rounded to two
  /// decimals for the answer column.
  final String? value, shown, error;
  final bool total;
  const NotebookLine({this.value, this.shown, this.error, this.total = false});
}

const _notebookFunctions = {'sqrt', 'abs', 'sin', 'cos', 'tan', 'log', 'pi'};
const _totalWords = {'tổng', 'tong', 'total', 'sum', 'cộng', 'cong'};
const _scales = {
  'k': 1000,
  'nghìn': 1000,
  'ngàn': 1000,
  'tr': 1000000,
  'triệu': 1000000,
  'm': 1000000,
  'tỷ': 1000000000,
  'tỉ': 1000000000,
  'b': 1000000000,
};

/// Works out a calc notebook: one sum per line, words around it ignored.
///
/// * `Rent: 5tr` or `rent = 5tr` names the line; later lines use `rent`.
/// * `ans` is the line above; `total` (or `tổng`) adds the lines above it
///   up to a blank line.
/// * `45k`, `1.2tr`, `1.200.000`, `10%`, `3 x 4` read as people write them.
List<NotebookLine> evaluateNotebook(String text) {
  _bounded(text, 50000);
  final lines = text.split('\n');
  if (lines.length > 500)
    throw const FormatException('Up to 500 lines / Tối đa 500 dòng');
  final names = <String, Rational>{};
  final out = <NotebookLine>[];
  final section = <Rational>[];
  Rational? last;
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) {
      section.clear();
      out.add(const NotebookLine());
      continue;
    }
    if (line.startsWith('#') || line.startsWith('//')) {
      out.add(const NotebookLine());
      continue;
    }
    var name = '', expression = line;
    final named = RegExp(
      // A name starts with a letter and may hold figures ("split 3").
      r'^(\p{L}[^=:()]*?)\s*[=:]\s*(.+)$',
      unicode: true,
    ).firstMatch(line);
    if (named != null) {
      name = named[1]!.trim().toLowerCase();
      expression = named[2]!;
    }
    try {
      final Rational value;
      final total = _totalWords.contains(expression.trim().toLowerCase());
      if (total) {
        value = section.fold(_zero, (a, b) => a + b);
      } else {
        final prepared = _prepareLine(expression, names, last);
        if (prepared == null) {
          out.add(const NotebookLine());
          continue;
        }
        value = _calculate(prepared);
      }
      if (name.isNotEmpty) names[name] = value;
      last = value;
      if (!total) section.add(value);
      final hundred = Rational.fromInt(100);
      out.add(
        NotebookLine(
          value: _format(value),
          shown: _format(Rational((value * hundred).round(), BigInt.from(100))),
          total: total,
        ),
      );
    } on FormatException catch (e) {
      out.add(NotebookLine(error: e.message));
    }
  }
  return out;
}

/// [expression] as the calculator reads it, or null when it holds no
/// figure at all (a heading).
String? _prepareLine(
  String expression,
  Map<String, Rational> names,
  Rational? last,
) {
  String value(Rational r) => '(${_format(r, 34)})';
  var s = expression.toLowerCase();
  // Longest names first, so "rent deposit" wins over "rent".
  for (final n
      in names.keys.toList()..sort((a, b) => b.length.compareTo(a.length))) {
    s = s.replaceAll(n, value(names[n]!));
  }
  if (last != null) s = s.replaceAll(RegExp(r'\bans\b'), value(last));
  // 1.200.000 and 1,200,000 group; 1,5 and 1.5 are decimals.
  s = s.replaceAllMapped(
    RegExp(r'\d{1,3}(?:([.,])\d{3})(?:\1\d{3})*(?![\d.,])'),
    (m) => m[0]!.replaceAll(m[1]!, ''),
  );
  s = s.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}');
  s = s.replaceAllMapped(
    RegExp(
      r'(\d+(?:\.\d+)?)\s*(nghìn|ngàn|triệu|tỷ|tỉ|tr|k|m|b)(?![\p{L}])',
      unicode: true,
    ),
    (m) => '(${m[1]}*${_scales[m[2]]})',
  );
  s = s.replaceAllMapped(
    RegExp(r'(\d+(?:\.\d+)?)%(?!\s*\d)'),
    (m) => '(${m[1]}/100)',
  );
  s = s.replaceAllMapped(RegExp(r'(?<=[\d)])\s*[x×]\s*(?=[\d(])'), (_) => '*');
  s = s.replaceAll('÷', '/');
  // Words left over are labels.
  s = s.replaceAllMapped(
    RegExp(r'[\p{L}_]+', unicode: true),
    (m) => _notebookFunctions.contains(m[0])
        ? m[0]!
        // "30 days x 35k": a lone x between figures multiplies.
        : m[0] == 'x'
        ? '*'
        : ' ',
  );
  if (!RegExp(r'\d').hasMatch(s)) return null;
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
