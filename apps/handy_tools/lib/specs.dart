import 'dart:convert';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/kit.dart';

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
  const FieldSpec(
    this.id,
    this.en,
    this.vi,
    this.type, {
    this.initial = '',
    this.hint = '',
    this.optional = false,
    this.choices,
  });
  String label(BuildContext c) => tr(c, en, vi);
}

enum Category { numbers, money, dates, text, color }

String categoryLabel(BuildContext c, Category k) => switch (k) {
  Category.numbers => tr(c, 'Numbers', 'Số'),
  Category.money => tr(c, 'Money', 'Tiền'),
  Category.dates => tr(c, 'Dates', 'Ngày'),
  Category.text => tr(c, 'Text', 'Văn bản'),
  Category.color => tr(c, 'Colour', 'Màu sắc'),
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

/// Labelled figures; [lead] answers the tool's question.
class RowsOutput extends Output {
  final List<(String, String)> rows;
  final int lead;
  final String copy;
  const RowsOutput(this.rows, this.copy, {this.lead = 0});
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
  const ToolSpec(
    this.id,
    this.icon,
    this.category,
    this.en,
    this.vi, {
    required this.fields,
    required this.encode,
    required this.present,
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

Map<String, Object?> _json(String raw) =>
    (jsonDecode(raw) as Map).cast<String, Object?>();
String _today() => DateTime.now().toIso8601String().substring(0, 10);
String _copyRows(List<(String, String)> rows) =>
    rows.map((r) => '${r.$1}: ${r.$2}').join('\n');
RowsOutput _rows(List<(String, String)> rows, {int lead = 0}) =>
    RowsOutput(rows, _copyRows(rows), lead: lead);

const _amount = FieldSpec('amount', 'Amount', 'Số tiền', FieldType.decimal);
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
  ToolSpec(
    'percent',
    Icons.percent,
    Category.numbers,
    'A percentage of an amount, and the amount after that discount.',
    'Phần trăm của một số và số còn lại sau khi giảm.',
    fields: const [
      _amount,
      FieldSpec(
        'percent',
        'Percent',
        'Phần trăm',
        FieldType.decimal,
        hint: '%',
      ),
    ],
    encode: (v) => ('${v['amount']},${v['percent']}', ''),
    present: (c, raw, v) {
      final j = _json(raw), p = v['percent'];
      return _rows([
        (tr(c, '$p% of amount', '$p% của số tiền'), '${j['percent']}'),
        (tr(c, 'After $p% off', 'Sau khi giảm $p%'), '${j['afterDiscount']}'),
      ]);
    },
  ),
  ToolSpec(
    'ratio',
    Icons.aspect_ratio,
    Category.numbers,
    'Keep a ratio a : b when a changes.',
    'Giữ tỷ lệ a : b khi a thay đổi.',
    fields: const [
      FieldSpec('a', 'a', 'a', FieldType.decimal, initial: '16'),
      FieldSpec('b', 'b', 'b', FieldType.decimal, initial: '9'),
      FieldSpec('next', 'New a', 'a mới', FieldType.decimal),
    ],
    encode: (v) => ('${v['a']},${v['b']},${v['next']}', ''),
    present: (c, raw, v) => ValueOutput(
      raw,
      caption: tr(
        c,
        'New b for ${v['a']} : ${v['b']}',
        'b mới cho ${v['a']} : ${v['b']}',
      ),
    ),
  ),
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
  ToolSpec(
    'tax',
    Icons.receipt_long_outlined,
    Category.money,
    'Rounded half up to two decimals.',
    'Làm tròn nửa lên, hai chữ số thập phân.',
    fields: [
      _amount,
      const FieldSpec(
        'rate',
        'Tax rate %',
        'Thuế suất %',
        FieldType.decimal,
        initial: '10',
      ),
      FieldSpec(
        'mode',
        'The amount',
        'Số tiền',
        FieldType.choice,
        initial: 'exclusive',
        choices: (_) => const [
          ('exclusive', 'Before tax', 'Chưa thuế'),
          ('inclusive', 'Includes tax', 'Đã gồm thuế'),
        ],
      ),
    ],
    encode: (v) => ('${v['amount']},${v['rate']}', v['mode']!),
    present: (c, raw, v) {
      final j = _json(raw);
      return _rows([
        (tr(c, 'Total', 'Tổng cộng'), '${j['total']}'),
        (tr(c, 'Before tax', 'Chưa thuế'), '${j['base']}'),
        (tr(c, 'Tax', 'Thuế'), '${j['tax']}'),
      ]);
    },
  ),
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
    'manual-exchange',
    Icons.currency_exchange,
    Category.money,
    'Uses the rate you enter. Nothing is looked up online.',
    'Dùng tỷ giá bạn nhập. Không tra cứu trực tuyến.',
    fields: [
      _amount,
      const FieldSpec('rate', 'Rate', 'Tỷ giá', FieldType.decimal),
      FieldSpec(
        'date',
        'Rate date',
        'Ngày tỷ giá',
        FieldType.date,
        initial: _today(),
      ),
    ],
    encode: (v) => ('${v['amount']},${v['rate']},${v['date']}', ''),
    present: (c, raw, v) {
      final j = _json(raw);
      return _rows([
        (tr(c, 'Converted', 'Quy đổi'), '${j['amount']}'),
        (tr(c, 'Rate', 'Tỷ giá'), '${j['rate']}'),
        (tr(c, 'Rate date', 'Ngày tỷ giá'), '${j['rateDate']}'),
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
  _textTool(
    'uppercase',
    Icons.text_increase,
    'EVERY LETTER IN CAPITALS.',
    'VIẾT HOA TẤT CẢ.',
  ),
  _textTool(
    'lowercase',
    Icons.text_decrease,
    'every letter in small letters.',
    'viết thường tất cả.',
  ),
  _textTool(
    'title-case',
    Icons.title,
    'Capitalises The First Letter Of Each Word.',
    'Viết Hoa Chữ Đầu Mỗi Từ.',
  ),
  _textTool(
    'sentence-case',
    Icons.short_text,
    'Capitalises the first letter of each sentence.',
    'Viết hoa chữ đầu mỗi câu.',
  ),
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
  ToolSpec(
    'contrast',
    Icons.contrast,
    Category.color,
    'WCAG contrast. Normal text needs 4.5 : 1.',
    'Độ tương phản WCAG. Chữ thường cần 4.5 : 1.',
    fields: const [
      FieldSpec(
        'fg',
        'Text colour',
        'Màu chữ',
        FieldType.color,
        initial: '#111111',
      ),
      FieldSpec(
        'bg',
        'Background',
        'Màu nền',
        FieldType.color,
        initial: '#FFFFFF',
      ),
    ],
    encode: (v) => ('${v['fg']},${v['bg']}', ''),
    present: (c, raw, v) {
      final j = _json(raw);
      return _rows([
        (tr(c, 'Contrast', 'Tương phản'), '${j['ratio']} : 1'),
        (
          tr(c, 'Normal text (AA)', 'Chữ thường (AA)'),
          j['normalAA'] == true
              ? tr(c, 'Passes', 'Đạt')
              : tr(c, 'Fails', 'Không đạt'),
        ),
      ]);
    },
  ),
  ToolSpec(
    'colors',
    Icons.palette_outlined,
    Category.color,
    'Converts a HEX colour to RGB and HSL.',
    'Đổi màu HEX sang RGB và HSL.',
    fields: const [
      FieldSpec('hex', 'Colour', 'Màu', FieldType.color, initial: '#1D5FBF'),
    ],
    encode: (v) => (v['hex']!, ''),
    present: (c, raw, v) {
      final j = _json(raw);
      final rgb = (j['rgb'] as Map), hsl = (j['hsl'] as Map);
      return _rows([
        ('HEX', '${j['hex']}'),
        ('RGB', '${rgb['r']}, ${rgb['g']}, ${rgb['b']}'),
        ('HSL', '${hsl['h']}°, ${hsl['s']}%, ${hsl['l']}%'),
      ]);
    },
  ),
];

final Map<String, ToolSpec> specById = {for (final s in specs) s.id: s};
