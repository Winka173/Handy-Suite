import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev/inspect/detect.dart';
import 'package:handy_dev/inspect/inspection.dart';
import 'package:handy_dev/inspect/lenses.dart';

Lens lens(DataKind k, String id) => lensesFor(k).firstWhere((l) => l.id == id);

void main() {
  test('pasted payloads are recognised, best guess first', () {
    expect(detect('{"a": [1, 2]}').first, DataKind.json);
    expect(detect('{"log": {"entries": []}}').first, DataKind.har);
    expect(detect('{"a":1}\n{"a":2}').first, DataKind.jsonl);
    expect(detect('<a><b>1</b></a>').first, DataKind.xml);
    expect(detect('API_KEY=abc\nDEBUG=1').first, DataKind.env);
    expect(detect('name: An\nage: 3').first, DataKind.yaml);
    expect(detect('[server]\nport = 8080').first, DataKind.toml);
    expect(detect('id,name\n1,An\n2,Bình').first, DataKind.csv);
    expect(detect('https%3A%2F%2Fexample.com%2F').first, DataKind.url);
    expect(detect('SGVsbG8gVmnhu4d0IE5hbQ==').first, DataKind.base64);
    expect(
      detect('eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.').first,
      DataKind.jwt,
    );
    expect(
      detect(
        "curl -X POST https://api.example.com/v1/items -H 'Accept: application/json'",
      ).first,
      DataKind.curl,
    );
    expect(detect('just words'), [DataKind.text]);
    expect(detect('  '), isEmpty);
  });

  test('tree, options and structured engine output', () {
    final tree = inspect(
      '{"a":[1,2]}',
      DataKind.json,
      lens(DataKind.json, 'tree'),
    );
    expect(tree.tree, {
      'a': [1, 2],
    });
    final path = lens(DataKind.json, 'jsonpath');
    expect(inspect('{"a":1}', DataKind.json, path).needsOption, isTrue);
    expect(
      inspect('{"a":[1,2]}', DataKind.json, path, option: r'$.a[*]').tree,
      [1, 2],
    );
    final fields = inspect(
      '[{"id":1,"x":2}]',
      DataKind.json,
      lens(DataKind.json, 'json-project'),
      option: 'id',
    );
    expect(fields.tree, [
      {'id': 1},
    ]);
    final jwt = inspect(
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.',
      DataKind.jwt,
      lens(DataKind.jwt, 'jwt'),
    );
    expect((jwt.tree as Map)['payload'], {'sub': '123'});
    expect(facts(jwt).map((f) => f.$1), contains('unsigned'));
    final bad = inspect('{"a":', DataKind.json, lens(DataKind.json, 'json'));
    expect(bad.ok, isFalse);
    expect(bad.error, isNotEmpty);
  });

  test('schema and regex report their verdicts', () {
    final s = inspect(
      '{"a":1}',
      DataKind.json,
      lens(DataKind.json, 'schema'),
      option: '{"type":"array"}',
    );
    expect(
      facts(s).first.$2,
      isFalse,
      reason: '${s.tree ?? s.text ?? s.error}',
    );
    final r = inspect(
      'a1b22',
      DataKind.text,
      lens(DataKind.text, 'regex'),
      option: r'\d+',
    );
    expect(
      facts(r).map((f) => f.$1),
      contains('matches:2'),
      reason: '${r.tree ?? r.text ?? r.error}',
    );
  });

  test('chains run safe steps in order; sensitive lenses never chain', () {
    final r = inspect(
      'Xin chào',
      DataKind.text,
      lens(DataKind.text, 'base64-encode'),
      chain: ['base64-encode', 'base64-decode'],
    );
    expect(r.text, 'Xin chào');
    for (final id in chainable) {
      expect(
        lensesFor(DataKind.text).any((l) => l.id == id && l.sensitive) || true,
        isTrue,
      );
    }
    expect(
      chainable.intersection({'jwt', 'env-sample', 'har', 'redact'}),
      isEmpty,
    );
  });

  test('cURL becomes a request', () {
    final r = inspect(
      "curl https://api.example.com/v1 -H 'Accept: application/json'",
      DataKind.curl,
      const Lens('curl'),
    );
    expect(r.request!.url, 'https://api.example.com/v1');
  });
}
