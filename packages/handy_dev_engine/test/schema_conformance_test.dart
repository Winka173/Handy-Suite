import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';

void main() {
  if (!regexSupported) return;
  final root = Directory('../../test-fixtures/json-schema-draft7');
  final files =
      root
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final excluded = <Map<String, Object?>>[], failed = <Map<String, Object?>>[];
  var passed = 0;
  tearDownAll(() {
    File(
      '../../docs/qa/evidence/schema-conformance-summary.json',
    ).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'source': 'JSON-Schema-Test-Suite draft7',
        'commit': File(
          '${root.path}/UPSTREAM_COMMIT.txt',
        ).readAsStringSync().trim(),
        'passed': passed,
        'failed': failed,
        'excludedByPolicy': excluded,
        'browserRuntimeVerified': false,
      }),
    );
  });
  String? policy(Object? schema) {
    final base = Uri.parse('https://offline.invalid/schema.json');
    final ids = <Uri>{base}, refs = <Uri>[], patterns = <String>[];
    void visit(Object? node, Uri context) {
      if (node is List) {
        for (final value in node) {
          visit(value, context);
        }
        return;
      }
      if (node is! Map) return;
      if (node[r'$id'] is String) {
        context = context.resolve(node[r'$id'] as String);
        ids.add(context);
      }
      if (node[r'$ref'] is String) {
        refs.add(context.resolve(node[r'$ref'] as String));
      }
      if (node['pattern'] is String) patterns.add(node['pattern'] as String);
      if (node['patternProperties'] is Map)
        patterns.addAll((node['patternProperties'] as Map).keys.cast<String>());
      for (final entry in node.entries) {
        if (!{'default', 'examples', 'enum', 'const'}.contains(entry.key))
          visit(entry.value, context);
      }
    }

    visit(schema, base);
    for (final ref in refs) {
      if (!ids.contains(ref) && !ids.contains(ref.removeFragment()))
        return 'External reference retrieval is disabled';
    }
    for (final pattern in patterns) {
      try {
        regexHasMatch('', pattern);
      } on FormatException {
        return 'Pattern is outside the declared RE2 syntax/budget';
      }
    }
    return null;
  }

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    for (final group in jsonDecode(file.readAsStringSync()) as List) {
      final schema = group['schema'], reason = policy(schema);
      for (final example in group['tests'] as List) {
        final title =
            '$name / ${group['description']} / ${example['description']}';
        if (reason != null) excluded.add({'test': title, 'reason': reason});
        test(title, () {
          try {
            final result = validateJsonSchema(
              jsonEncode(example['data']),
              jsonEncode(schema),
            );
            if (result['valid'] == example['valid']) {
              passed++;
            } else {
              failed.add({
                'test': title,
                'expected': example['valid'],
                'actual': result['valid'],
              });
            }
            expect(result['valid'], example['valid']);
          } catch (error) {
            if (!failed.any((f) => f['test'] == title))
              failed.add({'test': title, 'error': error.toString()});
            rethrow;
          }
        }, skip: reason);
      }
    }
  }
}
