import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';
import 'detect.dart';

/// A parameter a lens needs before it can run (a path, a pattern, a schema).
class LensOption {
  final String en, vi, hint;
  final bool multiline, optional;

  /// Turns what the person typed into the engine's option string.
  final String Function(String typed) encode;
  const LensOption(
    this.en,
    this.vi, {
    this.hint = '',
    this.multiline = false,
    this.optional = false,
    this.encode = _same,
  });
  static String _same(String s) => s;
  String label(BuildContext c) => tr(c, en, vi);
}

/// One way of looking at a payload. Most run an engine tool; `tree` and
/// `curl` are views of their own.
class Lens {
  final String id;
  final String? tool;
  final LensOption? option;
  const Lens(this.id, {this.tool, this.option});
  DevTool? get engine =>
      tool == null ? null : devTools.firstWhere((t) => t.id == tool);
  bool get sensitive => engine?.sensitive ?? false;
  String title(BuildContext c) => switch (id) {
    'tree' => tr(c, 'Tree', 'Dạng cây'),
    'curl' => tr(c, 'Request', 'Request'),
    _ => tr(c, engine!.titleEn, engine!.titleVi),
  };
}

Lens _t(String id, [LensOption? o]) => Lens(id, tool: id, option: o);

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
];

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
    DataKind.base64 => [_t('base64-decode')],
    DataKind.curl => [const Lens('curl')],
    DataKind.text => <Lens>[],
  },
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
    }.contains(l.id)
    ? LensGroup.convert
    : const {
        'regex',
        'base64-encode',
        'url-encode',
        'sha256',
        'sha512',
      }.contains(l.id)
    ? LensGroup.encode
    : LensGroup.view;

String lensGroupLabel(BuildContext c, LensGroup g) => switch (g) {
  LensGroup.view => tr(c, 'View', 'Xem'),
  LensGroup.convert => tr(c, 'Convert to', 'Đổi sang'),
  LensGroup.encode => tr(c, 'Encode & find', 'Mã hóa & tìm'),
};
