import 'dart:convert';
import 'transforms.dart' show assertJsonData, bounded;

String _kind(dynamic v) => v == null
    ? 'null'
    : v is List
    ? 'array'
    : v is Map
    ? 'object'
    : v is String
    ? 'string'
    : v is bool
    ? 'boolean'
    : 'number';
Map<String, dynamic> _infer(List<dynamic> samples, [int depth = 0]) {
  if (depth > 30) throw const FormatException('Inference depth limit');
  if (samples.isEmpty) return {'kind': 'unknown'};
  final buckets = <String, List<dynamic>>{};
  for (final v in samples) {
    buckets.putIfAbsent(_kind(v), () => []).add(v);
  }
  final keys = buckets.keys.toList()..sort();
  final choices = <Map<String, dynamic>>[];
  for (final kind in keys) {
    final group = buckets[kind]!;
    if (kind == 'array') {
      choices.add({
        'kind': kind,
        'items': _infer([for (final v in group) ...v as List], depth + 1),
      });
    } else if (kind == 'object') {
      final observed = <String, List<dynamic>>{};
      for (final v in group.cast<Map>()) {
        for (final e in v.entries) {
          observed.putIfAbsent(e.key as String, () => []).add(e.value);
        }
      }
      final fields = observed.keys.toList()..sort();
      choices.add({
        'kind': kind,
        'fields': [
          for (final k in fields)
            {
              'key': k,
              'optional': observed[k]!.length != group.length,
              'shape': _infer(observed[k]!, depth + 1),
            },
        ],
      });
    } else {
      choices.add({
        'kind': kind,
        if (kind == 'number')
          'integer': group.every((v) => (v as num) == v.truncateToDouble()),
      });
    }
  }
  return choices.length == 1
      ? choices.single
      : {'kind': 'union', 'choices': choices};
}

String _ts(Map<String, dynamic> shape) => switch (shape['kind']) {
  'union' => (shape['choices'] as List).map((s) => _ts(s)).join(' | '),
  'array' => 'Array<${_ts(shape['items'])}>',
  'object' =>
    (shape['fields'] as List).isEmpty
        ? 'Record<string, unknown>'
        : '{ ${(shape['fields'] as List).map((f) => '${jsonEncode(f['key'])}${f['optional'] ? '?' : ''}: ${_ts(f['shape'])};').join(' ')} }',
  _ => shape['kind'] as String,
};
String inferTypeScript(dynamic value, [String name = 'Root']) {
  assertJsonData(value, maxNodes: 20000, maxDepth: 30);
  const reserved =
      'class type interface export import default extends function const let var enum namespace declare new return break continue if else for while switch case throw try catch finally yield await this super delete void typeof instanceof in as any unknown never number string boolean null undefined object symbol bigint true false';
  if (!RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]{0,79}$').hasMatch(name) ||
      reserved.split(' ').contains(name))
    throw const FormatException('Non-reserved TypeScript identifier required');
  return bounded(
    '// Inferred from this sample only. No runtime validation or date/enum semantics.\n// Arrays are homogeneous unions, not tuples; missing sample fields become optional.\nexport type $name = ${_ts(_infer([value]))};\n',
    200000,
  );
}

Map<String, dynamic> _schema(Map<String, dynamic> shape) {
  switch (shape['kind']) {
    case 'unknown':
      return {};
    case 'union':
      return {
        'anyOf': (shape['choices'] as List).map((s) => _schema(s)).toList(),
      };
    case 'array':
      return {'type': 'array', 'items': _schema(shape['items'])};
    case 'object':
      final fields = shape['fields'] as List,
          required = fields
              .where((f) => f['optional'] == false)
              .map((f) => f['key'])
              .toList();
      return {
        'type': 'object',
        'properties': {for (final f in fields) f['key']: _schema(f['shape'])},
        if (required.isNotEmpty) 'required': required,
        'additionalProperties': true,
      };
    default:
      return {
        'type': shape['kind'] == 'number' && shape['integer'] == true
            ? 'integer'
            : shape['kind'],
      };
  }
}

Map<String, dynamic> inferJsonSchema(dynamic value) {
  assertJsonData(value, maxNodes: 20000, maxDepth: 30);
  return {
    r'$schema': 'http://json-schema.org/draft-07/schema#',
    r'$comment':
        'Sample inference only: observed keys may be required; additional keys allowed; arrays are unions, not tuples; no date/enum semantics.',
    ..._schema(_infer([value])),
  };
}
