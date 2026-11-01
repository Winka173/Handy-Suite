import 'dart:convert';
import 'transforms.dart' show assertJsonData;

List<dynamic> _pathTokens(String source) {
  if (!source.startsWith(r'$') || source.length > 2000)
    throw const FormatException(r'JSONPath requires $; 2000-character limit');
  var cursor = 1;
  final result = <dynamic>[];
  while (cursor < source.length) {
    if (result.length >= 30)
      throw const FormatException('JSONPath step limit: 30');
    if (source[cursor] == '.') {
      cursor++;
      final match = RegExp(
        r'^[A-Za-z_$][A-Za-z0-9_$]*',
      ).firstMatch(source.substring(cursor));
      if (match == null)
        throw const FormatException(
          'Expected .name; recursion and filters unsupported',
        );
      result.add(('key', match[0]!));
      cursor += match[0]!.length;
    } else if (source[cursor] == '[') {
      cursor++;
      if (cursor >= source.length)
        throw const FormatException('Unclosed JSONPath index');
      if (source[cursor] == '"') {
        final start = cursor++;
        while (cursor < source.length && source[cursor] != '"') {
          if (source[cursor] == r'\') cursor++;
          cursor++;
        }
        if (cursor >= source.length)
          throw const FormatException('Unclosed quoted property');
        final key = jsonDecode(source.substring(start, ++cursor));
        if (cursor >= source.length || source[cursor++] != ']')
          throw const FormatException('Expected ["property"]');
        result.add(('key', key as String));
      } else {
        final end = source.indexOf(']', cursor);
        if (end < 0) throw const FormatException('Unclosed array index');
        final token = source.substring(cursor, end);
        cursor = end + 1;
        if (token == '*') {
          result.add(('wildcard', ''));
        } else if (RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(token) &&
            token.length < 16) {
          result.add(('index', int.parse(token)));
        } else {
          throw const FormatException(
            'Only [index], [*], ["property"] supported',
          );
        }
      }
    } else {
      throw const FormatException('Unsupported JSONPath syntax');
    }
  }
  return result;
}

List<dynamic> selectJsonPath(dynamic value, String expression) {
  assertJsonData(value);
  var matches = [value];
  for (final token in _pathTokens(expression)) {
    final next = <dynamic>[];
    for (final match in matches) {
      if (token.$1 == 'wildcard') {
        if (match is Map) {
          next.addAll(match.values);
        } else if (match is List) {
          next.addAll(match);
        }
      } else if (token.$1 == 'index') {
        if (match is List && token.$2 < match.length) next.add(match[token.$2]);
      } else if (match is Map && match.containsKey(token.$2)) {
        next.add(match[token.$2]);
      } else if (match is List) {
        final index = int.tryParse(token.$2 as String);
        if (index != null &&
            index >= 0 &&
            index < match.length &&
            index.toString() == token.$2)
          next.add(match[index]);
      }
      if (next.length > 10000)
        throw const FormatException('JSONPath match limit: 10000');
    }
    matches = next;
  }
  return matches;
}

List<Map<String, dynamic>> projectFields(dynamic value, dynamic fields) {
  assertJsonData(value);
  if (value is! List || value.any((r) => r is! Map<String, dynamic>))
    throw const FormatException('Projection requires array of objects');
  if (fields is! List ||
      fields.isEmpty ||
      fields.length > 50 ||
      fields.any((k) => k is! String || k.isEmpty || k.length > 200))
    throw const FormatException('Options require 1–50 JSON field names');
  final names = fields.cast<String>().toSet();
  return [
    for (final row in value.cast<Map<String, dynamic>>())
      {
        for (final k in names)
          if (row.containsKey(k)) k: row[k],
      },
  ];
}

String _pointer(String key) => key.replaceAll('~', '~0').replaceAll('/', '~1');
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

class JsonTreeNode {
  final String path, key, kind, preview;
  final String? parent;
  final int depth;
  final dynamic value;
  final List<String> children;
  JsonTreeNode({
    required this.path,
    required this.key,
    required this.kind,
    required this.preview,
    this.parent,
    required this.depth,
    required this.value,
    required List<String> children,
  }) : children = List.unmodifiable(children);
}

class JsonTreeIndex {
  final Map<String, JsonTreeNode> nodes;
  final List<String> order;
  JsonTreeIndex(Map<String, JsonTreeNode> nodes, List<String> order)
    : nodes = Map.unmodifiable(nodes),
      order = List.unmodifiable(order);
}

JsonTreeIndex indexJson(dynamic value) {
  assertJsonData(value, maxNodes: 10000, maxDepth: 30);
  final nodes = <String, JsonTreeNode>{}, order = <String>[];
  void visit(dynamic v, String path, String key, String? parent, int depth) {
    if (path.length > 1024 || key.length > 512)
      throw const FormatException('Viewer path/property limit');
    final entries = v is Map
        ? v.cast<String, dynamic>().entries.toList()
        : v is List
        ? [for (var i = 0; i < v.length; i++) MapEntry('$i', v[i])]
        : <MapEntry<String, dynamic>>[];
    final kind = _kind(v);
    var preview = kind == 'object'
        ? '{${entries.length}}'
        : kind == 'array'
        ? '[${entries.length}]'
        : jsonEncode(v);
    if (preview.length > 160) preview = '${preview.substring(0, 157)}…';
    final children = [for (final e in entries) '$path/${_pointer(e.key)}'];
    nodes[path] = JsonTreeNode(
      path: path,
      key: key,
      kind: kind,
      preview: preview,
      parent: parent,
      depth: depth,
      value: v,
      children: children,
    );
    order.add(path);
    for (var i = 0; i < entries.length; i++) {
      visit(entries[i].value, children[i], entries[i].key, path, depth + 1);
    }
  }

  // Snapshot caller-owned graphs; tree rows cannot be changed by later caller mutations.
  visit(jsonDecode(jsonEncode(value)), '', r'$', null, 0);
  return JsonTreeIndex(nodes, order);
}

List<JsonTreeNode> visibleJsonRows(
  JsonTreeIndex index,
  Set<String> expanded, [
  String query = '',
]) {
  if (query.length > 200) throw const FormatException('Search limit: 200');
  final needle = query.trim().toLowerCase(), visible = <String>{};
  if (needle.isNotEmpty) {
    for (final path in index.order) {
      var node = index.nodes[path]!;
      final primitive = ['object', 'array'].contains(node.kind)
          ? ''
          : jsonEncode(node.value);
      if (!node.key.toLowerCase().contains(needle) &&
          !path.toLowerCase().contains(needle) &&
          !primitive.toLowerCase().contains(needle))
        continue;
      visible.add(path);
      while (node.parent != null) {
        node = index.nodes[node.parent]!;
        visible.add(node.path);
      }
    }
    return index.order
        .where(visible.contains)
        .map((p) => index.nodes[p]!)
        .toList();
  }
  void visit(String path) {
    final node = index.nodes[path]!;
    visible.add(path);
    if (expanded.contains(path)) {
      for (final c in node.children) {
        visit(c);
      }
    }
  }

  visit('');
  return index.order
      .where(visible.contains)
      .map((p) => index.nodes[p]!)
      .toList();
}

class FlatJsonTable {
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  FlatJsonTable(List<String> columns, List<Map<String, dynamic>> rows)
    : columns = List.unmodifiable(columns),
      rows = List.unmodifiable(
        rows.map((r) => Map<String, dynamic>.unmodifiable(r)),
      );
}

FlatJsonTable flatJsonTable(dynamic value) {
  assertJsonData(value);
  if (value is! List ||
      value.length > 10000 ||
      value.any((v) => v is! Map<String, dynamic>))
    throw const FormatException('Table requires up to 10000 flat object rows');
  final columns = <String>{};
  for (final row in value.cast<Map<String, dynamic>>()) {
    if (row.values.any((v) => v is List || v is Map))
      throw const FormatException('Nested table values unsupported');
    columns.addAll(row.keys);
    if (columns.length > 20)
      throw const FormatException('Table column limit: 20');
  }
  return FlatJsonTable(columns.toList(), value.cast<Map<String, dynamic>>());
}

String tableCell(Map<String, dynamic> row, String key) =>
    row.containsKey(key) ? jsonEncode(row[key]) : '[missing]';
List<({int index, Map<String, dynamic> row})> filterTableRows(
  FlatJsonTable table,
  String query,
) {
  if (query.length > 200) throw const FormatException('Search limit: 200');
  final needle = query.trim().toLowerCase();
  return [
    for (var i = 0; i < table.rows.length; i++)
      if (needle.isEmpty ||
          '$i'.contains(needle) ||
          jsonEncode(table.rows[i]).toLowerCase().contains(needle))
        (index: i, row: table.rows[i]),
  ];
}
