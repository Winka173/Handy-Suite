part of '../handy_tools_engine.dart';

DateTime _day(String source) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(source))
    throw const FormatException('Use YYYY-MM-DD');
  final values = source.split('-').map(int.parse).toList(),
      date = DateTime.utc(values[0], values[1], values[2]);
  if (values[0] < 1 ||
      date.year != values[0] ||
      date.month != values[1] ||
      date.day != values[2])
    throw const FormatException('Invalid calendar date');
  return date;
}

int dateDiff(String start, String end) =>
    _day(end).difference(_day(start)).inDays;
int businessDays(
  String start,
  String end, [
  List<int> weekend = const [0, 6],
  List<String> holidays = const [],
]) {
  final a = _day(start), b = _day(end);
  if (b.isBefore(a) ||
      b.difference(a).inDays > 36600 ||
      weekend.any((d) => d < 0 || d > 6) ||
      holidays.length > 1000)
    throw const FormatException('Invalid date range, weekend or holiday count');
  final excluded = holidays.map((d) => _day(d).millisecondsSinceEpoch).toSet();
  var count = 0;
  for (var day = a; day.isBefore(b); day = day.add(const Duration(days: 1)))
    if (!weekend.contains(day.weekday % 7) &&
        !excluded.contains(day.millisecondsSinceEpoch))
      count++;
  return count;
}

Map<String, Object> splitBill(String amount, String tip, int people) {
  final a = _d(amount), r = _d(tip);
  if (a < _zero ||
      r < _zero ||
      r > Rational.fromInt(1000) ||
      people < 1 ||
      people > 1000)
    throw const FormatException('Invalid bill, tip or people count');
  final centsValue = a * (_one + r / _hundred) * _hundred,
      cents = _roundedRatio(centsValue.numerator, centsValue.denominator);
  if (cents > BigInt.parse('9007199254740991'))
    throw const FormatException('Bill too large');
  final base = cents ~/ BigInt.from(people),
      remainder = (cents % BigInt.from(people)).toInt();
  return {
    'total': _fixed(Rational(cents) / _hundred, 2),
    'shares': List.generate(
      people,
      (i) => _fixed(
        Rational(base + BigInt.from(i < remainder ? 1 : 0)) / _hundred,
        2,
      ),
    ),
  };
}

String replaceLiteral(
  String source,
  String find,
  String replacement,
  bool all,
) {
  _bounded(source);
  _bounded(find, 10000);
  _bounded(replacement, 10000);
  if (find.isEmpty) throw const FormatException('Find text must not be empty');
  final pieces = source.split(find),
      count = all ? pieces.length - 1 : math.min(1, pieces.length - 1);
  if (source.length - count * find.length + count * replacement.length >
      1000000)
    throw const FormatException('Replacement output exceeds 1 MB');
  return all
      ? pieces.join(replacement)
      : source.replaceFirst(find, replacement);
}

Map<String, int> textStats(String text) => {
  'codePoints': text.runes.length,
  'utf16Units': text.length,
  'words': text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length,
  'lines': text.isEmpty ? 0 : text.split(RegExp(r'\r\n|\r|\n')).length,
};
String removeAccents(String source) => unorm.nfc(
  unorm
      .nfd(_bounded(source))
      .replaceAll(RegExp(r'\p{M}', unicode: true), '')
      .replaceAll('đ', 'd')
      .replaceAll('Đ', 'D'),
);
String _sortLines(String source) {
  final lines = _bounded(source).split(RegExp(r'\r\n|\r|\n'));
  lines.sort((a, b) {
    final left = a.runes.toList(), right = b.runes.toList();
    for (var i = 0; i < math.min(left.length, right.length); i++) {
      final difference = left[i] - right[i];
      if (difference != 0) return difference;
    }
    return left.length - right.length;
  });
  return lines.join('\n');
}

String _title(String source) => source.toLowerCase().replaceAllMapped(
  RegExp(r'\p{L}[\p{L}\p{M}]*', unicode: true),
  (m) {
    final word = m[0]!, first = String.fromCharCode(word.runes.first);
    return first.toUpperCase() + word.substring(first.length);
  },
);

/// The four case modes of the `case` tool. Each keeps the behaviour of the
/// separate tool it replaced.
const caseModes = ['upper', 'lower', 'title', 'sentence'];
String changeCase(String source, String mode) => switch (mode) {
  'upper' => source.toUpperCase(),
  'lower' => source.toLowerCase(),
  'title' => _title(source),
  'sentence' => source.toLowerCase().replaceAllMapped(
    RegExp(r'(^|[.!?]\s+)(\p{L})', unicode: true),
    (m) => m[1]! + m[2]!.toUpperCase(),
  ),
  _ => throw const FormatException('Case: upper, lower, title or sentence'),
};

ToolDefinition _tool(
  String id,
  String en,
  String vi,
  String description,
  String input,
  ToolRunner run, [
  String options = '',
]) => ToolDefinition(
  id: id,
  titleEn: en,
  titleVi: vi,
  description: description,
  inputLabel: input,
  optionsLabel: options,
  run: run,
);
List<String> _parts(String source, int count) {
  final values = source.split(',').map((s) => s.trim()).toList();
  if (values.length != count)
    throw FormatException('Expected $count comma-separated values');
  return values;
}

int _integer(String value) {
  if (!RegExp(r'^[+-]?\d+$').hasMatch(value))
    throw const FormatException('Integer required');
  return int.parse(value);
}

final List<ToolDefinition> tools = List.unmodifiable([
  _tool(
    'calculate',
    'Calculator',
    'Máy tính',
    'Operators + − * / % ^, parentheses, sqrt/abs/sin/cos/tan/log. Trigonometry uses radians.',
    'Expression',
    (s, o) => calculate(s),
  ),
  _tool(
    'units',
    'Unit converter',
    'Đổi đơn vị',
    'Compatible units; C/F/K supported.',
    'Value',
    (s, o) {
      final v = _parts(o, 2);
      return convert(s, v[0], v[1]);
    },
    'm,ft',
  ),
  _tool(
    'loan',
    'Loan schedule',
    'Lịch trả nợ',
    'Fixed annual rate, monthly installments; excludes fees and taxes.',
    'Principal,annual %,months',
    (s, o) {
      final v = _parts(s, 3);
      return loan(v[0], v[1], _integer(v[2]));
    },
  ),
  _tool(
    'compound',
    'Compound savings',
    'Lãi kép',
    'No additional contributions, tax or fees.',
    'Principal,annual %,years,compounds per year',
    (s, o) {
      final v = _parts(s, 4).map(_d).toList(),
          p = v[0],
          r = v[1],
          y = v[2],
          n = v[3];
      if (p < _zero ||
          r < _zero ||
          y < _zero ||
          y > _hundred ||
          !n.isInteger ||
          n < _one ||
          n > Rational.fromInt(365))
        throw const FormatException('Invalid savings inputs');
      return _fixed(
        _guard(p * _compoundPower(_one + r / _hundred / n, n * y)),
        2,
      );
    },
  ),
  _tool(
    'dates',
    'Date difference',
    'Khoảng cách ngày',
    'Calendar days in UTC; end minus start.',
    'YYYY-MM-DD,YYYY-MM-DD',
    (s, o) {
      final v = _parts(s, 2);
      return dateDiff(v[0], v[1]).toString();
    },
  ),
  _tool(
    'normalize',
    'Normalize whitespace',
    'Chuẩn hóa khoảng trắng',
    'NFC Unicode, trim each line, collapse spaces and tabs.',
    'Text',
    (s, o) => unorm
        .nfc(s)
        .split(RegExp(r'\r\n|\r|\n'))
        .map((line) => line.trim().replaceAll(RegExp(r'[\t ]+'), ' '))
        .join('\n'),
  ),
  _tool(
    'deduplicate',
    'Deduplicate lines',
    'Lọc dòng trùng',
    'Keep first exact occurrence.',
    'Text',
    (s, o) => s.split(RegExp(r'\r\n|\r|\n')).toSet().join('\n'),
  ),
  _tool(
    'sort',
    'Sort lines',
    'Sắp xếp dòng',
    'Unicode code-point order, independent of locale.',
    'Text',
    (s, o) => _sortLines(s),
  ),
  _tool(
    'case',
    'Change case',
    'Đổi kiểu chữ',
    'Unicode upper, lower, title (letter groups) or sentence case (after . ! ?).',
    'Text',
    (s, o) => changeCase(s, o.trim()),
    'upper / lower / title / sentence',
  ),
  _tool(
    'accents',
    'Remove accents',
    'Bỏ dấu',
    'Remove combining marks and map Vietnamese đ/Đ.',
    'Text',
    (s, o) => removeAccents(s),
  ),
  _tool(
    'count',
    'Text counts',
    'Đếm văn bản',
    'Code points, UTF-16 units, whitespace-separated words and lines.',
    'Text',
    (s, o) => _json(textStats(s)),
  ),
  _tool(
    'salary',
    'Salary',
    'Tính lương',
    'Vietnamese employee insurance with caps, family deductions and progressive PIT from a dated rule table; whole đồng.',
    'Amount (đồng)',
    runSalary,
    '{"mode":"gross","date":"YYYY-MM-DD","region":1,"dependants":0}',
  ),
  _tool(
    'split-bill',
    'Split bill & tip',
    'Chia hóa đơn và tiền tip',
    'Rounded cents are allocated exactly; extra cents go to first shares.',
    'Amount,tip %,people',
    (s, o) {
      final v = _parts(s, 3);
      return _json(splitBill(v[0], v[1], _integer(v[2])));
    },
  ),
  _tool(
    'business-days',
    'Business days',
    'Số ngày làm việc',
    'Start inclusive, end exclusive. Weekend indices Sun=0, Sat=6.',
    'Start,end YYYY-MM-DD',
    (s, o) {
      final v = _parts(s, 2), settings = o.split('|');
      if (settings.length > 2)
        throw const FormatException('Weekend|holiday options required');
      return businessDays(
        v[0],
        v[1],
        settings[0].trim().isEmpty
            ? [0, 6]
            : settings[0].split(',').map((v) => _integer(v.trim())).toList(),
        settings.length < 2 || settings[1].trim().isEmpty
            ? []
            : settings[1].split(',').map((v) => v.trim()).toList(),
      ).toString();
    },
    '0,6|2026-01-01',
  ),
  _tool(
    'literal-replace',
    'Find & replace',
    'Tìm và thay thế',
    'Literal replacement, bounded to one million UTF-16 units.',
    'Text',
    (s, o) {
      final value = jsonDecode(o);
      if (value is! Map ||
          value['find'] is! String ||
          value['replace'] is! String)
        throw const FormatException('Expected find/replace strings');
      return replaceLiteral(
        s,
        value['find'] as String,
        value['replace'] as String,
        value['all'] == true,
      );
    },
    '{"find":"old","replace":"new","all":true}',
  ),
  _tool(
    'number-words',
    'Number in words',
    'Đọc số thành chữ',
    'Vietnamese and English words; đồng amounts end "đồng chẵn". Up to 27 digits, 12 decimals.',
    'Number',
    runNumberWords,
    'unit=dong|none;style=north|south',
  ),
  _tool(
    'lunar',
    'Lunar calendar',
    'Âm lịch',
    'Vietnamese lunar date at UTC+7 (Hồ Ngọc Đức), leap months, can-chi, solar term; 1900–2100.',
    'YYYY-MM-DD',
    runLunar,
    'solar / lunar / lunar-leap',
  ),
]);
