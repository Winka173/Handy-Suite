import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';

DevTool tool(String id) => devTools.singleWhere((t) => t.id == id);
void main() {
  test(
    'TOML local dates/times retain local semantics and offset UTC normalization',
    () {
      final result = parseToml(
        'date = 2026-10-31\ntime = 08:09:10\nlocal = 2026-10-31T08:09:10\noffset = 2026-10-31T08:09:10+07:00',
      );
      expect(result['date'], '2026-10-31');
      expect(result['time'], '08:09:10');
      expect(result['local'], '2026-10-31T08:09:10');
      expect(result['offset'], '2026-10-31T01:09:10.000Z');
    },
  );
  test('XML deep nesting rejected before recursive conversion', () {
    expect(
      () => parseXml('${'<a>' * 42}x${'</a>' * 42}'),
      throwsFormatException,
    );
  });
  test('stable IDs; only actual platform implementations are registered', () {
    expect(devTools.length, regexSupported ? 22 : 20);
    expect(devTools.map((t) => t.id).toSet().length, devTools.length);
    expect(devTools.any((t) => t.id == 'regex'), regexSupported);
    expect(devTools.any((t) => t.id == 'schema'), regexSupported);
  });
  test('JSON format/minify Unicode and scalar parity', () {
    expect(jsonDecode(tool('json').run('{"emoji":"🧪","nil":null}')), {
      'emoji': '🧪',
      'nil': null,
    });
    expect(tool('json').run(' [ 1, true, null ] ', 'min'), '[1,true,null]');
  });
  for (final bad in ['{"x":}', '[1,]', 'undefined', 'NaN', '1e999']) {
    test(
      'reject malformed/nonfinite JSON $bad',
      () => expect(() => parseJson(bad), throwsA(isA<FormatException>())),
    );
  }
  test('structured bounds count expanded values and detect cycles', () {
    expect(() => parseJson('${'[' * 41}0${']' * 41}'), throwsFormatException);
    final a = <dynamic>[];
    a.add(a);
    expect(() => assertJsonData(a), throwsFormatException);
    expect(() => assertJsonData(List.filled(100001, 0)), throwsFormatException);
    expect(() => assertJsonData({1: 'key'}), throwsFormatException);
  });
  test(
    'UTF8 byte bounds include multibyte data',
    () => expect(() => bounded('🧪' * 260000), throwsFormatException),
  );
  test('YAML native types, flow export roundtrip', () {
    final v = parseYaml('name: "máy ảnh"\nactive: true\nitems: [1, 2]\n');
    expect(v, {
      'name': 'máy ảnh',
      'active': true,
      'items': [1, 2],
    });
    expect(parseYaml(tool('convert').run(jsonEncode(v), 'json yaml')), v);
  });
  for (final bad in ['a: 1\na: 2', 'a: .inf', '? [x,y]\n: z']) {
    test(
      'YAML rejects duplicate/nonJSON keys $bad',
      () => expect(() => parseYaml(bad), throwsA(anything)),
    );
  }
  test('YAML alias expansion bounds', () {
    var source = 'a: &a [0,0,0,0,0,0,0,0,0,0]\n';
    for (var i = 1; i <= 6; i++) {
      final prev = i == 1 ? 'a' : 'n${i - 1}';
      source += 'n$i: &n$i [${List.filled(10, '*$prev').join(',')}]\n';
    }
    expect(() => parseYaml(source), throwsFormatException);
  });
  test('TOML structured JSON roundtrip', () {
    final v = {
      'title': 'Tiếng Việt',
      'enabled': true,
      'items': [1, 2],
      'server': {'port': 443},
      'people': [
        {'name': 'A'},
        {'name': 'B'},
      ],
    };
    expect(parseToml(jsonToToml(v)), v);
  });
  test('TOML dates to ISO and null/unsafe rejected', () {
    expect(
      (parseToml('at = 2026-10-31T08:00:00Z') as Map)['at'],
      '2026-10-31T08:00:00.000Z',
    );
    expect(() => jsonToToml({'x': null}), throwsFormatException);
    expect(() => jsonToToml({'x': 9007199254740992}), throwsFormatException);
    expect(() => jsonToToml([1]), throwsFormatException);
  });
  test('XML repeated children attributes and encoded scalar roundtrip', () {
    final v = {
      'root': {
        '@_id': '01',
        'name': 'A & B',
        'n': [1, 2],
        'active': true,
      },
    };
    final xml = jsonToXml(v);
    expect(xml, contains('&amp;'));
    expect(parseXml(xml), v);
  });
  for (final bad in [
    '<!DOCTYPE a [<!ENTITY x SYSTEM "file:///secret">]><a>&x;</a>',
    '<a><b></a>',
    '<a>',
  ]) {
    test(
      'XML rejects DTD/malformed $bad',
      () => expect(() => parseXml(bad), throwsA(anything)),
    );
  }
  test('XML unsafe name/multiple roots reject', () {
    expect(() => jsonToXml({'a': 0, 'b': 1}), throwsFormatException);
    expect(() => jsonToXml({'bad name': 1}), throwsFormatException);
  });
  test('CSV multiline Unicode quotes and empty cells roundtrip', () {
    final rows = [
      {'name': 'máy, ảnh', 'notes': 'line1\n"two"', 'empty': ''},
      {'name': 'B', 'notes': 'ok', 'empty': ''},
    ];
    expect(parseCsv(jsonCsv(jsonEncode(rows))), rows);
  });
  for (final d in [',', ';', '\t', '|']) {
    test(
      'CSV detects delimiter ${jsonEncode(d)}',
      () => expect(parseCsv('a${d}b\n1${d}2'), [
        {'a': '1', 'b': '2'},
      ]),
    );
  }
  for (final bad in [
    'a,a\n1,2',
    'a,b\n1',
    'a,b\n"bad,2',
    'a,b\n"a"garbage,2',
  ]) {
    test(
      'CSV rejects invalid $bad',
      () => expect(() => parseCsv(bad), throwsFormatException),
    );
  }
  test('CSV formulas escaped intentionally lossy; nested values rejected', () {
    expect(parseCsv(jsonCsv('[{"v":"=cmd"}]')).single['v'], "'=cmd");
    expect(() => jsonCsv('[{"v":{}}]'), throwsFormatException);
    expect(() => jsonCsv('[1]'), throwsFormatException);
  });
  test('JSONL preserves real line number including blank lines', () {
    expect(jsonDecode(tool('jsonl').run('1\n\n{"x":2}')), [
      1,
      {'x': 2},
    ]);
    expect(
      () => tool('jsonl').run('1\n\n{bad}'),
      throwsA(predicate((e) => e.toString().contains('line 3'))),
    );
  });
  test('Base64 Unicode and URLsafe roundtrip', () {
    for (final s in ['', 'Tiếng Việt 🧪', '\x00']) {
      expect(decode64(tool('base64').run(s)), s);
    }
    expect(decode64('8J-nqg'), '🧪');
  });
  for (final bad in ['Zg=', 'Zh==', 'Z===', 'a', '/w==', ' a ']) {
    test(
      'Base64 rejects bad padding/bits/UTF8 $bad',
      () => expect(() => decode64(bad), throwsFormatException),
    );
  }
  test('URL component roundtrip strict UTF8', () {
    const s = 'Tiếng Việt ?&+=🧪';
    expect(tool('url').run(tool('url').run(s), 'decode'), s);
    expect(tool('url').run('a+b', 'decode'), 'a+b');
    expect(() => tool('url').run('%FF', 'decode'), throwsFormatException);
    expect(() => tool('url').run('%Q1', 'decode'), throwsFormatException);
  });
  test('known cryptographic hash fixtures', () {
    expect(
      tool('hash').run('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      tool('hash').run('abc', 'sha512'),
      'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f',
    );
  });
  test('JWT always unverified and invalid expiration explicit', () {
    String enc(dynamic v) =>
        base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
    final r = jwt(
      '${enc({'alg': 'none'})}.${enc({'exp': 0})}.',
      now: DateTime.utc(2026),
    );
    expect(r['signatureVerified'], false);
    expect(r['expired'], true);
    expect(r['expiration'], '1970-01-01T00:00:00.000Z');
    expect(
      jwt('${enc({})}.${enc({'exp': 'bad'})}.')['expirationError'],
      isNotNull,
    );
    expect(() => jwt('a.b'), throwsFormatException);
    expect(() => jwt('${enc([])}.${enc({})}.'), throwsFormatException);
  });
  test('JSON diff pointer escaping null vs missing arrays', () {
    expect(
      diff(
        {
          'a/b': {'~': 1},
          'remove': null,
        },
        {
          'a/b': {'~': 2},
          'add': null,
        },
      ),
      [
        {'path': '/a~1b/~0', 'kind': 'change', 'before': 1, 'after': 2},
        {'path': '/remove', 'kind': 'remove', 'before': null},
        {'path': '/add', 'kind': 'add', 'after': null},
      ],
    );
    expect(diff([1], [1, 2]).single['path'], '/1');
  });
  test('redaction traverses arrays and credential key variants', () {
    expect(
      redact({
        'ok': [
          {'api-key': 'x', 'password': 'y', 'value': 'retained'},
        ],
        'Authorization': 'z',
      }),
      {
        'ok': [
          {
            'api-key': '[REDACTED]',
            'password': '[REDACTED]',
            'value': 'retained',
          },
        ],
        'Authorization': '[REDACTED]',
      },
    );
  });
  test('TypeScript homogeneous union inference optional fields', () {
    final result = inferTypeScript([
      {'id': 1, 'name': 'a'},
      {'id': 2, 'enabled': true},
    ], 'Entry');
    expect(
      result,
      contains(
        'Array<{ "enabled"?: boolean; "id": number; "name"?: string; }>',
      ),
    );
    expect(inferTypeScript([]), contains('Array<unknown>'));
    expect(inferTypeScript({}), contains('Record<string, unknown>'));
    expect(() => inferTypeScript({}, 'class'), throwsFormatException);
  });
  test('schema inference integer union missing fields and empty arrays', () {
    final schema = inferJsonSchema([
      {'id': 1},
      {'id': 2, 'x': null},
    ]);
    expect(schema['items']['required'], ['id']);
    expect(schema['items']['properties']['x'], {'type': 'null'});
    expect(inferJsonSchema([])['items'], {});
    expect(inferJsonSchema([1, 'a'])['items']['anyOf'], [
      {'type': 'integer'},
      {'type': 'string'},
    ]);
  });

  test('convert goes through JSON both ways and refuses other pairs', () {
    const v = {
      'a': 1,
      'b': [true, 'x'],
    };
    final yaml = tool('convert').run(jsonEncode(v), 'json yaml');
    expect(jsonDecode(tool('convert').run(yaml, 'yaml json')), v);
    final toml = tool('convert').run('{"a":1}', 'json toml');
    expect(jsonDecode(tool('convert').run(toml, 'toml json')), {'a': 1});
    expect(jsonDecode(tool('convert').run('a,b\n1,2', 'csv → json')), [
      {'a': '1', 'b': '2'},
    ]);
    for (final bad in ['yaml toml', 'json json', 'json', 'json pdf', '']) {
      expect(() => tool('convert').run('{}', bad), throwsFormatException);
    }
  });
  test('old tool ids still run as the merged tools', () {
    expect(runDevTool('sha512', 'abc'), tool('hash').run('abc', 'sha512'));
    expect(
      runDevTool('base64-decode', runDevTool('base64-encode', 'Xin chào')),
      'Xin chào',
    );
    expect(runDevTool('json-min', '{ "a" : 1 }'), '{"a":1}');
    expect(() => runDevTool('har', '{}'), throwsFormatException);
    for (final a in devToolAliases.values) {
      expect(devTools.map((t) => t.id), contains(a.$1));
    }
  });
  group('colors', () {
    test('black white WCAG', () => expect(contrast('#000000', '#ffffff'), 21));
    for (final v in <String, Map<String, num>>{
      '#ff0000': {'h': 0, 's': 100, 'l': 50},
      '#00ff00': {'h': 120, 's': 100, 'l': 50},
      '#0000ff': {'h': 240, 's': 100, 'l': 50},
      '#ffffff': {'h': 0, 's': 0, 'l': 100},
      '#000000': {'h': 0, 's': 0, 'l': 0},
    }.entries) {
      test(v.key, () => expect(colors(v.key)['hsl'], v.value));
    }
    test(
      'invalid hex',
      () => expect(() => colors('#fff'), throwsFormatException),
    );
  });
  test('contrast reads two colours from input and options', () {
    final r = jsonDecode(tool('contrast').run('#777777', '#FFFFFF'));
    expect(r['ratio'], 4.48);
    expect(r['normalTextAA'], false);
    expect(r['largeTextAA'], true);
    expect(jsonDecode(tool('contrast').run('#000000 on #ffffff'))['ratio'], 21);
    expect(() => tool('contrast').run('#000000'), throwsFormatException);
  });

  test(
    'filter takes a path or field names; infer makes TypeScript or a schema',
    () {
      const data = '{"items":[{"id":1,"name":"An","x":true}]}';
      expect(jsonDecode(tool('json-filter').run(data, r'$.items[*].name')), [
        'An',
      ]);
      expect(jsonDecode(tool('json-filter').run('[{"id":1,"x":2}]', 'id')), [
        {'id': 1},
      ]);
      expect(jsonDecode(tool('json-filter').run('[{"id":1,"x":2}]', '["x"]')), [
        {'x': 2},
      ]);
      expect(tool('json-infer').run('{"a":1}', 'Order'), contains('Order'));
      expect(
        jsonDecode(tool('json-infer').run('{"a":1}', 'schema'))['type'],
        'object',
      );
      // Old ids still run, with their options.
      expect(jsonDecode(runDevTool('jsonpath', data, r'$.items[*].id')), [1]);
      expect(runDevTool('json-typescript', '{"a":1}', 'Row'), contains('Row'));
      expect(
        jsonDecode(runDevTool('json-schema-infer', '{"a":1}'))['type'],
        'object',
      );
    },
  );
}
