import 'dart:convert';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/kit.dart';
import 'bench/intent.dart' show normalizeNumber;
import 'specs.dart';

/// Specs for the tools added in 2026-11: one `case` tool, Vietnamese salary,
/// numbers in words and the lunar calendar. Engines compute; these only
/// describe fields and how answers read.

const _text = FieldSpec('text', 'Text', 'Văn bản', FieldType.longText);

final caseSpec = ToolSpec(
  'case',
  Icons.text_fields,
  Category.text,
  'UPPER, lower, Title Case or Sentence case.',
  'VIẾT HOA, viết thường, Viết Hoa Đầu Từ hoặc Viết hoa đầu câu.',
  fields: [
    _text,
    FieldSpec(
      'mode',
      'Write it',
      'Viết lại',
      FieldType.choice,
      initial: 'upper',
      segmented: true,
      choices: (_) => const [
        ('upper', 'UPPER', 'HOA'),
        ('lower', 'lower', 'thường'),
        ('title', 'Title', 'Đầu Từ'),
        ('sentence', 'Sentence', 'Đầu câu'),
      ],
    ),
  ],
  encode: (v) => (v['text']!, v['mode']!),
  present: (c, raw, v) => TextOutput(raw),
);

/// Money as people type it: `25.000.000`, `25,000,000` or `25000000`.
String moneyInput(String s) {
  final t = s.replaceAll(' ', '');
  return RegExp(r'^\d{1,3}([.,])\d{3}(\1\d{3})*$').hasMatch(t)
      ? t.replaceAll(RegExp(r'[.,]'), '')
      : t.replaceAll(',', '.');
}

String _dong(Object? v) => '$v đ';
String _minus(Object? v) => v == '0' ? '0 đ' : '-$v đ';
String _rate(BuildContext c, Object? r) =>
    tr(c, '$r', '$r'.replaceAll('.', ','));

SalaryRules? _rulesFor(Map<String, String> v) {
  try {
    return salaryRulesOn(v['date'] ?? '');
  } on FormatException {
    return null;
  }
}

String _tableHint(
  Map<String, String> v,
  String Function(SalaryRules r, int region) pick,
) {
  final r = _rulesFor(v);
  if (r == null) return '';
  final region = (int.tryParse(v['region'] ?? '1') ?? 1).clamp(1, 4);
  return pick(r, region);
}

String _grouped(int n) {
  final s = '$n', out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return out.toString();
}

String _hintInsured(Map<String, String> v) => '= Gross';
String _hintPersonal(Map<String, String> v) =>
    _tableHint(v, (r, _) => _grouped(r.personal));
String _hintDependant(Map<String, String> v) =>
    _tableHint(v, (r, _) => _grouped(r.dependant));
String _hintBase(Map<String, String> v) =>
    _tableHint(v, (r, _) => _grouped(r.base));
String _hintMinimum(Map<String, String> v) =>
    _tableHint(v, (r, region) => _grouped(r.regionalMinimum[region - 1]));
String _hintSocial(Map<String, String> v) => _tableHint(v, (r, _) => r.social);
String _hintHealth(Map<String, String> v) => _tableHint(v, (r, _) => r.health);
String _hintUnemployment(Map<String, String> v) =>
    _tableHint(v, (r, _) => r.unemployment);
String _hintBrackets(Map<String, String> v) =>
    _tableHint(v, (r, _) => r.bracketText);
String _hintAmount(Map<String, String> v) =>
    v['mode'] == 'net' ? '20.000.000' : '30.000.000';

const _overrides = [
  'insured',
  'personal',
  'dependant',
  'base',
  'regionalMinimum',
  'social',
  'health',
  'unemployment',
  'brackets',
];

final salarySpec = ToolSpec(
  'salary',
  Icons.payments_outlined,
  Category.money,
  'Vietnamese payroll: insurance with its caps, family deductions and income tax by bracket.',
  'Lương Việt Nam: bảo hiểm có trần, giảm trừ gia cảnh và thuế TNCN theo từng bậc.',
  empty: (
    'Enter the gross or the take-home pay — the payslip appears here.',
    'Nhập lương gộp hoặc thực nhận — phiếu lương hiện ở đây.',
  ),
  advancedLabel: (c, v) {
    final r = _rulesFor(v);
    final changed = _overrides.where((k) => (v[k] ?? '').isNotEmpty).length;
    final rules = r == null
        ? tr(c, 'Rules in use', 'Quy định đang dùng')
        : tr(c, 'Rules from ${r.from}', 'Quy định từ ${r.from}');
    return changed == 0
        ? tr(c, '$rules · edit', '$rules · sửa')
        : tr(c, '$rules · $changed changed', '$rules · đã sửa $changed');
  },
  fields: [
    FieldSpec(
      'mode',
      'Work out',
      'Tính',
      FieldType.choice,
      initial: 'gross',
      choices: (_) => const [
        ('gross', 'Gross → net', 'Gross → Net'),
        ('net', 'Net → gross', 'Net → Gross'),
      ],
    ),
    const FieldSpec(
      'amount',
      'Amount (đ)',
      'Số tiền (đ)',
      FieldType.decimal,
      hintOf: _hintAmount,
    ),
    const FieldSpec(
      'dependants',
      'Dependants',
      'Người phụ thuộc',
      FieldType.integer,
      initial: '0',
    ),
    FieldSpec(
      'region',
      'Region (unemployment cap)',
      'Vùng (trần BHTN)',
      FieldType.choice,
      initial: '1',
      segmented: true,
      choices: (_) => const [
        ('1', 'I', 'I'),
        ('2', 'II', 'II'),
        ('3', 'III', 'III'),
        ('4', 'IV', 'IV'),
      ],
    ),
    FieldSpec(
      'date',
      'Rules on',
      'Áp dụng quy định ngày',
      FieldType.date,
      initial: today(),
    ),
    const FieldSpec(
      'insured',
      'Salary for insurance (đ)',
      'Lương đóng bảo hiểm (đ)',
      FieldType.decimal,
      optional: true,
      advanced: true,
      hintOf: _hintInsured,
    ),
    const FieldSpec(
      'personal',
      'Personal deduction (đ)',
      'Giảm trừ bản thân (đ)',
      FieldType.decimal,
      optional: true,
      advanced: true,
      hintOf: _hintPersonal,
    ),
    const FieldSpec(
      'dependant',
      'Per dependant (đ)',
      'Mỗi người phụ thuộc (đ)',
      FieldType.decimal,
      optional: true,
      advanced: true,
      hintOf: _hintDependant,
    ),
    const FieldSpec(
      'base',
      'Base salary (cap = 20×) (đ)',
      'Lương cơ sở (trần = 20×) (đ)',
      FieldType.decimal,
      optional: true,
      advanced: true,
      hintOf: _hintBase,
    ),
    const FieldSpec(
      'regionalMinimum',
      'Regional minimum wage (đ)',
      'Lương tối thiểu vùng (đ)',
      FieldType.decimal,
      optional: true,
      advanced: true,
      hintOf: _hintMinimum,
    ),
    const FieldSpec(
      'social',
      'Social insurance %',
      'BHXH %',
      FieldType.decimal,
      optional: true,
      advanced: true,
      hintOf: _hintSocial,
    ),
    const FieldSpec(
      'health',
      'Health insurance %',
      'BHYT %',
      FieldType.decimal,
      optional: true,
      advanced: true,
      hintOf: _hintHealth,
    ),
    const FieldSpec(
      'unemployment',
      'Unemployment insurance %',
      'BHTN %',
      FieldType.decimal,
      optional: true,
      advanced: true,
      hintOf: _hintUnemployment,
    ),
    const FieldSpec(
      'brackets',
      'Tax brackets (up to đ = %)',
      'Biểu thuế (đến đ = %)',
      FieldType.text,
      optional: true,
      advanced: true,
      hintOf: _hintBrackets,
    ),
  ],
  encode: (v) => (
    moneyInput(v['amount']!),
    jsonEncode({
      'mode': v['mode'],
      'date': v['date'],
      'region': v['region'],
      'dependants': v['dependants'],
      'overrides': {
        for (final k in _overrides)
          if ((v[k] ?? '').isNotEmpty) k: v[k],
      },
    }),
  ),
  present: (c, raw, v) {
    final j = decodeObject(raw);
    final net = j['mode'] == 'net';
    final dependants = j['dependantCount'];
    final rows = <(String, String)>[
      if (net) ...[
        (tr(c, 'Gross to pay', 'Lương gộp cần trả'), _dong(j['gross'])),
        (tr(c, 'Take-home', 'Thực nhận'), _dong(j['net'])),
      ] else ...[
        (tr(c, 'Take-home', 'Thực nhận'), _dong(j['net'])),
        (tr(c, 'Gross', 'Lương gộp'), _dong(j['gross'])),
      ],
      (
        tr(
          c,
          'Social insurance ${_rate(c, j['socialRate'])}%',
          'BHXH ${_rate(c, j['socialRate'])}%',
        ),
        _minus(j['social']),
      ),
      (
        tr(
          c,
          'Health insurance ${_rate(c, j['healthRate'])}%',
          'BHYT ${_rate(c, j['healthRate'])}%',
        ),
        _minus(j['health']),
      ),
      (
        tr(
          c,
          'Unemployment ${_rate(c, j['unemploymentRate'])}%',
          'BHTN ${_rate(c, j['unemploymentRate'])}%',
        ),
        _minus(j['unemployment']),
      ),
      // The payslip above adds up to the take-home; the rows below show
      // how the income tax was worked out.
      (tr(c, 'Income tax', 'Thuế TNCN'), _minus(j['tax'])),
      (tr(c, 'Personal deduction', 'Giảm trừ bản thân'), _dong(j['personal'])),
      if (dependants != 0)
        (
          tr(
            c,
            'Deduction, $dependants dependants',
            'Giảm trừ $dependants người phụ thuộc',
          ),
          _dong(j['dependants']),
        ),
      (tr(c, 'Taxable income', 'Thu nhập tính thuế'), _dong(j['taxable'])),
      for (final (i, b) in (j['brackets'] as List).cast<Map>().indexed)
        (
          tr(
            c,
            'Bracket ${i + 1} · ${_rate(c, b['rate'])}% × ${formatFigure(c, '${b['amount']}')}',
            'Bậc ${i + 1} · ${_rate(c, b['rate'])}% × ${formatFigure(c, '${b['amount']}')}',
          ),
          _dong(b['tax']),
        ),
    ];
    final changed = j['overridden'] as int;
    final note = [
      tr(c, 'Rules from ${j['rulesFrom']}', 'Quy định từ ${j['rulesFrom']}'),
      (j['sources'] as List).join(', '),
      tr(
        c,
        'Caps: social and health ${formatFigure(c, '${j['socialCap']}')} đ, unemployment ${formatFigure(c, '${j['unemploymentCap']}')} đ',
        'Trần: BHXH, BHYT ${formatFigure(c, '${j['socialCap']}')} đ, BHTN ${formatFigure(c, '${j['unemploymentCap']}')} đ',
      ),
      if (changed > 0)
        tr(c, 'You changed $changed values', 'Bạn đã sửa $changed tham số'),
      if (net && j['net'] != j['target'])
        tr(
          c,
          'Rounding to whole đồng: nearest take-home ${formatFigure(c, '${j['net']}')} đ',
          'Làm tròn đến đồng: thực nhận gần nhất ${formatFigure(c, '${j['net']}')} đ',
        ),
    ].join(' · ');
    return RowsOutput(rows, copyRows(rows, note), note: note);
  },
);

final numberWordsSpec = ToolSpec(
  'number-words',
  Icons.spellcheck,
  Category.numbers,
  'The "in words" line of an invoice, in Vietnamese and English.',
  'Dòng "bằng chữ" trên hóa đơn, tiếng Việt và tiếng Anh.',
  fields: [
    const FieldSpec(
      'number',
      'Number',
      'Số',
      FieldType.text,
      hint: '1.250.000',
    ),
    FieldSpec(
      'unit',
      'Unit',
      'Đơn vị',
      FieldType.choice,
      initial: 'dong',
      choices: (_) => const [
        ('dong', 'Đồng', 'Đồng'),
        ('none', 'Number only', 'Chỉ đọc số'),
      ],
    ),
    FieldSpec(
      'style',
      'Reading',
      'Cách đọc',
      FieldType.choice,
      initial: 'north',
      choices: (_) => const [
        ('north', 'linh, nghìn', 'linh, nghìn'),
        ('south', 'lẻ, ngàn', 'lẻ, ngàn'),
      ],
    ),
  ],
  encode: (v) {
    final n = v['number']!.trim();
    return (
      normalizeNumber(n, vi: true) ?? n,
      'unit=${v['unit']};style=${v['style']}',
    );
  },
  present: (c, raw, v) {
    final j = decodeObject(raw);
    return WordsOutput(
      '${j['vi']}',
      '${j['en']}',
      caption: tr(
        c,
        'In words · read as ${formatFigure(c, '${j['number']}')}',
        'Bằng chữ · đã hiểu số là ${formatFigure(c, '${j['number']}')}',
      ),
    );
  },
);

bool _solar(Map<String, String> v) => v['direction'] != 'lunar';
bool _lunar(Map<String, String> v) => v['direction'] == 'lunar';

const _weekdays = [
  ('Monday', 'Thứ Hai'),
  ('Tuesday', 'Thứ Ba'),
  ('Wednesday', 'Thứ Tư'),
  ('Thursday', 'Thứ Năm'),
  ('Friday', 'Thứ Sáu'),
  ('Saturday', 'Thứ Bảy'),
  ('Sunday', 'Chủ nhật'),
];

final lunarSpec = ToolSpec(
  'lunar',
  Icons.brightness_3_outlined,
  Category.dates,
  'Vietnamese lunar calendar (UTC+7): leap months, can-chi and solar terms, 1900–2100.',
  'Âm lịch Việt Nam (UTC+7): tháng nhuận, can chi và tiết khí, 1900–2100.',
  fields: [
    FieldSpec(
      'direction',
      'Convert',
      'Đổi',
      FieldType.choice,
      initial: 'solar',
      choices: (_) => const [
        ('solar', 'Solar → lunar', 'Dương → Âm'),
        ('lunar', 'Lunar → solar', 'Âm → Dương'),
      ],
    ),
    FieldSpec(
      'date',
      'Solar date',
      'Ngày dương lịch',
      FieldType.date,
      initial: today(),
      visibleWhen: _solar,
    ),
    const FieldSpec(
      'lday',
      'Lunar day',
      'Ngày âm',
      FieldType.integer,
      initial: '1',
      visibleWhen: _lunar,
    ),
    FieldSpec(
      'lmonth',
      'Lunar month',
      'Tháng âm',
      FieldType.choice,
      initial: '1',
      visibleWhen: _lunar,
      choices: (_) => [
        for (var m = 1; m <= 12; m++)
          (
            '$m',
            'Month $m',
            m == 1 ? 'Tháng Giêng' : (m == 12 ? 'Tháng Chạp' : 'Tháng $m'),
          ),
      ],
    ),
    FieldSpec(
      'lyear',
      'Lunar year',
      'Năm âm',
      FieldType.integer,
      initial: today().substring(0, 4),
      visibleWhen: _lunar,
    ),
    FieldSpec(
      'leap',
      'Month kind',
      'Loại tháng',
      FieldType.choice,
      initial: 'no',
      visibleWhen: _lunar,
      choices: (_) => const [
        ('no', 'Regular', 'Tháng thường'),
        ('yes', 'Leap', 'Tháng nhuận'),
      ],
    ),
  ],
  encode: (v) => _lunar(v)
      ? (
          '${v['lyear']}-${v['lmonth']}-${v['lday']}',
          v['leap'] == 'yes' ? 'lunar-leap' : 'lunar',
        )
      : (v['date']!, 'solar'),
  present: (c, raw, v) {
    final j = decodeObject(raw);
    final leap = j['leap'] == true;
    final weekday = _weekdays[(j['weekday'] as int) - 1];
    final lunar =
        '${j['lunarDay']}/${j['lunarMonth']}/${j['lunarYear']}${leap ? tr(c, ' (leap)', ' (nhuận)') : ''}';
    final solar = '${j['solar']}';
    final rows = <(String, String)>[
      if (_lunar(v)) ...[
        (tr(c, 'Solar date', 'Dương lịch'), solar),
        (tr(c, 'Weekday', 'Thứ'), tr(c, weekday.$1, weekday.$2)),
        (tr(c, 'Lunar date', 'Âm lịch'), lunar),
      ] else ...[
        (tr(c, 'Lunar date', 'Âm lịch'), lunar),
        (
          tr(c, 'Solar date', 'Dương lịch'),
          '$solar · ${tr(c, weekday.$1, weekday.$2)}',
        ),
      ],
      (tr(c, 'Day', 'Ngày'), '${j['dayName']}'),
      (
        tr(c, 'Month', 'Tháng'),
        '${j['monthName']}${leap ? tr(c, ' (leap)', ' (nhuận)') : ''} · ${tr(c, '${j['monthDays']} days', '${j['monthDays']} ngày')}',
      ),
      (tr(c, 'Year', 'Năm'), '${j['yearName']}'),
      (
        tr(c, 'Solar term', 'Tiết khí'),
        '${j['term']}${j['termStarts'] == true ? tr(c, ' · starts today', ' · bắt đầu hôm nay') : ''}',
      ),
    ];
    return RowsOutput(rows, copyRows(rows));
  },
);
