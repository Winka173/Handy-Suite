part of '../handy_tools_engine.dart';

/// One progressive bracket: taxable income up to [upTo] đồng a month (null
/// for the top bracket) is taxed at [rate] percent.
typedef SalaryBracket = ({int? upTo, String rate});

/// Vietnamese payroll parameters in force from [from] (inclusive) until the
/// next entry of [salaryRuleTable]. Amounts are đồng a month.
class SalaryRules {
  final String from;
  final int personal, dependant, base;

  /// Regional minimum wages, region I to IV.
  final List<int> regionalMinimum;

  /// Employee shares in percent: social, health, unemployment insurance.
  final String social, health, unemployment;

  /// Contribution caps are this many times the base salary (social and
  /// health) or the regional minimum wage (unemployment).
  final int capTimes;
  final List<SalaryBracket> brackets;
  final List<String> sources;
  const SalaryRules({
    required this.from,
    required this.personal,
    required this.dependant,
    required this.base,
    required this.regionalMinimum,
    required this.social,
    required this.health,
    required this.unemployment,
    required this.brackets,
    required this.sources,
    this.capTimes = 20,
  });

  /// The bracket list written the way the override field takes it.
  String get bracketText => formatSalaryBrackets(brackets);
}

const _sevenBrackets = <SalaryBracket>[
  (upTo: 5000000, rate: '5'),
  (upTo: 10000000, rate: '10'),
  (upTo: 18000000, rate: '15'),
  (upTo: 32000000, rate: '20'),
  (upTo: 52000000, rate: '25'),
  (upTo: 80000000, rate: '30'),
  (upTo: null, rate: '35'),
];
const _fiveBrackets = <SalaryBracket>[
  (upTo: 10000000, rate: '5'),
  (upTo: 30000000, rate: '10'),
  (upTo: 60000000, rate: '20'),
  (upTo: 100000000, rate: '30'),
  (upTo: null, rate: '35'),
];

/// Dated parameter sets, oldest first. Checked on 2026-11-02; sources are
/// listed per entry and in docs/FUNCTIONS.md.
const salaryRuleTable = <SalaryRules>[
  SalaryRules(
    from: '2024-07-01',
    personal: 11000000,
    dependant: 4400000,
    base: 2340000,
    regionalMinimum: [4960000, 4410000, 3860000, 3450000],
    social: '8',
    health: '1.5',
    unemployment: '1',
    brackets: _sevenBrackets,
    sources: [
      'NQ 954/2020/UBTVQH14 (giảm trừ)',
      'Luật Thuế TNCN 2007 sửa đổi (biểu 7 bậc)',
      'NĐ 73/2024/NĐ-CP (lương cơ sở)',
      'NĐ 74/2024/NĐ-CP (lương tối thiểu vùng)',
    ],
  ),
  SalaryRules(
    from: '2026-01-01',
    personal: 15500000,
    dependant: 6200000,
    base: 2340000,
    regionalMinimum: [5310000, 4730000, 4140000, 3700000],
    social: '8',
    health: '1.5',
    unemployment: '1',
    brackets: _fiveBrackets,
    sources: [
      'NQ 110/2025/UBTVQH15 (giảm trừ)',
      'Luật 109/2025/QH15 (biểu 5 bậc, kỳ tính thuế 2026)',
      'NĐ 73/2024/NĐ-CP (lương cơ sở)',
      'NĐ 293/2025/NĐ-CP (lương tối thiểu vùng)',
    ],
  ),
  SalaryRules(
    from: '2026-07-01',
    personal: 15500000,
    dependant: 6200000,
    base: 2530000,
    regionalMinimum: [5310000, 4730000, 4140000, 3700000],
    social: '8',
    health: '1.5',
    unemployment: '1',
    brackets: _fiveBrackets,
    sources: [
      'NQ 110/2025/UBTVQH15 (giảm trừ)',
      'Luật 109/2025/QH15 (biểu 5 bậc, kỳ tính thuế 2026)',
      'NĐ 161/2026/NĐ-CP (lương cơ sở)',
      'NĐ 293/2025/NĐ-CP (lương tối thiểu vùng)',
    ],
  ),
];

/// The rules in force on [date] (`YYYY-MM-DD`).
SalaryRules salaryRulesOn(String date) {
  final day = _day(date);
  SalaryRules? found;
  for (final rules in salaryRuleTable) {
    if (!_day(rules.from).isAfter(day)) found = rules;
  }
  if (found == null) {
    throw FormatException(
      'No salary rules before ${salaryRuleTable.first.from}',
    );
  }
  return found;
}

String formatSalaryBrackets(List<SalaryBracket> brackets) => brackets
    .map((b) => '${b.upTo == null ? '*' : b.upTo}=${b.rate}')
    .join('; ');

/// Reads `10000000=5; 30000000=10; *=35`: limits in đồng (separators
/// allowed), ascending, the last one open (`*`). Rates 0–60 %.
List<SalaryBracket> parseSalaryBrackets(String source) {
  _bounded(source, 1000);
  final parts = source
      .split(RegExp(r'[;\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty || parts.length > 12) {
    throw const FormatException('Brackets: 1–12 entries like 10000000=5');
  }
  final out = <SalaryBracket>[];
  int? previous;
  for (var i = 0; i < parts.length; i++) {
    final m = RegExp(
      r'^([\d., ]+|\*)\s*=\s*(\d+(?:\.\d+)?)\s*%?$',
    ).firstMatch(parts[i]);
    if (m == null) {
      throw FormatException('Bracket "${parts[i]}" should read limit=rate');
    }
    final last = i == parts.length - 1;
    final rate = _d(m[2]!);
    if (rate > Rational.fromInt(60)) {
      throw const FormatException('Bracket rate must be 0–60 %');
    }
    if (m[1] == '*') {
      if (!last) throw const FormatException('Only the last bracket is open');
      out.add((upTo: null, rate: _format(rate)));
      break;
    }
    if (last) throw const FormatException('The last bracket must be *=rate');
    final limit = int.tryParse(m[1]!.replaceAll(RegExp(r'[., ]'), ''));
    if (limit == null ||
        limit <= 0 ||
        limit > 100000000000 ||
        (previous != null && limit <= previous)) {
      throw const FormatException('Bracket limits must rise above zero');
    }
    previous = limit;
    out.add((upTo: limit, rate: _format(rate)));
  }
  return out;
}

/// Everything the user may override; null keeps the table's value.
class SalaryOverrides {
  final int? insured, personal, dependant, base, regionalMinimum;
  final String? social, health, unemployment;
  final List<SalaryBracket>? brackets;
  const SalaryOverrides({
    this.insured,
    this.personal,
    this.dependant,
    this.base,
    this.regionalMinimum,
    this.social,
    this.health,
    this.unemployment,
    this.brackets,
  });
  int get count => [
    insured,
    personal,
    dependant,
    base,
    regionalMinimum,
    social,
    health,
    unemployment,
    brackets,
  ].where((v) => v != null).length;
}

class _SalaryParams {
  final Rational personal, dependant, socialCap, unemploymentCap;
  final Rational social, health, unemployment;
  final List<SalaryBracket> brackets;
  final Rational? insured;
  const _SalaryParams(
    this.personal,
    this.dependant,
    this.socialCap,
    this.unemploymentCap,
    this.social,
    this.health,
    this.unemployment,
    this.brackets,
    this.insured,
  );
}

/// One month of a Vietnamese employee's pay, computed from gross. All
/// amounts are whole đồng; every row adds up to [net].
class SalaryBreakdown {
  final int gross, insured, social, health, unemployment;
  final int personal, dependants, taxable, tax, net;
  final int socialCap, unemploymentCap;

  /// Each bracket the taxable income reaches: its bounds, rate, the part of
  /// the income in it and the tax on that part.
  final List<({int from, int? upTo, String rate, int amount, int tax})>
  brackets;
  const SalaryBreakdown({
    required this.gross,
    required this.insured,
    required this.social,
    required this.health,
    required this.unemployment,
    required this.personal,
    required this.dependants,
    required this.taxable,
    required this.tax,
    required this.net,
    required this.socialCap,
    required this.unemploymentCap,
    required this.brackets,
  });
  int get insurance => social + health + unemployment;
}

int _round(Rational v) => _roundedRatio(v.numerator, v.denominator).toInt();

_SalaryParams _params(
  SalaryRules rules,
  int region,
  int dependantCount,
  SalaryOverrides o,
) {
  if (region < 1 || region > 4) throw const FormatException('Region 1–4');
  if (dependantCount < 0 || dependantCount > 20) {
    throw const FormatException('Dependants: 0–20');
  }
  Rational percent(String value) {
    final r = _d(value);
    if (r < _zero || r > Rational.fromInt(20)) {
      throw const FormatException('Insurance rates must be 0–20 %');
    }
    return r / _hundred;
  }

  int amount(int value) {
    if (value < 0 || value > 100000000000) {
      throw const FormatException('Amounts must be 0–100,000,000,000 đ');
    }
    return value;
  }

  final base = amount(o.base ?? rules.base),
      minimum = amount(o.regionalMinimum ?? rules.regionalMinimum[region - 1]),
      social = percent(o.social ?? rules.social),
      health = percent(o.health ?? rules.health),
      unemployment = percent(o.unemployment ?? rules.unemployment);
  if (social + health + unemployment >= _one) {
    throw const FormatException('Insurance rates must stay under 100 %');
  }
  return _SalaryParams(
    Rational.fromInt(amount(o.personal ?? rules.personal)),
    Rational.fromInt(amount(o.dependant ?? rules.dependant) * dependantCount),
    Rational.fromInt(base * rules.capTimes),
    Rational.fromInt(minimum * rules.capTimes),
    social,
    health,
    unemployment,
    o.brackets ?? rules.brackets,
    o.insured == null ? null : Rational.fromInt(amount(o.insured!)),
  );
}

Rational _min2(Rational a, Rational b) => a < b ? a : b;

/// Net pay as an exact rational, without rounding: strictly increasing in
/// [gross], so Net → Gross can search it.
Rational _netExact(_SalaryParams p, Rational gross) {
  final insured = p.insured ?? gross;
  final ins =
      _min2(insured, p.socialCap) * (p.social + p.health) +
      _min2(insured, p.unemploymentCap) * p.unemployment;
  var taxable = gross - ins - p.personal - p.dependant;
  if (taxable < _zero) taxable = _zero;
  return gross - ins - _bracketTax(p.brackets, taxable);
}

Rational _bracketTax(List<SalaryBracket> brackets, Rational taxable) {
  var tax = _zero, from = _zero;
  for (final b in brackets) {
    if (taxable <= from) break;
    final top = b.upTo == null
        ? taxable
        : _min2(taxable, Rational.fromInt(b.upTo!));
    tax += (top - from) * _d(b.rate) / _hundred;
    if (b.upTo == null) break;
    from = Rational.fromInt(b.upTo!);
  }
  return tax;
}

SalaryBreakdown _breakdown(_SalaryParams p, int gross) {
  final g = Rational.fromInt(gross);
  final insuredValue = p.insured ?? g;
  final socialBase = _min2(insuredValue, p.socialCap),
      unemploymentBase = _min2(insuredValue, p.unemploymentCap);
  final social = _round(socialBase * p.social),
      health = _round(socialBase * p.health),
      unemployment = _round(unemploymentBase * p.unemployment);
  final personal = _round(p.personal), dependants = _round(p.dependant);
  final taxable = math.max(
    0,
    gross - social - health - unemployment - personal - dependants,
  );
  final rows = <({int from, int? upTo, String rate, int amount, int tax})>[];
  var from = 0;
  for (final b in p.brackets) {
    if (taxable <= from) break;
    final top = b.upTo == null ? taxable : math.min(taxable, b.upTo!);
    final part = top - from;
    rows.add((
      from: from,
      upTo: b.upTo,
      rate: b.rate,
      amount: part,
      tax: _round(Rational.fromInt(part) * _d(b.rate) / _hundred),
    ));
    if (b.upTo == null) break;
    from = b.upTo!;
  }
  // The total is the sum of the rounded rows, so the payslip adds up.
  final tax = rows.fold<int>(0, (n, r) => n + r.tax);
  return SalaryBreakdown(
    gross: gross,
    insured: _round(insuredValue),
    social: social,
    health: health,
    unemployment: unemployment,
    personal: personal,
    dependants: dependants,
    taxable: taxable,
    tax: tax,
    net: gross - social - health - unemployment - tax,
    socialCap: _round(p.socialCap),
    unemploymentCap: _round(p.unemploymentCap),
    brackets: rows,
  );
}

const _salaryLimit = 100000000000;

/// Gross → net. [gross] in đồng, rounded half up to a whole đồng.
SalaryBreakdown salaryFromGross(
  String gross, {
  required SalaryRules rules,
  int region = 1,
  int dependants = 0,
  SalaryOverrides overrides = const SalaryOverrides(),
}) {
  final g = _d(gross);
  if (g < _zero || g > Rational.fromInt(_salaryLimit)) {
    throw const FormatException('Salary must be 0–100,000,000,000 đ');
  }
  return _breakdown(_params(rules, region, dependants, overrides), _round(g));
}

/// Net → gross: the smallest whole-đồng gross whose exact net reaches
/// [net]. The breakdown is then computed forward from that gross, so its
/// rounded net may differ from the target by a đồng or two.
SalaryBreakdown salaryFromNet(
  String net, {
  required SalaryRules rules,
  int region = 1,
  int dependants = 0,
  SalaryOverrides overrides = const SalaryOverrides(),
}) {
  final target = _d(net);
  if (target < _zero || target > Rational.fromInt(_salaryLimit)) {
    throw const FormatException('Salary must be 0–100,000,000,000 đ');
  }
  final p = _params(rules, region, dependants, overrides);
  var low = 0, high = 1;
  while (_netExact(p, Rational.fromInt(high)) < target) {
    low = high;
    high *= 2;
    if (high > _salaryLimit * 10) {
      throw const FormatException('Gross would exceed the supported range');
    }
  }
  while (low < high) {
    final middle = low + (high - low) ~/ 2;
    if (_netExact(p, Rational.fromInt(middle)) >= target) {
      high = middle;
    } else {
      low = middle + 1;
    }
  }
  return _breakdown(p, low);
}

int? _optionalInt(Object? v, String name) {
  if (v == null || (v is String && v.trim().isEmpty)) return null;
  final s = '$v'.trim().replaceAll(RegExp(r'[., ]'), '');
  final n = int.tryParse(s);
  if (n == null) throw FormatException('$name must be a whole number of đồng');
  return n;
}

String? _optionalRate(Object? v) {
  if (v == null || (v is String && v.trim().isEmpty)) return null;
  final s = '$v'.trim().replaceAll(',', '.');
  _d(s);
  return s;
}

/// The registry runner: [input] is the amount, [options] a JSON object
/// `{"mode":"gross"|"net","date":"YYYY-MM-DD","region":1-4,"dependants":n,
/// "overrides":{...}}`.
String runSalary(String input, String options) {
  final o = jsonDecode(options.isEmpty ? '{}' : options);
  if (o is! Map) throw const FormatException('Salary options must be JSON');
  final mode = o['mode'] ?? 'gross';
  if (mode != 'gross' && mode != 'net') {
    throw const FormatException('Mode is gross or net');
  }
  final region = int.tryParse('${o['region'] ?? 1}'),
      dependants = int.tryParse('${o['dependants'] ?? 0}');
  if (region == null || dependants == null) {
    throw const FormatException('Region and dependants are whole numbers');
  }
  final date = '${o['date'] ?? ''}';
  final rules = salaryRulesOn(date);
  final raw = o['overrides'] ?? const {};
  if (raw is! Map) throw const FormatException('Overrides must be an object');
  final brackets = raw['brackets'];
  final overrides = SalaryOverrides(
    insured: _optionalInt(raw['insured'], 'Insured salary'),
    personal: _optionalInt(raw['personal'], 'Personal deduction'),
    dependant: _optionalInt(raw['dependant'], 'Dependant deduction'),
    base: _optionalInt(raw['base'], 'Base salary'),
    regionalMinimum: _optionalInt(raw['regionalMinimum'], 'Minimum wage'),
    social: _optionalRate(raw['social']),
    health: _optionalRate(raw['health']),
    unemployment: _optionalRate(raw['unemployment']),
    brackets: brackets == null || '$brackets'.trim().isEmpty
        ? null
        : parseSalaryBrackets('$brackets'),
  );
  final amount = input.trim();
  final b = mode == 'gross'
      ? salaryFromGross(
          amount,
          rules: rules,
          region: region,
          dependants: dependants,
          overrides: overrides,
        )
      : salaryFromNet(
          amount,
          rules: rules,
          region: region,
          dependants: dependants,
          overrides: overrides,
        );
  return _json({
    'mode': mode,
    'rulesFrom': rules.from,
    'sources': rules.sources,
    'overridden': overrides.count,
    'dependantCount': dependants,
    'region': region,
    'gross': '${b.gross}',
    'insured': '${b.insured}',
    'social': '${b.social}',
    'health': '${b.health}',
    'unemployment': '${b.unemployment}',
    'socialRate': overrides.social ?? rules.social,
    'healthRate': overrides.health ?? rules.health,
    'unemploymentRate': overrides.unemployment ?? rules.unemployment,
    'socialCap': '${b.socialCap}',
    'unemploymentCap': '${b.unemploymentCap}',
    'personal': '${b.personal}',
    'dependants': '${b.dependants}',
    'taxable': '${b.taxable}',
    'brackets': [
      for (final r in b.brackets)
        {
          'from': '${r.from}',
          'upTo': r.upTo == null ? null : '${r.upTo}',
          'rate': r.rate,
          'amount': '${r.amount}',
          'tax': '${r.tax}',
        },
    ],
    'tax': '${b.tax}',
    'net': '${b.net}',
    if (mode == 'net') 'target': _fixed(_d(amount), 0),
  });
}
