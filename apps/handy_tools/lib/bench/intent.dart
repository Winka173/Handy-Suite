import 'package:handy_tools_engine/handy_tools_engine.dart';
import '../specs.dart';

/// What the bench thinks a free-form entry means: a tool and its field
/// values. The engine still validates everything; this only routes.
class Reading {
  final String toolId;
  final Map<String, String> values;
  const Reading(this.toolId, this.values);
  ToolSpec? get spec => specById[canonicalToolId(toolId)];
  @override
  String toString() => '$toolId $values';
}

/// Text transforms offered as chips (and chainable) for prose input.
const textTransforms = [
  'normalize',
  'deduplicate',
  'sort',
  'uppercase',
  'lowercase',
  'title-case',
  'sentence-case',
  'accents',
];

/// Normalises one written number to the engine's `1234.5` form.
/// Vietnamese writes `1.385.000,5`; English writes `1,385,000.5`. A single
/// separator followed by exactly three digits is read as thousands in the
/// writer's own convention.
String? normalizeNumber(String raw, {required bool vi}) {
  final s = raw.replaceAll(' ', '');
  if (!RegExp(r'^-?\d[\d.,]*$').hasMatch(s)) return null;
  final dots = '.'.allMatches(s).length, commas = ','.allMatches(s).length;
  if (dots > 0 && commas > 0) {
    final decimal = s.lastIndexOf('.') > s.lastIndexOf(',') ? '.' : ',';
    final group = decimal == '.' ? ',' : '.';
    return s.replaceAll(group, '').replaceAll(decimal, '.');
  }
  if (dots > 1) return s.replaceAll('.', '');
  if (commas > 1) return s.replaceAll(',', '');
  if (dots == 1) {
    return vi && s.split('.').last.length == 3 ? s.replaceAll('.', '') : s;
  }
  if (commas == 1) {
    return !vi && s.split(',').last.length == 3
        ? s.replaceAll(',', '')
        : s.replaceAll(',', '.');
  }
  return s;
}

final _unitAlias = <String, String>{
  for (final u in unitGroups.values.expand((v) => v)) u.toLowerCase(): u,
  '°c': 'C',
  '°f': 'F',
  'gal': 'us-gal',
  'm²': 'm2',
  'km²': 'km2',
  'kmh': 'km/h',
  'giây': 's',
  'sec': 's',
  'phút': 'min',
  'giờ': 'h',
  'ngày': 'day',
  'days': 'day',
  'lít': 'l',
  'mét': 'm',
};

String? _unit(String raw) => _unitAlias[raw.toLowerCase()];
String? _group(String unit) =>
    unitGroups.entries.firstWhere((e) => e.value.contains(unit)).key;

String? _date(String raw, DateTime today) {
  final s = raw.trim().toLowerCase();
  if (s == 'hôm nay' || s == 'today' || s == 'nay') {
    return today.toIso8601String().substring(0, 10);
  }
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
  if (m == null) return null;
  return '${m[3]}-${m[2]!.padLeft(2, '0')}-${m[1]!.padLeft(2, '0')}';
}

const _datePart = r'(\d{4}-\d{2}-\d{2}|\d{1,2}/\d{1,2}/\d{4}|hôm nay|today)';
const _num = r'(-?\d[\d.,]*)';

/// Candidate readings, best first. Empty when nothing useful applies yet.
List<Reading> interpret(String input, {required bool vi, DateTime? now}) {
  final s = input.trim();
  if (s.isEmpty) return const [];
  final today = now ?? DateTime.now();
  final lower = s.toLowerCase();
  RegExpMatch? m;

  m = RegExp(
    '^$_num\\s*([^\\s\\d][^\\s]*)\\s*(?:to|in|sang|ra|->|→|=)\\s*([^\\s\\d][^\\s]*)\$',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final from = _unit(m[2]!), to = _unit(m[3]!);
    final value = normalizeNumber(m[1]!, vi: vi);
    if (from != null && to != null && value != null) {
      return [
        Reading('units', {
          'kind': _group(from)!,
          'value': value,
          'from': from,
          'to': to,
        }),
      ];
    }
  }

  m = RegExp(
    '^$_num\\s*%\\s*(?:of|của|x|\\*)?\\s*$_num\$',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final p = normalizeNumber(m[1]!, vi: vi),
        a = normalizeNumber(m[2]!, vi: vi);
    if (p != null && a != null) {
      // The share, worked out exactly by the calculator; "2tr - 15%" (what
      // is left) belongs to the calc notebook since the percent tool went.
      return [
        Reading('calculate', {'expression': '$a * $p / 100'}),
      ];
    }
  }

  m = RegExp(
    '^$_datePart\\s*(?:-|–|đến|to|→)\\s*$_datePart\$',
    caseSensitive: false,
  ).firstMatch(lower);
  if (m != null) {
    final a = _date(m[1]!, today), b = _date(m[2]!, today);
    if (a != null && b != null) {
      return [
        // Working days come with the dates answer.
        Reading('dates', {'start': a, 'end': b, 'weekend': '0,6'}),
      ];
    }
  }

  if (RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(s)) {
    return [
      Reading('qr', {'text': s}),
      Reading('count', {'text': s}),
    ];
  }

  m = RegExp(
    '^$_num\\s*(?:đ|đồng|vnd)?\\s*(?:bằng chữ|thành chữ|in words|to words)\$',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final n = normalizeNumber(m[1]!, vi: vi);
    if (n != null) {
      return [
        Reading('number-words', {
          'number': n,
          'unit': n.contains('.') ? 'none' : 'dong',
          'style': 'north',
        }),
      ];
    }
  }

  m = RegExp(
    '^$_datePart\\s*(?:âm lịch|âm|lunar)\$',
    caseSensitive: false,
  ).firstMatch(lower);
  if (m != null) {
    final d = _date(m[1]!, today);
    if (d != null) {
      return [
        Reading('lunar', {'direction': 'solar', 'date': d}),
      ];
    }
  }

  m = RegExp(
    '^(lương|luong|gross|salary|net|thực nhận|thuc nhan)\\s+$_num\\s*(?:đ|đồng|vnd)?\$',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final n = normalizeNumber(m[2]!, vi: vi);
    final net = RegExp('^(net|thực|thuc)').hasMatch(m[1]!.toLowerCase());
    if (n != null) {
      return [
        Reading('salary', {
          'mode': net ? 'net' : 'gross',
          'amount': n,
          'dependants': '0',
          'region': '1',
          'date': today.toIso8601String().substring(0, 10),
        }),
      ];
    }
  }

  // "1.000.000 + VAT 10%", "2.400.000 - 15% - 5%": a percentage added or
  // taken off, one after another (the calculator's % is a remainder).
  m = RegExp(
    '^$_num((?:\\s*[+-]\\s*(?:vat|thuế|thue)?\\s*$_num\\s*%)+)\$',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final base = normalizeNumber(m[1]!, vi: vi);
    final steps = [
      for (final x in RegExp(
        '([+-])\\s*(?:vat|thuế|thue)?\\s*$_num\\s*%',
        caseSensitive: false,
      ).allMatches(m[2]!))
        (x[1]!, normalizeNumber(x[2]!, vi: vi)),
    ];
    if (base != null && steps.every((t) => t.$2 != null)) {
      final expression = [
        base,
        for (final (sign, p) in steps) '* (100 $sign $p) / 100',
      ].join(' ');
      return [
        Reading('calculate', {'expression': expression}),
      ];
    }
  }

  // "120 lên 150", "change 120 to 150": the change in percent.
  m = RegExp(
    '^(?:từ\\s+|change\\s+|thay đổi\\s+)?$_num\\s*(?:lên|xuống|→|->|thành|to)\\s*$_num\\s*%?\$',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final a = normalizeNumber(m[1]!, vi: vi),
        b = normalizeNumber(m[2]!, vi: vi);
    if (a != null && b != null && double.tryParse(a) != 0) {
      return [
        Reading('calculate', {'expression': '($b - $a) * 100 / $a'}),
      ];
    }
  }

  // "1.350.000 tip 10% chia 3", "450.000 chia 3 người": each share.
  m = RegExp(
    '^$_num(?:\\s*\\+?\\s*(?:tip|bo|boa)\\s*$_num\\s*%)?\\s*(?:chia|split)\\s*(\\d+)\\s*(?:người|nguoi|people|ways)?\$',
    caseSensitive: false,
  ).firstMatch(s);
  if (m != null) {
    final total = normalizeNumber(m[1]!, vi: vi);
    final tip = m[2] == null ? '0' : normalizeNumber(m[2]!, vi: vi);
    final n = int.tryParse(m[3]!);
    if (total != null && tip != null && n != null && n > 0) {
      return [
        Reading('calculate', {
          'expression': '$total * (100 + $tip) / 100 / $n',
        }),
      ];
    }
  }

  final expression = _expression(s, vi: vi);
  if (expression != null) {
    return [
      Reading('calculate', {'expression': expression}),
    ];
  }

  // Prose: counts first, then every transform as an alternative.
  return [
    Reading('count', {'text': input}),
    for (final id in textTransforms)
      Reading(id, {'text': input, ...legacyValues(id)}),
  ];
}

/// The engine's expression for arithmetic typed the way people write it, or
/// null when the entry is not arithmetic.
String? _expression(String s, {required bool vi}) {
  var e = s
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-')
      .replaceAllMapped(
        RegExp(r'(\d)\s*[xX]\s*(\d)'),
        (m) => '${m[1]}*${m[2]}',
      );
  final words = e.toLowerCase().replaceAll(
    RegExp(r'sqrt|abs|sin|cos|tan|log'),
    '',
  );
  if (!RegExp(r'^[\d\s+\-*/%^().,]+$').hasMatch(words)) return null;
  if (!RegExp(r'\d').hasMatch(words)) return null;
  final operated =
      RegExp(
        r'[+\-*/%^()]',
      ).hasMatch(words.replaceFirst(RegExp(r'^\s*-'), '')) ||
      words.length != e.length;
  if (!operated) return null;
  e = e.replaceAllMapped(
    RegExp(r'\d[\d.,]*'),
    (m) => normalizeNumber(m[0]!, vi: vi) ?? m[0]!,
  );
  return e;
}
