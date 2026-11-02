import 'dart:convert';
import 'package:handy_dev_engine/handy_dev_engine.dart';

/// What a pasted payload is. Order matters: the first match is shown first.
enum DataKind {
  curl,
  jwt,
  json,
  jsonl,
  xml,
  toml,
  yaml,
  csv,
  link,
  timestamp,
  number,
  ids,
  cron,
  color,
  url,
  base64,
  text,
}

/// Old one-way ids (`yaml-json`) still name the merged tools' directions.
String _run(String id, String input) => runDevTool(id, input);

bool _runs(String id, String input) {
  try {
    _run(id, input);
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
  if (json is Map || json is List) kinds.add(DataKind.json);
  if (json == null &&
      lines.length > 1 &&
      lines.every((l) => _json(l.trim()) is Map)) {
    kinds.add(DataKind.jsonl);
  }
  if (s.startsWith('<') && s.endsWith('>') && _runs('xml-json', s))
    kinds.add(DataKind.xml);
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
    final out = _json(_run('yaml-json', s));
    if (out is Map || out is List) kinds.add(DataKind.yaml);
  }
  if (lines.length > 1 &&
      RegExp('[,;\t|]').hasMatch(lines.first) &&
      _runs('csv-json', s)) {
    final out = _json(_run('csv-json', s));
    if (out is List &&
        out.isNotEmpty &&
        out.first is Map &&
        (out.first as Map).length > 1) {
      kinds.add(DataKind.csv);
    }
  }
  final oneLine = lines.length == 1;
  if (oneLine &&
      RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://\S+$').hasMatch(s) &&
      _runs('url-parse', s)) {
    kinds.add(DataKind.link);
  }
  if (oneLine &&
      (RegExp(r'^-?\d{9,19}(\.\d{1,9})?$').hasMatch(s) ||
          RegExp(r'^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}.*)?$').hasMatch(s)) &&
      _runs('timestamp', s)) {
    kinds.add(DataKind.timestamp);
  }
  if (oneLine &&
      s.length <= maxBaseDigits &&
      RegExp(
        r'^[+-]?(0[xX][0-9a-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+|\d[\d_]*)$',
      ).hasMatch(s)) {
    kinds.add(DataKind.number);
  }
  if (lines.length <= maxIds && lines.every(looksLikeId)) {
    kinds.add(DataKind.ids);
  }
  if (oneLine &&
      (s.startsWith('@') ||
          RegExp(r'^[\w*?,/-]+(\s+[\w*?,/-]+){4,5}$').hasMatch(s))) {
    try {
      parseCron(s);
      kinds.add(DataKind.cron);
    } on FormatException catch (_) {}
  }
  // A colour, or a text colour on a background ("#111111 on #FFFFFF").
  if (oneLine &&
      RegExp(
        r'^#[0-9a-fA-F]{6}(\s*(on|trên|/|,)?\s*#[0-9a-fA-F]{6})?$',
      ).hasMatch(s)) {
    kinds.add(DataKind.color);
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
