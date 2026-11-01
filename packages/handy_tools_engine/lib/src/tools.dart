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

Map<String, Object> tax(String amount, String rate, bool inclusive) {
  final a = _d(amount), r = _d(rate) / _hundred;
  if (a < _zero || r < _zero || r > Rational.fromInt(10))
    throw const FormatException('Invalid nonnegative amount or tax rate');
  final base = inclusive ? a / (_one + r) : a,
      total = inclusive ? a : a * (_one + r);
  return {
    'base': _fixed(base, 2),
    'tax': _fixed(total - base, 2),
    'total': _fixed(total, 2),
  };
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
List<int> _rgb(String hex) {
  if (!RegExp(r'^#[a-f\d]{6}$', caseSensitive: false).hasMatch(hex))
    throw const FormatException('Use #RRGGBB');
  return [
    1,
    3,
    5,
  ].map((at) => int.parse(hex.substring(at, at + 2), radix: 16)).toList();
}

double contrast(String a, String b) {
  double luminance(String hex) {
    final rgb = _rgb(hex)
        .map((n) => n / 255)
        .map(
          (n) => n <= 0.04045
              ? n / 12.92
              : math.pow((n + 0.055) / 1.055, 2.4).toDouble(),
        )
        .toList();
    return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722;
  }

  final left = luminance(a), right = luminance(b);
  return (math.max(left, right) + 0.05) / (math.min(left, right) + 0.05);
}

double _two(double n) => double.parse(n.toStringAsFixed(2));
Map<String, Object> colors(String hex) {
  final rgb = _rgb(hex),
      r = rgb[0] / 255,
      g = rgb[1] / 255,
      b = rgb[2] / 255,
      max = math.max(r, math.max(g, b)),
      min = math.min(r, math.min(g, b)),
      delta = max - min,
      light = (max + min) / 2;
  var hue = delta == 0
      ? 0.0
      : max == r
      ? ((g - b) / delta) % 6
      : max == g
      ? (b - r) / delta + 2
      : (r - g) / delta + 4;
  hue = (hue * 60 + 360) % 360;
  return {
    'hex': hex.toUpperCase(),
    'rgb': {'r': rgb[0], 'g': rgb[1], 'b': rgb[2]},
    'hsl': {
      'h': _two(hue),
      's': _two(delta == 0 ? 0 : delta / (1 - (2 * light - 1).abs()) * 100),
      'l': _two(light * 100),
    },
  };
}

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
    'percent',
    'Percentage',
    'Phần trăm',
    'Percentage value and amount after discount.',
    'Amount,percentage',
    (s, o) {
      final v = _parts(s, 2).map(_d).toList();
      return _json({
        'percent': _format(v[0] * v[1] / _hundred),
        'afterDiscount': _format(v[0] * (_one - v[1] / _hundred)),
      });
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
    'uppercase',
    'Uppercase',
    'Viết hoa',
    'Unicode uppercase.',
    'Text',
    (s, o) => s.toUpperCase(),
  ),
  _tool(
    'lowercase',
    'Lowercase',
    'Viết thường',
    'Unicode lowercase.',
    'Text',
    (s, o) => s.toLowerCase(),
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
    'contrast',
    'Color contrast',
    'Độ tương phản',
    'WCAG contrast; normal text AA requires 4.5.',
    'HEX,HEX',
    (s, o) {
      final v = _parts(s, 2), ratio = contrast(v[0], v[1]);
      return _json({
        'ratio': double.parse(ratio.toStringAsFixed(3)),
        'normalAA': ratio >= 4.5,
      });
    },
  ),
  _tool(
    'tax',
    'Tax calculator',
    'Tính thuế',
    'Amounts round half up to two decimals.',
    'Amount,rate %',
    (s, o) {
      final v = _parts(s, 2);
      if (!['inclusive', 'exclusive'].contains(o.trim()))
        throw const FormatException('Choose inclusive or exclusive');
      return _json(tax(v[0], v[1], o.trim() == 'inclusive'));
    },
    'inclusive / exclusive',
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
    'ratio',
    'Scale a ratio',
    'Tính tỷ lệ',
    'Proportional new second term.',
    'a,b,new a',
    (s, o) {
      final v = _parts(s, 3).map(_d).toList();
      if (v[0] == _zero)
        throw const FormatException('First ratio term must be nonzero');
      return _format(v[1] * v[2] / v[0]);
    },
  ),
  _tool(
    'manual-exchange',
    'Manual exchange rate',
    'Đổi tiền theo tỷ giá nhập',
    'User-provided rate only; no live rate lookup.',
    'Amount,rate,YYYY-MM-DD',
    (s, o) {
      final v = _parts(s, 3);
      _day(v[2]);
      final a = _d(v[0]), r = _d(v[1]);
      if (r <= _zero) throw const FormatException('Rate must be positive');
      return _json({
        'amount': _fixed(a * r, 2),
        'rate': _format(r),
        'rateDate': v[2],
        'source': 'user supplied',
      });
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
    'title-case',
    'Title case',
    'Viết hoa đầu từ',
    'Unicode letter groups; not language-specific editorial rules.',
    'Text',
    (s, o) => _title(s),
  ),
  _tool(
    'sentence-case',
    'Sentence case',
    'Viết hoa đầu câu',
    'Capitalize first letter and after . ! ?; abbreviations not inferred.',
    'Text',
    (s, o) => s.toLowerCase().replaceAllMapped(
      RegExp(r'(^|[.!?]\s+)(\p{L})', unicode: true),
      (m) => m[1]! + m[2]!.toUpperCase(),
    ),
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
    'colors',
    'HEX / RGB / HSL',
    'HEX / RGB / HSL',
    'HEX input, HSL in degrees and percentages.',
    '#RRGGBB',
    (s, o) => _json(colors(s.trim())),
  ),
]);
