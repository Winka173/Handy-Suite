import 'dart:convert';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/kit.dart';
import 'vn_specs.dart';

/// UI description of every engine tool: real fields instead of the engine's
/// comma/JSON syntax, and how its output is presented. The engine stays the
/// single source of truth for computation and validation.
enum FieldType { decimal, integer, date, text, longText, color, choice }

typedef Choice = (String value, String en, String vi);

class FieldSpec {
  final String id, en, vi, initial, hint;
  final FieldType type;
  final bool optional;
  final List<Choice> Function(Map<String, String> values)? choices;

  /// Kept behind the form's "rules in use" toggle until the user opens it.
  final bool advanced;

  /// Choices drawn as joined buttons even past three options.
  final bool segmented;

  /// Shown only while this holds for the current values.
  final bool Function(Map<String, String> values)? visibleWhen;

  /// A hint computed from the other values, such as the table value an
  /// empty override falls back to.
  final String Function(Map<String, String> values)? hintOf;
  const FieldSpec(
    this.id,
    this.en,
    this.vi,
    this.type, {
    this.initial = '',
    this.hint = '',
    this.optional = false,
    this.choices,
    this.advanced = false,
    this.segmented = false,
    this.visibleWhen,
    this.hintOf,
  });
  String label(BuildContext c) => tr(c, en, vi);
  bool visible(Map<String, String> values) => visibleWhen?.call(values) ?? true;
}

enum Category { numbers, money, dates, text }

String categoryLabel(BuildContext c, Category k) => switch (k) {
  Category.numbers => tr(c, 'Numbers', 'Số'),
  Category.money => tr(c, 'Money', 'Tiền'),
  Category.dates => tr(c, 'Dates', 'Ngày'),
  Category.text => tr(c, 'Text', 'Văn bản'),
};

/// How a computed output is shown.
sealed class Output {
  const Output();
}

/// One answer, set large.
class ValueOutput extends Output {
  final String value, caption;
  final bool money;
  const ValueOutput(this.value, {this.caption = '', this.money = false});
}

/// Labelled figures; [lead] answers the tool's question. [note] is one
/// grey line under them (the rules a figure came from).
class RowsOutput extends Output {
  final List<(String, String)> rows;
  final int lead;
  final String copy, note;
  const RowsOutput(this.rows, this.copy, {this.lead = 0, this.note = ''});
}

/// A number in words: [words] answers and is what Copy takes; [other] is
/// the second language under it, with its own copy action.
class WordsOutput extends Output {
  final String words, other, caption;
  const WordsOutput(this.words, this.other, {this.caption = ''});
}

/// Transformed text.
class TextOutput extends Output {
  final String text;
  const TextOutput(this.text);
}

/// Loan summary plus the full schedule.
class ScheduleOutput extends RowsOutput {
  final List<List<String>> schedule;
  const ScheduleOutput(super.rows, super.copy, this.schedule);
}

class ToolSpec {
  final String id;
  final IconData icon;
  final Category category;
  final String en, vi;
  final List<FieldSpec> fields;
  final (String, String) Function(Map<String, String> v) encode;
  final Output Function(BuildContext c, String raw, Map<String, String> v)
  present;

  /// The empty state's sentence, when the generic one says too little.
  final (String, String)? empty;

  /// Names the advanced fields' toggle from the current values.
  final String Function(BuildContext c, Map<String, String> v)? advancedLabel;
  const ToolSpec(
    this.id,
    this.icon,
    this.category,
    this.en,
    this.vi, {
    required this.fields,
    required this.encode,
    required this.present,
    this.empty,
    this.advancedLabel,
  });
  ToolDefinition get engine => tools.firstWhere((t) => t.id == id);
  String title(BuildContext c) => tr(c, engine.titleEn, engine.titleVi);
  String hint(BuildContext c) => tr(c, en, vi);
  bool get textTool =>
      fields.length == 1 && fields.first.type == FieldType.longText;
}

const _unitNames = {'us-gal': 'US gal', 'm2': 'm²', 'km2': 'km²'};
String unitName(String u) => _unitNames[u] ?? u;
const _unitKinds = {
  'length': ('Length', 'Độ dài'),
  'mass': ('Weight', 'Khối lượng'),
  'volume': ('Volume', 'Thể tích'),
  'area': ('Area', 'Diện tích'),
  'speed': ('Speed', 'Tốc độ'),
  'time': ('Time', 'Thời gian'),
  'data': ('Data', 'Dữ liệu'),
  'temperature': ('Temperature', 'Nhiệt độ'),
};
List<Choice> _units(Map<String, String> v) => [
  for (final u in unitGroups[v['kind']] ?? unitGroups['length']!)
    (u, unitName(u), unitName(u)),
];

Map<String, Object?> _json(String raw) => decodeObject(raw);
Map<String, Object?> decodeObject(String raw) =>
    (jsonDecode(raw) as Map).cast<String, Object?>();
String _today() => today();
String today() => DateTime.now().toIso8601String().substring(0, 10);
String copyRows(List<(String, String)> rows, [String note = '']) => [
  ...rows.map((r) => '${r.$1}: ${r.$2}'),
  if (note.isNotEmpty) note,
].join('\n');
RowsOutput _rows(List<(String, String)> rows, {int lead = 0}) =>
    RowsOutput(rows, copyRows(rows), lead: lead);

const _text = FieldSpec('text', 'Text', 'Văn bản', FieldType.longText);

ToolSpec _textTool(String id, IconData icon, String en, String vi) => ToolSpec(
  id,
  icon,
  Category.text,
  en,
  vi,
  fields: const [_text],
  encode: (v) => (v['text']!, ''),
  present: (c, raw, v) => TextOutput(raw),
);

final List<ToolSpec> specs = [
  ToolSpec(
    'calculate',
    Icons.calculate_outlined,
    Category.numbers,
    'Exact decimals. + − * / % ^, brackets, sqrt, sin, cos, tan, log (radians).',
    'Số thập phân chính xác. + − * / % ^, ngoặc, sqrt, sin, cos, tan, log (radian).',
    fields: const [
      FieldSpec(
        'expression',
        'Expression',
        'Biểu thức',
        FieldType.text,
        hint: '12 * (3 + 4)',
      ),
    ],
    encode: (v) => (v['expression']!, ''),
    present: (c, raw, v) => ValueOutput(raw),
  ),
  ToolSpec(
    'units',
    Icons.straighten,
    Category.numbers,
    'Length, weight, volume, area, speed, time, data and temperature.',
    'Độ dài, khối lượng, thể tích, diện tích, tốc độ, thời gian, dữ liệu, nhiệt độ.',
    fields: [
      FieldSpec(
        'kind',
        'Measure',
        'Đại lượng',
        FieldType.choice,
        initial: 'length',
        choices: (_) => [
          for (final e in _unitKinds.entries) (e.key, e.value.$1, e.value.$2),
        ],
      ),
      const FieldSpec('value', 'Value', 'Giá trị', FieldType.decimal),
      const FieldSpec(
        'from',
        'From',
        'Từ',
        FieldType.choice,
        initial: 'm',
        choices: _units,
      ),
      const FieldSpec(
        'to',
        'To',
        'Sang',
        FieldType.choice,
        initial: 'cm',
        choices: _units,
      ),
    ],
    encode: (v) => (v['value']!, '${v['from']},${v['to']}'),
    present: (c, raw, v) => ValueOutput(
      '$raw ${unitName(v['to']!)}',
      caption: '${v['value']} ${unitName(v['from']!)} =',
    ),
  ),
  numberWordsSpec,
  ToolSpec(
    'loan',
    Icons.account_balance_outlined,
    Category.money,
    'Fixed yearly rate, monthly payments. Fees and taxes not included.',
    'Lãi suất năm cố định, trả hằng tháng. Chưa gồm phí và thuế.',
    fields: const [
      FieldSpec('principal', 'Loan amount', 'Số tiền vay', FieldType.decimal),
      FieldSpec('rate', 'Yearly rate %', 'Lãi suất năm %', FieldType.decimal),
      FieldSpec(
        'months',
        'Months',
        'Số tháng',
        FieldType.integer,
        initial: '12',
      ),
    ],
    encode: (v) => ('${v['principal']},${v['rate']},${v['months']}', ''),
    present: (c, raw, v) {
      final lines = raw.split('\n').skip(1).map((l) => l.split(',')).toList();
      var interest = 0.0, paid = 0.0;
      for (final l in lines) {
        interest += double.parse(l[2]);
        paid += double.parse(l[1]);
      }
      final rows = [
        (tr(c, 'Monthly payment', 'Trả mỗi tháng'), lines.first[1]),
        (tr(c, 'Total interest', 'Tổng tiền lãi'), interest.toStringAsFixed(2)),
        (tr(c, 'Total paid', 'Tổng phải trả'), paid.toStringAsFixed(2)),
      ];
      return ScheduleOutput(rows, raw, lines);
    },
  ),
  ToolSpec(
    'compound',
    Icons.savings_outlined,
    Category.money,
    'Savings with compound interest. No extra deposits, tax or fees.',
    'Tiết kiệm lãi kép. Không gửi thêm, không thuế, không phí.',
    fields: [
      const FieldSpec('principal', 'Deposit', 'Tiền gửi', FieldType.decimal),
      const FieldSpec(
        'rate',
        'Yearly rate %',
        'Lãi suất năm %',
        FieldType.decimal,
      ),
      const FieldSpec(
        'years',
        'Years',
        'Số năm',
        FieldType.decimal,
        initial: '1',
      ),
      FieldSpec(
        'n',
        'Interest added',
        'Nhập lãi',
        FieldType.choice,
        initial: '12',
        choices: (_) => const [
          ('1', 'Yearly', 'Hằng năm'),
          ('4', 'Quarterly', 'Hằng quý'),
          ('12', 'Monthly', 'Hằng tháng'),
          ('365', 'Daily', 'Hằng ngày'),
        ],
      ),
    ],
    encode: (v) =>
        ('${v['principal']},${v['rate']},${v['years']},${v['n']}', ''),
    present: (c, raw, v) => ValueOutput(
      raw,
      money: true,
      caption: tr(
        c,
        'Balance after ${v['years']} years',
        'Số dư sau ${v['years']} năm',
      ),
    ),
  ),
  salarySpec,
  ToolSpec(
    'split-bill',
    Icons.groups_outlined,
    Category.money,
    'Cents are shared exactly; any extra cent goes to the first people.',
    'Chia chính xác đến xu; xu lẻ dồn cho những người đầu.',
    fields: const [
      FieldSpec('amount', 'Bill', 'Hóa đơn', FieldType.decimal),
      FieldSpec('tip', 'Tip %', 'Tip %', FieldType.decimal, initial: '0'),
      FieldSpec(
        'people',
        'People',
        'Số người',
        FieldType.integer,
        initial: '2',
      ),
    ],
    encode: (v) => ('${v['amount']},${v['tip']},${v['people']}', ''),
    present: (c, raw, v) {
      final j = _json(raw), shares = (j['shares'] as List).cast<String>();
      final even = shares.toSet().length == 1;
      return _rows([
        (
          tr(c, 'Each person pays', 'Mỗi người trả'),
          even ? shares.first : '${shares.last} – ${shares.first}',
        ),
        (tr(c, 'Total with tip', 'Tổng kèm tip'), '${j['total']}'),
        if (!even)
          for (var i = 0; i < shares.length && i < 50; i++)
            (tr(c, 'Person ${i + 1}', 'Người ${i + 1}'), shares[i]),
      ]);
    },
  ),
  ToolSpec(
    'dates',
    Icons.date_range_outlined,
    Category.dates,
    'Calendar days from the first date to the second.',
    'Số ngày lịch từ ngày đầu đến ngày sau.',
    fields: [
      FieldSpec('start', 'From', 'Từ ngày', FieldType.date, initial: _today()),
      const FieldSpec('end', 'To', 'Đến ngày', FieldType.date),
    ],
    encode: (v) => ('${v['start']},${v['end']}', ''),
    present: (c, raw, v) => ValueOutput(tr(c, '$raw days', '$raw ngày')),
  ),
  ToolSpec(
    'business-days',
    Icons.work_outline,
    Category.dates,
    'Counts the first day, not the last.',
    'Tính ngày đầu, không tính ngày cuối.',
    fields: [
      FieldSpec('start', 'From', 'Từ ngày', FieldType.date, initial: _today()),
      const FieldSpec('end', 'To', 'Đến ngày', FieldType.date),
      FieldSpec(
        'weekend',
        'Weekend',
        'Cuối tuần',
        FieldType.choice,
        initial: '0,6',
        choices: (_) => const [
          ('0,6', 'Sat + Sun', 'T7 + CN'),
          ('0', 'Sun only', 'Chỉ CN'),
          ('5,6', 'Fri + Sat', 'T6 + T7'),
        ],
      ),
      const FieldSpec(
        'holidays',
        'Holidays',
        'Ngày nghỉ lễ',
        FieldType.text,
        optional: true,
        hint: '2026-01-01, 2026-04-30',
      ),
    ],
    encode: (v) => (
      '${v['start']},${v['end']}',
      '${v['weekend']}|${v['holidays']!.replaceAll(' ', '')}',
    ),
    present: (c, raw, v) =>
        ValueOutput(tr(c, '$raw working days', '$raw ngày làm việc')),
  ),
  lunarSpec,
  _textTool(
    'normalize',
    Icons.space_bar,
    'Trims each line and collapses runs of spaces.',
    'Cắt khoảng trắng đầu/cuối dòng và gộp khoảng trắng thừa.',
  ),
  _textTool(
    'deduplicate',
    Icons.filter_list,
    'Keeps the first copy of each line.',
    'Giữ dòng xuất hiện đầu tiên.',
  ),
  _textTool(
    'sort',
    Icons.sort_by_alpha,
    'A to Z by character code.',
    'A đến Z theo mã ký tự.',
  ),
  caseSpec,
  _textTool(
    'accents',
    Icons.font_download_off_outlined,
    'Tiếng Việt → Tieng Viet, including đ.',
    'Tiếng Việt → Tieng Viet, gồm cả đ.',
  ),
  ToolSpec(
    'count',
    Icons.numbers,
    Category.text,
    'Characters, words and lines.',
    'Số ký tự, từ và dòng.',
    fields: const [_text],
    encode: (v) => (v['text']!, ''),
    present: (c, raw, v) {
      final j = _json(raw);
      return _rows([
        (tr(c, 'Characters', 'Ký tự'), '${j['codePoints']}'),
        (tr(c, 'Words', 'Từ'), '${j['words']}'),
        (tr(c, 'Lines', 'Dòng'), '${j['lines']}'),
        (tr(c, 'UTF-16 units', 'Đơn vị UTF-16'), '${j['utf16Units']}'),
      ]);
    },
  ),
  ToolSpec(
    'literal-replace',
    Icons.find_replace,
    Category.text,
    'Exact text, not patterns.',
    'Khớp chính xác, không dùng mẫu.',
    fields: [
      _text,
      const FieldSpec('find', 'Find', 'Tìm', FieldType.text),
      const FieldSpec(
        'replace',
        'Replace with',
        'Thay bằng',
        FieldType.text,
        optional: true,
      ),
      FieldSpec(
        'all',
        'Replace',
        'Thay',
        FieldType.choice,
        initial: 'all',
        choices: (_) => const [
          ('all', 'Every match', 'Tất cả'),
          ('first', 'First match', 'Chỗ đầu tiên'),
        ],
      ),
    ],
    encode: (v) => (
      v['text']!,
      jsonEncode({
        'find': v['find'],
        'replace': v['replace'],
        'all': v['all'] == 'all',
      }),
    ),
    present: (c, raw, v) => TextOutput(raw),
  ),
];

final Map<String, ToolSpec> specById = {for (final s in specs) s.id: s};

/// The four case tools became one `case` tool. Their ids live on as text
/// chain steps (saved chains keep working) and as old links and pins.
const caseSteps = {
  'uppercase': 'upper',
  'lowercase': 'lower',
  'title-case': 'title',
  'sentence-case': 'sentence',
};

/// The tool an id opens today: an old case id opens `case`.
String canonicalToolId(String id) => caseSteps.containsKey(id) ? 'case' : id;

/// Values an old id brings with it (its case mode).
Map<String, String> legacyValues(String id) =>
    caseSteps[id] == null ? const {} : {'mode': caseSteps[id]!};

/// A text chain step's name, and running it.
String stepTitle(BuildContext c, String id) => switch (caseSteps[id]) {
  'upper' => tr(c, 'Uppercase', 'Viết hoa'),
  'lower' => tr(c, 'Lowercase', 'Viết thường'),
  'title' => tr(c, 'Title case', 'Viết hoa đầu từ'),
  'sentence' => tr(c, 'Sentence case', 'Viết hoa đầu câu'),
  _ => specById[id]!.title(c),
};
String runStep(String id, String text) => caseSteps[id] == null
    ? specById[id]!.engine.run(text)
    : specById['case']!.engine.run(text, caseSteps[id]!);
