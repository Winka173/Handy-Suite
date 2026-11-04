import 'dart:collection';
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:toml/toml.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';
import 'inference.dart';
import 'viewer.dart';
import 'regex.dart';
import 'schema.dart';
import 'time.dart';
import 'ids.dart';
import 'text_diff.dart';
import 'cron.dart';
import 'bases.dart';
import 'url_parts.dart';
import 'hmac.dart';
import 'colors.dart';
export 'inference.dart';

String bounded(String text, [int maxBytes = 1000000]) {
  if (text.length > maxBytes || utf8.encode(text).length > maxBytes)
    throw FormatException('Input limit: $maxBytes UTF-8 bytes');
  return text;
}

void assertJsonData(dynamic value, {int maxNodes = 100000, int maxDepth = 40}) {
  var count = 0;
  final ancestors = HashSet<Object>.identity();
  void visit(dynamic v, int depth) {
    if (++count > maxNodes || depth > maxDepth)
      throw const FormatException('Structured data node/depth limit exceeded');
    if (v == null || v is String || v is bool) return;
    if (v is num) {
      if (!v.isFinite)
        throw const FormatException('Finite JSON numbers required');
      return;
    }
    if (v is! List && v is! Map)
      throw const FormatException('JSON values required');
    if (!ancestors.add(v as Object))
      throw const FormatException('Cyclic data cannot be JSON');
    if (v is Map) {
      if (v.keys.any((k) => k is! String))
        throw const FormatException('String object keys required');
      for (final child in v.values) {
        visit(child, depth + 1);
      }
    } else {
      for (final child in v as List) {
        visit(child, depth + 1);
      }
    }
    ancestors.remove(v);
  }

  visit(value, 0);
}

dynamic parseJson(String input) {
  final text = bounded(input);
  final dynamic value;
  try {
    value = jsonDecode(text);
  } on FormatException catch (e) {
    throw jsonSyntaxError(text, e);
  }
  assertJsonData(value);
  return value;
}

/// 1-based line and column of [offset] in [text]; a CRLF counts as one
/// line break and the column counts UTF-16 code units, as editors do.
({int line, int column}) textPlace(String text, int offset) {
  final end = offset.clamp(0, text.length);
  var line = 1, start = 0;
  for (var i = 0; i < end; i++) {
    if (text.codeUnitAt(i) == 0x0A) {
      line++;
      start = i + 1;
    }
  }
  return (line: line, column: end - start + 1);
}

/// A JSON syntax error said where it is and what usually causes it there,
/// bilingual (`English / Tiếng Việt`), keeping the offset for the caller to
/// select. Errors without an offset pass through.
FormatException jsonSyntaxError(String text, FormatException e) {
  final at = e.offset;
  if (at == null) return e;
  final offset = at.clamp(0, text.length);
  final (:line, :column) = textPlace(text, offset);
  final here = offset < text.length ? text[offset] : '';
  var before = offset - 1;
  while (before >= 0 && ' \t\r\n'.contains(text[before])) {
    before--;
  }
  final previous = before >= 0 ? text[before] : '';
  final (String en, String vi) hint = switch (here) {
    '' => (
      'the text ends early; a bracket or quote is not closed',
      'văn bản hết sớm; còn ngoặc hoặc dấu nháy chưa đóng',
    ),
    '}' || ']' when previous == ',' => (
      'remove the comma before it',
      'bỏ dấu phẩy thừa ngay trước',
    ),
    "'" => (
      'JSON strings use double quotes "…"',
      'chuỗi JSON dùng nháy kép "…"',
    ),
    '/' || '#' => ('JSON has no comments', 'JSON không có chú thích'),
    _
        when RegExp(r'[A-Za-z_$]').hasMatch(here) &&
            (previous == '{' || previous == ',') =>
      ('keys need double quotes', 'tên khóa cần nháy kép'),
    _
        when previous == '}' ||
            previous == ']' ||
            previous == '"' ||
            RegExp(r'[0-9el]').hasMatch(previous) =>
      ('a comma is missing before this', 'thiếu dấu phẩy trước chỗ này'),
    _ => ('unexpected character', 'ký tự không hợp lệ'),
  };
  final lineText = text
      .substring(offset - column + 1)
      .split('\n')
      .first
      .replaceAll('\r', '');
  final from = (column - 1 - 24).clamp(0, lineText.length);
  final to = (column - 1 + 16).clamp(0, lineText.length);
  final near =
      '${from > 0 ? '…' : ''}${lineText.substring(from, to).trim()}'
      '${to < lineText.length ? '…' : ''}';
  // The message splits its languages at the first " / ".
  final safe = near.replaceAll(' / ', ' / ');
  final quote = near.isEmpty ? '' : ': $safe';
  return FormatException(
    'Line $line, column $column: ${hint.$1}$quote / '
    'Dòng $line, cột $column: ${hint.$2}$quote',
    text,
    offset,
  );
}

String pretty(dynamic value) {
  assertJsonData(value);
  return bounded(const JsonEncoder.withIndent('  ').convert(value), 2000000);
}

dynamic parseYaml(String input) {
  final parsed = loadYaml(bounded(input));
  // Traverse the expanded graph before copying: repeated aliases count repeatedly,
  // recursive aliases and non-string keys are rejected without infinite recursion.
  assertJsonData(parsed);
  dynamic plain(dynamic value) => value is Map
      ? {for (final e in value.entries) e.key: plain(e.value)}
      : value is List
      ? value.map(plain).toList()
      : value;
  return plain(parsed);
}

dynamic parseToml(String input) {
  dynamic normalize(dynamic v) => v is TomlOffsetDateTime
      ? v.toUtcDateTime().toIso8601String()
      : v is TomlLocalDateTime
      ? '${v.date}T${v.time}'
      : v is TomlLocalDate
      ? v.date.toString()
      : v is TomlLocalTime
      ? v.time.toString()
      : v is DateTime
      ? v.toIso8601String()
      : v is Map
      ? {for (final e in v.entries) e.key.toString(): normalize(e.value)}
      : v is List
      ? v.map(normalize).toList()
      : v;
  final result = normalize(TomlDocument.parse(bounded(input)).toMap());
  assertJsonData(result);
  return result;
}

String jsonToToml(dynamic value) {
  assertJsonData(value, maxNodes: 20000, maxDepth: 30);
  if (value is! Map<String, dynamic>)
    throw const FormatException('TOML requires root object');
  void check(dynamic v) {
    if (v == null) throw const FormatException('TOML cannot preserve null');
    if (v is num && v == v.truncateToDouble() && v.abs() > 9007199254740991)
      throw const FormatException(
        'Unsafe integer unsupported for portable TOML',
      );
    if (v is Map) {
      for (final x in v.values) {
        check(x);
      }
    }
    if (v is List) {
      for (final x in v) {
        check(x);
      }
    }
  }

  check(value);
  final result = TomlDocument.fromMap(value).toString();
  if (!jsonEquivalent(value, parseToml(result)))
    throw const FormatException('TOML roundtrip changes JSON; rejected');
  return bounded(result, 2000000);
}

bool jsonEquivalent(dynamic a, dynamic b) {
  if (a is Map && b is Map)
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && jsonEquivalent(a[k], b[k]));
  if (a is List && b is List)
    return a.length == b.length &&
        Iterable<int>.generate(
          a.length,
        ).every((i) => jsonEquivalent(a[i], b[i]));
  return a == b;
}

dynamic parseXml(String input) {
  bounded(input);
  if (RegExp(r'<!\s*(DOCTYPE|ENTITY)', caseSensitive: false).hasMatch(input))
    throw const FormatException('DTD and entities disabled');
  final document = XmlDocument.parse(input);
  dynamic scalar(String s) {
    final trimmed = s.trim();
    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;
    return num.tryParse(trimmed) ?? trimmed;
  }

  var xmlNodes = 0;
  dynamic element(XmlElement node, [int depth = 0]) {
    if (++xmlNodes > 100000 || depth > 40) {
      throw const FormatException('XML node/depth limit exceeded');
    }
    final children = node.childElements.toList(), attrs = node.attributes;
    if (children.isEmpty && attrs.isEmpty) return scalar(node.innerText);
    final result = <String, dynamic>{
      for (final a in attrs) '@_${a.name.qualified}': a.value,
    };
    for (final child in children) {
      final key = child.name.qualified, v = element(child, depth + 1);
      if (result.containsKey(key)) {
        final existing = result[key];
        if (existing is List) {
          existing.add(v);
        } else {
          result[key] = [existing, v];
        }
      } else {
        result[key] = v;
      }
    }
    final text = node.children
        .whereType<XmlText>()
        .map((t) => t.value)
        .join()
        .trim();
    if (text.isNotEmpty) result['#text'] = scalar(text);
    return result;
  }

  final result = {
    document.rootElement.name.qualified: element(document.rootElement),
  };
  assertJsonData(result);
  return result;
}

String jsonToXml(dynamic value) {
  assertJsonData(value);
  if (value is! Map<String, dynamic> || value.length != 1)
    throw const FormatException('Exactly one XML root key required');
  final name = RegExp(r'^[A-Za-z_][A-Za-z0-9_.:-]*$');
  XmlElement build(String key, dynamic v) {
    if (!name.hasMatch(key))
      throw const FormatException('Invalid XML element name');
    final attrs = <XmlAttribute>[], children = <XmlNode>[];
    if (v is Map) {
      for (final entry in v.entries) {
        final k = entry.key as String, x = entry.value;
        if (k.startsWith('@_')) {
          if (!name.hasMatch(k.substring(2)) || x is Map || x is List)
            throw const FormatException('Invalid XML attribute');
          attrs.add(
            XmlAttribute(
              XmlName.qualified(k.substring(2)),
              x?.toString() ?? '',
            ),
          );
        } else if (k == '#text') {
          if (x is Map || x is List)
            throw const FormatException('XML text must be scalar');
          children.add(XmlText(x?.toString() ?? ''));
        } else if (x is List) {
          for (final item in x) {
            children.add(build(k, item));
          }
        } else {
          children.add(build(k, x));
        }
      }
    } else if (v is List) {
      throw const FormatException('Root XML value cannot be array');
    } else {
      children.add(XmlText(v?.toString() ?? ''));
    }
    return XmlElement(XmlName.qualified(key), attrs, children);
  }

  final result = build(
    value.keys.single,
    value.values.single,
  ).toXmlString(pretty: true);
  parseXml(result);
  return bounded(result, 2000000);
}

List<List<String>> _csvRows(String input, String delimiter) {
  final rows = <List<String>>[];
  var row = <String>[], field = StringBuffer(), quoted = false, closed = false;
  void cell() {
    row.add(field.toString());
    field = StringBuffer();
    closed = false;
  }

  void line() {
    cell();
    if (row.any((v) => v.isNotEmpty)) rows.add(row);
    row = [];
    if (rows.length > 100000) throw const FormatException('CSV row limit');
  }

  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      if (field.isNotEmpty || closed)
        throw const FormatException('Invalid CSV quote');
      quoted = true;
    } else if (c == delimiter) {
      cell();
    } else if (c == '\r' || c == '\n') {
      if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      line();
    } else {
      if (closed)
        throw const FormatException('Unexpected text after CSV quote');
      field.write(c);
    }
  }
  if (quoted) throw const FormatException('Unclosed CSV quote');
  if (field.isNotEmpty || row.isNotEmpty || closed) line();
  return rows;
}

List<Map<String, String>> parseCsv(String input) {
  bounded(input);
  if (input.startsWith('\uFEFF')) input = input.substring(1);
  var delimiter = ',', best = -1, inQuotes = false;
  final counts = {',': 0, '\t': 0, ';': 0, '|': 0};
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (c == '"') {
      if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (!inQuotes) {
      if (c == '\r' || c == '\n') break;
      if (counts.containsKey(c)) counts[c] = counts[c]! + 1;
    }
  }
  for (final d in counts.keys) {
    final n = counts[d]!;
    if (n > best) {
      best = n;
      delimiter = d;
    }
  }
  final rows = _csvRows(input, delimiter);
  if (rows.isEmpty) return [];
  final header = rows.removeAt(0);
  if (header.length > 1000 || header.toSet().length != header.length)
    throw const FormatException('CSV duplicate headers or column limit');
  if (rows.length * header.length > 200000)
    throw const FormatException('CSV cell limit: 200000');
  return [
    for (final row in rows)
      if (row.length == header.length)
        {for (var i = 0; i < header.length; i++) header[i]: row[i]}
      else
        throw const FormatException('CSV field count differs from header'),
  ];
}

String jsonCsv(String input) {
  final value = parseJson(input);
  if (value is! List || value.any((r) => r is! Map<String, dynamic>))
    throw const FormatException('Array of flat objects required');
  final columns = <String>{};
  for (final row in value.cast<Map<String, dynamic>>()) {
    columns.addAll(row.keys);
    if (row.values.any((v) => v is Map || v is List))
      throw const FormatException('Nested CSV fields unsupported');
  }
  if (columns.length > 1000 || columns.length * value.length > 200000)
    throw const FormatException('CSV cell/column limit exceeded');
  String cell(dynamic v) {
    var s = v == null ? '' : v.toString();
    if (RegExp(r'^[=+\-@\t\r]').hasMatch(s)) s = "'$s";
    return s.contains(RegExp('[",\r\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final result = [
    columns.map(cell).join(','),
    for (final row in value.cast<Map<String, dynamic>>())
      columns.map((k) => cell(row[k])).join(','),
  ].join('\r\n');
  return bounded(result, 2000000);
}

String decode64(String source) {
  var s = bounded(source).replaceAll('-', '+').replaceAll('_', '/');
  if (!RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(s) ||
      s.length % 4 == 1 ||
      (s.contains('=') && s.length % 4 != 0))
    throw const FormatException('Invalid Base64 padding');
  s = s.replaceAll(RegExp(r'=+$'), '');
  s = s.padRight((s.length + 3) ~/ 4 * 4, '=');
  final bytes = base64.decode(s);
  if (base64.encode(bytes) != s)
    throw const FormatException('Invalid Base64 unused bits');
  return utf8.decode(bytes, allowMalformed: false);
}

Map<String, dynamic> jwt(String input, {DateTime? now}) {
  final p = bounded(input.trim(), 50000).split('.');
  if (p.length != 3) throw const FormatException('Expected three JWT segments');
  final header = parseJson(decode64(p[0])), payload = parseJson(decode64(p[1]));
  if (header is! Map || payload is! Map)
    throw const FormatException('JWT header and payload must be objects');
  final exp = payload['exp'],
      valid = exp is num && exp.isFinite && exp.abs() <= 8640000000000;
  return {
    'signatureVerified': false,
    'warning':
        'Decoded only. Untrusted content; signature verification is not implemented.',
    'header': header,
    'payload': payload,
    'expiration': valid
        ? DateTime.fromMillisecondsSinceEpoch(
            (exp * 1000).toInt(),
            isUtc: true,
          ).toIso8601String()
        : null,
    'expired': valid
        ? exp * 1000 < (now ?? DateTime.now()).millisecondsSinceEpoch
        : null,
    if (payload.containsKey('exp') && !valid)
      'expirationError':
          'exp must be a finite NumericDate within the supported date range',
  };
}

List<Map<String, dynamic>> diff(
  dynamic a,
  dynamic b, [
  String path = '',
  int depth = 0,
]) {
  if (depth == 0) {
    assertJsonData(a);
    assertJsonData(b);
  }
  if (depth > 40) throw const FormatException('Diff depth limit');
  if (jsonEquivalent(a, b)) return [];
  if ((a is Map && b is Map) || (a is List && b is List)) {
    Map<String, dynamic> map(dynamic x) => x is Map
        ? x.cast<String, dynamic>()
        : {for (var i = 0; i < (x as List).length; i++) '$i': x[i]};
    final left = map(a), right = map(b), out = <Map<String, dynamic>>[];
    for (final k in {...left.keys, ...right.keys}) {
      final p = '$path/${k.replaceAll('~', '~0').replaceAll('/', '~1')}';
      if (!left.containsKey(k)) {
        out.add({'path': p, 'kind': 'add', 'after': right[k]});
      } else if (!right.containsKey(k)) {
        out.add({'path': p, 'kind': 'remove', 'before': left[k]});
      } else {
        out.addAll(diff(left[k], right[k], p, depth + 1));
      }
    }
    return out;
  }
  return [
    {'path': path, 'kind': 'change', 'before': a, 'after': b},
  ];
}

dynamic redact(dynamic value, [int depth = 0]) {
  if (depth == 0) assertJsonData(value);
  if (depth > 20) return '[depth limit]';
  if (value is List) return value.map((v) => redact(v, depth + 1)).toList();
  if (value is Map)
    return {
      for (final e in value.entries)
        e.key:
            RegExp(
              r'authorization|cookie|password|secret|token|api[-_]?key',
              caseSensitive: false,
            ).hasMatch(e.key as String)
            ? '[REDACTED]'
            : redact(e.value, depth + 1),
    };
  return value;
}

/// Formats [convertData] reads and writes; one side is always JSON.
const convertFormats = ['json', 'yaml', 'toml', 'xml', 'csv'];

/// `from to` (e.g. `json yaml`) → the converted text. JSON is the hub: a
/// conversion between two other formats is refused rather than chained,
/// because each step is lossy in its own way.
String convertData(String input, String options) {
  final parts = options.trim().toLowerCase().split(RegExp(r'[\s,>→-]+'))
    ..removeWhere((p) => p.isEmpty);
  if (parts.length != 2 ||
      parts.any((p) => !convertFormats.contains(p)) ||
      parts[0] == parts[1]) {
    throw const FormatException(
      'Options: from and to, one of json yaml toml xml csv',
    );
  }
  final (from, to) = (parts[0], parts[1]);
  if (from != 'json' && to != 'json') {
    throw const FormatException(
      'One side must be JSON / Một phía phải là JSON',
    );
  }
  return switch (from) {
    'yaml' => pretty(parseYaml(input)),
    'toml' => pretty(parseToml(input)),
    'xml' => pretty(parseXml(input)),
    'csv' => pretty(parseCsv(input)),
    _ => switch (to) {
      // JSON flow syntax is valid YAML 1.2 and keeps every scalar type.
      'yaml' => pretty(parseJson(input)),
      'toml' => jsonToToml(parseJson(input)),
      'xml' => jsonToXml(parseJson(input)),
      _ => jsonCsv(input),
    },
  };
}

class DevTool {
  final String id, titleEn, titleVi, description, inputLabel, optionsLabel;
  final bool sensitive;
  final String Function(String, String) _run;
  const DevTool(
    this.id,
    this.titleEn,
    this.titleVi,
    this.description,
    this._run, {
    this.optionsLabel = '',
    this.inputLabel = 'Paste input / Dán dữ liệu',
    this.sensitive = false,
  });
  String run(String input, [String options = '']) =>
      bounded(_run(bounded(input), bounded(options)), 2000000);
}

final List<DevTool> devTools = List.unmodifiable([
  if (regexSupported)
    DevTool(
      'schema',
      'JSON Schema validate',
      'Kiểm tra JSON Schema',
      'Local draft-07 validation with RE2 patterns. 20 KB schema; external references and format assertions disabled; bounded evaluation.',
      (s, o) => pretty(validateJsonSchema(s, o)),
      optionsLabel: 'JSON Schema',
    ),
  if (regexSupported)
    DevTool(
      'regex',
      'Regex RE2',
      'Biểu thức RE2',
      'Local RE2; no lookaround/backreferences. 100 KB input / 1000-byte pattern / 1000 matches; bounded capture output.',
      (s, o) => pretty(regex(s, o)),
      optionsLabel: 'Pattern / Biểu thức',
    ),
  DevTool(
    'json-infer',
    'Infer a type',
    'Suy ra kiểu',
    'From a sample: a TypeScript type (options: its name, default Root; missing array fields optional) or a draft-07 JSON Schema (options: schema). No runtime validation.',
    (s, o) => o.trim() == 'schema'
        ? pretty(inferJsonSchema(parseJson(s)))
        : inferTypeScript(parseJson(s), o.trim().isEmpty ? 'Root' : o.trim()),
    optionsLabel: 'Type name, or schema',
  ),
  DevTool(
    'json-filter',
    'Filter JSON',
    'Lọc JSON',
    r'A path ($, .name, [index], [*], ["key"]; no scripts or filters) or field names to keep from an object array (id, name or ["id","name"]).',
    (s, o) {
      final q = o.trim();
      if (q.isEmpty || q.startsWith(r'$')) {
        return pretty(selectJsonPath(parseJson(s), q.isEmpty ? r'$' : q));
      }
      final names = q.startsWith('[')
          ? parseJson(q)
          : [
              for (final n in q.split(','))
                if (n.trim().isNotEmpty) n.trim(),
            ];
      return pretty(projectFields(parseJson(s), names));
    },
    optionsLabel: r'Path ($.items[*].name) or fields (id, name)',
  ),
  DevTool(
    'json',
    'JSON format',
    'Định dạng JSON',
    'Strict JSON: pretty (default) or minified. Options: pretty | min.',
    (s, o) =>
        o.trim() == 'min' ? jsonEncode(parseJson(s)) : pretty(parseJson(s)),
    optionsLabel: 'pretty | min',
  ),
  DevTool(
    'convert',
    'Convert data',
    'Chuyển đổi dữ liệu',
    'Between JSON, YAML, TOML, XML and CSV; one side is JSON. Options: from and to, e.g. "json yaml". YAML rejects duplicate keys and alias bombs; TOML rejects null and unsafe integers; XML maps attributes to @_ and text to #text (DTD off); CSV is flat with formulas escaped.',
    (s, o) => convertData(s, o),
    optionsLabel: 'From and to, e.g. json yaml',
  ),
  DevTool(
    'jsonl',
    'JSONL → JSON',
    'JSONL → JSON',
    'Parse nonempty lines as JSON.',
    (s, o) {
      final rows = <dynamic>[];
      var i = 0;
      for (final line in s.split(RegExp(r'\r?\n'))) {
        i++;
        if (line.trim().isEmpty) continue;
        try {
          rows.add(parseJson(line));
        } catch (_) {
          throw FormatException('Invalid JSON on line $i');
        }
      }
      return pretty(rows);
    },
  ),
  DevTool(
    'base64',
    'Base64',
    'Base64',
    'UTF-8 text. Options: encode (default) | decode; decoding is strict UTF-8 with canonical unused bits.',
    (s, o) =>
        o.trim() == 'decode' ? decode64(s) : base64.encode(utf8.encode(s)),
    optionsLabel: 'encode | decode',
  ),
  DevTool(
    'url',
    'URL encode',
    'Mã hóa URL',
    'A UTF-8 component. Options: encode (default) | decode; invalid percent escapes are rejected.',
    (s, o) {
      if (o.trim() != 'decode') return Uri.encodeComponent(s);
      try {
        return Uri.decodeComponent(s);
      } catch (_) {
        throw const FormatException('Invalid percent-encoded UTF-8');
      }
    },
    optionsLabel: 'encode | decode',
  ),
  DevTool(
    'hash',
    'Hash',
    'Băm',
    'Local UTF-8 hash. Options: sha256 (default) | sha512.',
    (s, o) => (o.trim() == 'sha512' ? crypto.sha512 : crypto.sha256)
        .convert(utf8.encode(s))
        .toString(),
    optionsLabel: 'sha256 | sha512',
  ),
  DevTool(
    'jwt',
    'JWT decode',
    'Giải mã JWT',
    'Decode only; signature NEVER verified; no saved drafts.',
    (s, o) => pretty(jwt(s)),
    sensitive: true,
  ),
  DevTool(
    'json-diff',
    'JSON structural diff',
    'So sánh JSON',
    'Before JSON; options after JSON. JSON Pointer paths.',
    (s, o) => pretty(diff(parseJson(s), parseJson(o))),
    optionsLabel: 'After JSON',
  ),
  DevTool(
    'redact',
    'Redact JSON secrets',
    'Ẩn bí mật JSON',
    'Mask common credential keys recursively; review before sharing.',
    (s, o) => pretty(redact(parseJson(s))),
    sensitive: true,
  ),
  DevTool(
    'timestamp',
    'Unix timestamp',
    'Mốc thời gian Unix',
    'Unix s/ms/µs/ns (unit by size) or ISO-8601 to UTC, a zone and relative time. Zones: UTC, device local or a fixed offset; no IANA names.',
    (s, o) {
      final opt = timestampOptions(o);
      return pretty(readTimestamp(s, zone: opt.zone, unit: opt.unit).toJson());
    },
    optionsLabel: 'Zone and unit, e.g. +07:00 ms',
  ),
  DevTool(
    'uuid',
    'UUID / ULID',
    'UUID / ULID',
    'Inspect pasted IDs (version, variant, v1/v6/v7 and ULID time), or with empty input make 1–1000 v4, v7 or ULID from a secure random source.',
    (s, o) {
      if (s.trim().isNotEmpty) {
        final r = inspectIds(s);
        if (r.length == 1 && r.single['valid'] != true) {
          throw FormatException(r.single['error'] as String);
        }
        return pretty(r.length == 1 ? r.single : r);
      }
      final parts = o.trim().split(RegExp(r'\s+'));
      final count = parts.length > 1 ? int.tryParse(parts[1]) : 1;
      if (count == null) throw const FormatException('Count must be a number');
      return generateIds(idKind(parts.first), count).join('\n');
    },
    optionsLabel: 'Make: v4 | v7 | ulid, and a count',
  ),
  DevTool(
    'text-diff',
    'Text diff',
    'So sánh văn bản',
    'Line diff (Myers), unified output. Before text; options after text. $maxDiffLines lines per side, $maxDiffChanges changed lines.',
    (s, o) => diffText(s, o).unified(),
    optionsLabel: 'After text',
  ),
  DevTool(
    'cron',
    'Cron explain',
    'Giải thích cron',
    '5 fields, or 6 with seconds; ranges, steps, lists, names, @daily-style macros. Explained in EN/VI with the next 1–100 runs in UTC, local or a fixed offset.',
    (s, o) {
      final opt = cronOptions(o);
      return pretty(cronReport(parseCron(s), opt.zone, opt.count));
    },
    optionsLabel: 'Zone and count, e.g. +07:00 10',
  ),
  DevTool(
    'base-convert',
    'Number bases',
    'Đổi hệ cơ số',
    'BigInt between bases 2/8/10/16 and any 2–36; two’s complement at a bit width. Up to $maxBaseDigits digits.',
    (s, o) {
      final opt = baseOptions(o);
      return pretty(convertBase(s, base: opt.base, bits: opt.bits).toJson());
    },
    optionsLabel: 'base=36 bits=32',
  ),
  DevTool(
    'url-parse',
    'URL parts',
    'Tách URL',
    'Scheme, user, host, port, path, decoded query table and fragment; rebuilt after editing. Password hidden; nothing fetched.',
    (s, o) {
      final p = parseUrl(s);
      final json = p.toJson();
      if (o.trim().isNotEmpty) {
        final pairs = parseJson(o);
        if (pairs is! List ||
            pairs.any(
              (x) => x is! List || x.length != 2 || x.any((y) => y is! String),
            )) {
          throw const FormatException('Query must be [["name","value"], …]');
        }
        json['url'] = p.rebuild([
          for (final x in pairs) (x[0] as String, x[1] as String),
        ]);
      }
      return pretty(json);
    },
    optionsLabel: 'Query as [["name","value"]] (optional)',
  ),
  DevTool(
    'hmac',
    'HMAC',
    'HMAC',
    'HMAC-SHA256/SHA512 of UTF-8 text, hex or Base64. The key is session-only: never saved in drafts, chains or exports.',
    (s, o) => hmacTool(s, o),
    optionsLabel: 'JSON: key, hash, keyFormat, output',
    sensitive: true,
  ),
  DevTool(
    'colors',
    'HEX / RGB / HSL',
    'HEX / RGB / HSL',
    'A #RRGGBB colour as RGB and HSL (degrees and percentages).',
    (s, o) => pretty(colors(s.trim())),
  ),
  DevTool(
    'contrast',
    'Colour contrast',
    'Độ tương phản màu',
    'WCAG 2 ratio of a text colour on a background: AA needs 4.5 for normal text, 3 for large; AAA needs 7. Input: text colour; options: background (or both in the input, "#111111 on #FFFFFF").',
    (s, o) {
      final hexes = RegExp(
        r'#[0-9a-fA-F]{6}\b',
      ).allMatches('$s ${o.trim()}').map((m) => m[0]!).toList();
      if (hexes.length != 2) {
        throw const FormatException(
          'Two colours: text and background, #RRGGBB',
        );
      }
      return pretty(contrastReport(hexes[0], hexes[1]));
    },
    optionsLabel: 'Background #RRGGBB',
  ),
]);
final tools = devTools;

/// Tools merged on 2026-11-03, each with the tool and options it became;
/// `{}` in the options stands for the options the old tool was given.
/// Saved chains keep these ids as steps; favorites and drafts move over.
const devToolAliases = <String, (String, String)>{
  'jsonpath': ('json-filter', '{}'),
  'json-project': ('json-filter', '{}'),
  'json-typescript': ('json-infer', '{}'),
  'json-schema-infer': ('json-infer', 'schema'),
  'json-min': ('json', 'min'),
  'json-yaml': ('convert', 'json yaml'),
  'json-toml': ('convert', 'json toml'),
  'json-xml': ('convert', 'json xml'),
  'json-csv': ('convert', 'json csv'),
  'yaml-json': ('convert', 'yaml json'),
  'toml-json': ('convert', 'toml json'),
  'xml-json': ('convert', 'xml json'),
  'csv-json': ('convert', 'csv json'),
  'base64-encode': ('base64', 'encode'),
  'base64-decode': ('base64', 'decode'),
  'url-encode': ('url', 'encode'),
  'url-decode': ('url', 'decode'),
  'sha256': ('hash', 'sha256'),
  'sha512': ('hash', 'sha512'),
};

/// Tools removed on 2026-11-03; their saved favorites and drafts are dropped.
const devRemovedTools = {'har', 'env-sample'};

/// Runs a tool by id, or a merged tool's old id with the options it implies.
String runDevTool(String id, String input, [String options = '']) {
  final alias = devToolAliases[id];
  final toolId = alias?.$1 ?? id;
  final tool = devTools.firstWhere(
    (t) => t.id == toolId,
    orElse: () => throw FormatException('Unknown tool: $id'),
  );
  return tool.run(input, alias?.$2.replaceAll('{}', options) ?? options);
}
