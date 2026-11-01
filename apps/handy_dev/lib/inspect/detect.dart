import 'dart:convert';
import 'package:handy_dev_engine/handy_dev_engine.dart';

/// What a pasted payload is. Order matters: the first match is shown first.
enum DataKind {
  curl,
  jwt,
  har,
  json,
  jsonl,
  xml,
  env,
  toml,
  yaml,
  csv,
  url,
  base64,
  text,
}

DevTool _tool(String id) => devTools.firstWhere((t) => t.id == id);

bool _runs(String id, String input) {
  try {
    _tool(id).run(input);
    return true;
  } catch (_) {
    return false;
  }
}

dynamic _json(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    return null;
  }
}

/// Every kind the input could be, best first; plain text is always last.
/// Detection only routes: the engine still validates on every run.
List<DataKind> detect(String input) {
  final s = input.trim();
  if (s.isEmpty) return const [];
  if (s.length > 1000000) return const [DataKind.text];
  final kinds = <DataKind>[];
  final lines = s
      .split(RegExp(r'\r?\n'))
      .where((l) => l.trim().isNotEmpty)
      .toList();

  if (RegExp(r'^curl\s', caseSensitive: false).hasMatch(s))
    kinds.add(DataKind.curl);
  if (RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$').hasMatch(s) &&
      _runs('jwt', s)) {
    kinds.add(DataKind.jwt);
  }
  final json = (s.startsWith('{') || s.startsWith('[')) ? _json(s) : null;
  if (json is Map &&
      json['log'] is Map &&
      (json['log'] as Map)['entries'] is List) {
    kinds.add(DataKind.har);
  }
  if (json is Map || json is List) kinds.add(DataKind.json);
  if (json == null &&
      lines.length > 1 &&
      lines.every((l) => _json(l.trim()) is Map)) {
    kinds.add(DataKind.jsonl);
  }
  if (s.startsWith('<') && s.endsWith('>') && _runs('xml-json', s))
    kinds.add(DataKind.xml);
  // .env: every line is an UPPER_CASE key, '=', a value (no spaces), or a
  // comment. Upper case keeps Base64 such as `SGVsbG8=` out.
  final env = RegExp(r'^\s*(#.*|[A-Z_][A-Z0-9_]*=(?!=)\S*)$');
  if (lines.every(env.hasMatch) &&
      lines.any((l) => !l.trim().startsWith('#'))) {
    kinds.add(DataKind.env);
  }
  if (json == null &&
      RegExp(
        r'^\s*(\[[^\]]+\]|[A-Za-z0-9_."-]+\s*=)',
        multiLine: true,
      ).hasMatch(s) &&
      _runs('toml-json', s)) {
    kinds.add(DataKind.toml);
  }
  if (json == null &&
      RegExp(r'^\s*[^\s:#][^:]*:(\s|$)', multiLine: true).hasMatch(s) &&
      _runs('yaml-json', s)) {
    final out = _json(_tool('yaml-json').run(s));
    if (out is Map || out is List) kinds.add(DataKind.yaml);
  }
  if (lines.length > 1 &&
      RegExp('[,;\t|]').hasMatch(lines.first) &&
      _runs('csv-json', s)) {
    final out = _json(_tool('csv-json').run(s));
    if (out is List &&
        out.isNotEmpty &&
        out.first is Map &&
        (out.first as Map).length > 1) {
      kinds.add(DataKind.csv);
    }
  }
  if (RegExp('%[0-9A-Fa-f]{2}').hasMatch(s) && _runs('url-decode', s))
    kinds.add(DataKind.url);
  final compact = s.replaceAll(RegExp(r'\s'), '');
  if (compact.length >= 8 &&
      compact.length % 4 == 0 &&
      RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(compact) &&
      RegExp(r'[0-9+/=]|[a-z][A-Z]').hasMatch(compact) &&
      _runs('base64-decode', s)) {
    kinds.add(DataKind.base64);
  }
  kinds.add(DataKind.text);
  return kinds;
}
