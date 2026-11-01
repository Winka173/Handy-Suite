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
  final value = jsonDecode(bounded(input));
  assertJsonData(value);
  return value;
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

String envSample(String input) => bounded(input)
    .split(RegExp(r'\r?\n'))
    .where((s) => RegExp(r'^\s*(export\s+)?[A-Za-z_][\w]*=').hasMatch(s))
    .map(
      (s) =>
          '${s.split('=').first.trim().replaceFirst(RegExp(r'^export\s+'), '')}=',
    )
    .join('\n');
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

dynamic harSummary(String input) {
  final v = parseJson(input);
  if (v is! Map || v['log'] is! Map || v['log']['entries'] is! List)
    throw const FormatException('Missing HAR log.entries');
  return (v['log']['entries'] as List).map((e) {
    if (e is! Map) throw const FormatException('Invalid HAR entry');
    return {
      if (e['request'] is Map && e['request'].containsKey('method'))
        'method': e['request']['method'],
      if (e['response'] is Map && e['response'].containsKey('status'))
        'status': e['response']['status'],
      if (e.containsKey('time')) 'durationMs': e['time'],
    };
  }).toList();
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
    'json-typescript',
    'JSON → TypeScript',
    'JSON → TypeScript',
    'Infer a sample type; missing array fields optional, no runtime validation.',
    (s, o) =>
        inferTypeScript(parseJson(s), o.trim().isEmpty ? 'Root' : o.trim()),
    optionsLabel: 'Type name',
  ),
  DevTool(
    'json-schema-infer',
    'Infer JSON Schema',
    'Suy luận JSON Schema',
    'Draft-07 inference from sample only.',
    (s, o) => pretty(inferJsonSchema(parseJson(s))),
  ),
  DevTool(
    'json-toml',
    'JSON → TOML',
    'JSON → TOML',
    'Reject null/unsafe integers and lossy roundtrip.',
    (s, o) => jsonToToml(parseJson(s)),
  ),
  DevTool(
    'jsonpath',
    'JSONPath subset',
    'JSONPath giới hạn',
    r'Supports $, .name, [index], [*], ["key"]; no scripts or filters.',
    (s, o) => pretty(selectJsonPath(parseJson(s), o.trim())),
    optionsLabel: r'Path, e.g. $.items[*].name',
  ),
  DevTool(
    'json-project',
    'Project JSON fields',
    'Chọn trường JSON',
    'Object array; options are JSON field-name array.',
    (s, o) => pretty(projectFields(parseJson(s), parseJson(o))),
    optionsLabel: 'Field names as JSON array',
  ),
  DevTool(
    'json',
    'JSON format',
    'Định dạng JSON',
    'Strict JSON format.',
    (s, o) => pretty(parseJson(s)),
  ),
  DevTool(
    'json-min',
    'JSON minify',
    'Rút gọn JSON',
    'Validate and minify.',
    (s, o) => jsonEncode(parseJson(s)),
  ),
  DevTool(
    'yaml-json',
    'YAML → JSON',
    'YAML → JSON',
    'Reject duplicate keys, cycles and excessive aliases.',
    (s, o) => pretty(parseYaml(s)),
  ),
  DevTool(
    'json-yaml',
    'JSON → YAML',
    'JSON → YAML',
    'JSON flow syntax is valid YAML 1.2; preserves scalar types.',
    (s, o) => pretty(parseJson(s)),
  ),
  DevTool(
    'toml-json',
    'TOML → JSON',
    'TOML → JSON',
    'Parse TOML; dates emitted as ISO strings.',
    (s, o) => pretty(parseToml(s)),
  ),
  DevTool(
    'xml-json',
    'XML → JSON',
    'XML → JSON',
    'Attributes @_ and #text; mixed-content mapping is partial; DTD disabled.',
    (s, o) => pretty(parseXml(s)),
  ),
  DevTool(
    'json-xml',
    'JSON → XML',
    'JSON → XML',
    'Exactly one root key; attributes @_ and #text.',
    (s, o) => jsonToXml(parseJson(s)),
  ),
  DevTool(
    'csv-json',
    'CSV → JSON',
    'CSV → JSON',
    'Auto delimiter; strict header/field count; strings retained.',
    (s, o) => pretty(parseCsv(s)),
  ),
  DevTool(
    'json-csv',
    'JSON → CSV',
    'JSON → CSV',
    'Flat objects only; spreadsheet formulas escaped (lossy).',
    (s, o) => jsonCsv(s),
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
    'base64-encode',
    'Base64 encode',
    'Mã hóa Base64',
    'UTF-8 text.',
    (s, o) => base64.encode(utf8.encode(s)),
  ),
  DevTool(
    'base64-decode',
    'Base64 decode',
    'Giải mã Base64',
    'Strict UTF-8 and canonical unused bits.',
    (s, o) => decode64(s),
  ),
  DevTool(
    'url-encode',
    'URL encode',
    'Mã hóa URL',
    'Encode a UTF-8 component.',
    (s, o) => Uri.encodeComponent(s),
  ),
  DevTool(
    'url-decode',
    'URL decode',
    'Giải mã URL',
    'Reject invalid UTF-8/percent escapes.',
    (s, o) {
      try {
        return Uri.decodeComponent(s);
      } catch (_) {
        throw const FormatException('Invalid percent-encoded UTF-8');
      }
    },
  ),
  DevTool(
    'sha256',
    'SHA-256',
    'SHA-256',
    'Local UTF-8 hash.',
    (s, o) => crypto.sha256.convert(utf8.encode(s)).toString(),
  ),
  DevTool(
    'sha512',
    'SHA-512',
    'SHA-512',
    'Local UTF-8 hash.',
    (s, o) => crypto.sha512.convert(utf8.encode(s)).toString(),
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
    'env-sample',
    '.env sample',
    '.env mẫu',
    'Export names only; remove all values.',
    (s, o) => envSample(s),
    sensitive: true,
  ),
  DevTool(
    'har',
    'HAR summary',
    'Tóm tắt HAR',
    'Only method, status, duration; omit URLs/headers/bodies.',
    (s, o) => pretty(harSummary(s)),
    sensitive: true,
  ),
  DevTool(
    'redact',
    'Redact JSON secrets',
    'Ẩn bí mật JSON',
    'Mask common credential keys recursively; review before sharing.',
    (s, o) => pretty(redact(parseJson(s))),
    sensitive: true,
  ),
]);
final tools = devTools;
