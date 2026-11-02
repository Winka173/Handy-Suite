import 'dart:convert';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';
import 'detect.dart';

/// A parameter a lens needs before it can run (a path, a pattern, a schema).
class LensOption {
  final String en, vi, hint;
  final bool multiline, optional;

  /// Turns what the person typed into the engine's option string.
  final String Function(String typed) encode;

  /// A secret (an HMAC key): hidden while typed, never kept across lenses.
  final bool secret;
  const LensOption(
    this.en,
    this.vi, {
    this.hint = '',
    this.multiline = false,
    this.optional = false,
    this.encode = _same,
    this.secret = false,
  });
  static String _same(String s) => s;
  String label(BuildContext c) => tr(c, en, vi);
}

/// A small set of settings for a lens, shown as one row of chips.
class LensChoice {
  final String id, en, vi;

  /// (value, English label, Vietnamese label); the first is the default.
  final List<(String, String, String)> values;
  const LensChoice(this.id, this.en, this.vi, this.values);
  String label(BuildContext c) => tr(c, en, vi);
}

/// One way of looking at a payload. Most run an engine tool; `tree` and
/// `curl` are views of their own.
class Lens {
  final String id;
  final String? tool;
  final LensOption? option;
  final List<LensChoice> choices;

  /// Builds the engine's option string from the typed option and the
  /// chosen settings, when the plain [LensOption.encode] is not enough.
  final String Function(String typed, String Function(String) pick)? encode;
  const Lens(
    this.id, {
    this.tool,
    this.option,
    this.choices = const [],
    this.encode,
  });
  DevTool? get engine =>
      tool == null ? null : devTools.firstWhere((t) => t.id == tool);
  bool get sensitive => engine?.sensitive ?? false;

  /// The chosen value of setting [id], or its default.
  String pick(Map<String, String> picks, String id) =>
      picks[id] ?? choices.firstWhere((c) => c.id == id).values.first.$1;
  String title(BuildContext c) => switch (id) {
    'tree' => tr(c, 'Tree', 'Dạng cây'),
    'curl' => tr(c, 'Request', 'Request'),
    _ => tr(c, engine!.titleEn, engine!.titleVi),
  };
}

Lens _t(String id, [LensOption? o]) => Lens(id, tool: id, option: o);

const _zone = LensChoice('zone', 'Time zone', 'Múi giờ', [
  ('local', 'Device', 'Giờ máy'),
  ('utc', 'UTC', 'UTC'),
]);
const _otherZone = LensOption(
  'Other offset',
  'Độ lệch khác',
  hint: '+07:00',
  optional: true,
);

String _hmacOptions(String key, String Function(String) pick) => jsonEncode({
  'key': key,
  'hash': pick('hash'),
  'output': pick('output'),
  'keyFormat': pick('keyFormat'),
});

final timestampLens = Lens(
  'timestamp',
  tool: 'timestamp',
  option: _otherZone,
  choices: const [_zone],
);
final cronLens = Lens(
  'cron',
  tool: 'cron',
  option: _otherZone,
  choices: const [
    _zone,
    LensChoice('count', 'Next runs', 'Lần chạy tới', [
      ('5', '5', '5'),
      ('10', '10', '10'),
      ('20', '20', '20'),
    ]),
  ],
);
const baseLens = Lens(
  'base-convert',
  tool: 'base-convert',
  option: LensOption(
    'Also in base',
    'Thêm hệ cơ số',
    hint: '36',
    optional: true,
  ),
  choices: [
    LensChoice('bits', 'Bits', 'Số bit', [
      ('', 'None', 'Không'),
      ('8', '8', '8'),
      ('16', '16', '16'),
      ('32', '32', '32'),
      ('64', '64', '64'),
    ]),
  ],
);
const idsLens = Lens('uuid', tool: 'uuid');
const urlLens = Lens('url-parse', tool: 'url-parse');
const textDiffLens = Lens(
  'text-diff',
  tool: 'text-diff',
  option: LensOption('Compare with', 'So với', multiline: true),
);
const hmacLens = Lens(
  'hmac',
  tool: 'hmac',
  option: LensOption('Key', 'Khóa', secret: true),
  encode: _hmacOptions,
  choices: [
    LensChoice('hash', 'Hash', 'Hàm băm', [
      ('sha256', 'SHA-256', 'SHA-256'),
      ('sha512', 'SHA-512', 'SHA-512'),
    ]),
    LensChoice('output', 'Output', 'Kết quả', [
      ('hex', 'Hex', 'Hex'),
      ('base64', 'Base64', 'Base64'),
    ]),
    LensChoice('keyFormat', 'Key is', 'Khóa là', [
      ('text', 'Text', 'Văn bản'),
      ('hex', 'Hex', 'Hex'),
      ('base64', 'Base64', 'Base64'),
    ]),
  ],
);

String _fields(String typed) => typedFieldsJson(typed);

/// `id, name` or `["id","name"]` → the engine's JSON array of field names.
String typedFieldsJson(String typed) {
  final t = typed.trim();
  if (t.startsWith('[')) return t;
  final names = t.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
  return '[${names.map((n) => '"${n.replaceAll('"', r'\"')}"').join(',')}]';
}

final _json = [
  const Lens('tree'),
  _t('json'),
  _t('json-min'),
  _t(
    'jsonpath',
    const LensOption('Path', 'Đường dẫn', hint: r'$.items[*].name'),
  ),
  _t(
    'json-project',
    const LensOption('Fields', 'Các trường', hint: 'id, name', encode: _fields),
  ),
  _t(
    'json-diff',
    const LensOption(
      'Compare with',
      'So với JSON',
      multiline: true,
      hint: '{ … }',
    ),
  ),
  _t(
    'schema',
    const LensOption(
      'JSON Schema',
      'JSON Schema',
      multiline: true,
      hint: '{"type": "object"}',
    ),
  ),
  _t('json-yaml'),
  _t('json-toml'),
  _t('json-xml'),
  _t('json-csv'),
  _t(
    'json-typescript',
    const LensOption('Type name', 'Tên kiểu', hint: 'Root', optional: true),
  ),
  _t('json-schema-infer'),
  _t('redact'),
];

final _text = [
  _t('regex', const LensOption('Pattern', 'Biểu thức', hint: r'\d+')),
  _t('base64-encode'),
  _t('url-encode'),
  _t('sha256'),
  _t('sha512'),
  hmacLens,
];

/// Kinds whose text has versions worth comparing line by line.
const _documents = {
  DataKind.text,
  DataKind.json,
  DataKind.har,
  DataKind.jsonl,
  DataKind.xml,
  DataKind.yaml,
  DataKind.toml,
  DataKind.csv,
  DataKind.env,
};

/// Lenses for a kind, the default first; text lenses close every list.
List<Lens> lensesFor(DataKind kind) => [
  ...switch (kind) {
    DataKind.json => _json,
    DataKind.har => [_t('har'), ..._json],
    DataKind.jsonl => [_t('jsonl')],
    DataKind.xml => [_t('xml-json')],
    DataKind.yaml => [_t('yaml-json')],
    DataKind.toml => [_t('toml-json')],
    DataKind.csv => [_t('csv-json')],
    DataKind.jwt => [_t('jwt')],
    DataKind.env => [_t('env-sample')],
    DataKind.url => [_t('url-decode')],
    DataKind.link => [urlLens],
    DataKind.timestamp => [timestampLens],
    DataKind.number => [baseLens],
    DataKind.ids => [idsLens],
    DataKind.cron => [cronLens],
    DataKind.base64 => [_t('base64-decode')],
    DataKind.curl => [const Lens('curl')],
    DataKind.text => <Lens>[],
  },
  if (_documents.contains(kind)) textDiffLens,
  if (kind != DataKind.curl) ..._text,
];

String kindLabel(BuildContext c, DataKind k) => switch (k) {
  DataKind.curl => tr(c, 'cURL command', 'Lệnh cURL'),
  DataKind.jwt => 'JWT',
  DataKind.har => 'HAR',
  DataKind.json => 'JSON',
  DataKind.jsonl => 'JSON Lines',
  DataKind.xml => 'XML',
  DataKind.env => '.env',
  DataKind.toml => 'TOML',
  DataKind.yaml => 'YAML',
  DataKind.csv => 'CSV',
  DataKind.url => tr(c, 'URL-encoded', 'URL mã hóa'),
  DataKind.link => 'URL',
  DataKind.timestamp => tr(c, 'Timestamp', 'Mốc thời gian'),
  DataKind.number => tr(c, 'Integer', 'Số nguyên'),
  DataKind.ids => 'UUID / ULID',
  DataKind.cron => 'Cron',
  DataKind.base64 => 'Base64',
  DataKind.text => tr(c, 'Text', 'Văn bản'),
};

/// Steps that may be chained and saved as a workflow: never a sensitive one.
const chainable = {
  'base64-encode',
  'base64-decode',
  'url-encode',
  'url-decode',
  'sha256',
  'sha512',
};

/// Rows the lens chips are grouped into, so a long list scans by purpose.
enum LensGroup { view, convert, encode }

LensGroup lensGroup(Lens l) =>
    const {
      'json-yaml',
      'json-toml',
      'json-xml',
      'json-csv',
      'json-typescript',
      'json-schema-infer',
      'base-convert',
    }.contains(l.id)
    ? LensGroup.convert
    : const {
        'regex',
        'base64-encode',
        'url-encode',
        'sha256',
        'sha512',
        'hmac',
      }.contains(l.id)
    ? LensGroup.encode
    : LensGroup.view;

String lensGroupLabel(BuildContext c, LensGroup g) => switch (g) {
  LensGroup.view => tr(c, 'View', 'Xem'),
  LensGroup.convert => tr(c, 'Convert to', 'Đổi sang'),
  LensGroup.encode => tr(c, 'Encode & find', 'Mã hóa & tìm'),
};
