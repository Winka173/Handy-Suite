import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';

void main() {
  final value = {
    'items': [
      {'name': 'Máy ảnh', 'id': 1},
      {'name': 'Phone', 'id': 2},
    ],
    'a/b': {'~key': null},
    'constructor': 'own data',
  };
  test('JSONPath wildcard indexed quoted and root selections', () {
    expect(selectJsonPath(value, r'$.items[*].name'), ['Máy ảnh', 'Phone']);
    expect(selectJsonPath(value, r'$.items[1].id'), [2]);
    expect(selectJsonPath(value, r'$["a/b"]["~key"]'), [null]);
    expect(selectJsonPath(value, r'$.constructor'), ['own data']);
    expect(selectJsonPath(value, r'$.missing'), []);
    expect(selectJsonPath(value, r'$'), [value]);
    expect(selectJsonPath([3], r'$["0"]'), [3]);
  });
  for (final bad in [
    'items',
    '\$..name',
    '\$[?(@.id)]',
    '\$[-1]',
    '\$[01]',
    '\$["a"',
    '\$[',
    '\$[9007199254740999]',
  ]) {
    test(
      'JSONPath unsupported syntax rejects $bad',
      () => expect(() => selectJsonPath(value, bad), throwsFormatException),
    );
  }
  test('JSONPath step and match caps', () {
    expect(
      () => selectJsonPath(value, r'$' + '.a' * 31),
      throwsFormatException,
    );
    expect(
      () => selectJsonPath(List.filled(10001, 0), r'$[*]'),
      throwsFormatException,
    );
  });
  test(
    'projection preserves nested values omits missing and duplicate keys',
    () {
      final rows = [
        {
          'id': 1,
          'x': {'v': true},
        },
        {'id': 2, 'other': 1},
      ];
      expect(projectFields(rows, ['id', 'x', 'id']), [
        {
          'id': 1,
          'x': {'v': true},
        },
        {'id': 2},
      ]);
      expect(rows.last['other'], 1);
      expect(() => projectFields([1], ['id']), throwsFormatException);
      expect(() => projectFields(rows, []), throwsFormatException);
    },
  );
  test('tree pointer paths and collapsing ancestor-aware search', () {
    final index = indexJson(value);
    expect(index.nodes['/a~1b/~0key']!.value, null);
    expect(visibleJsonRows(index, {}).map((n) => n.path), ['']);
    expect(visibleJsonRows(index, {''}).map((n) => n.path), [
      '',
      '/items',
      '/a~1b',
      '/constructor',
    ]);
    expect(visibleJsonRows(index, {}, 'máy').map((n) => n.path), [
      '',
      '/items',
      '/items/0',
      '/items/0/name',
    ]);
  });
  test('tree snapshots source and truncates preview', () {
    final source = {'text': 'x' * 200};
    final index = indexJson(source);
    source['text'] = 'changed';
    expect(index.nodes['/text']!.preview.length, 158);
    expect(index.nodes['/text']!.value, 'x' * 200);
    expect(() => index.nodes.clear(), throwsUnsupportedError);
    expect(() => index.nodes['']!.children.clear(), throwsUnsupportedError);
  });
  test('viewer caps nodes depths property and search', () {
    expect(() => indexJson(List.filled(10000, 0)), throwsFormatException);
    expect(() => indexJson({'x' * 513: 0}), throwsFormatException);
    final index = indexJson(0);
    expect(() => visibleJsonRows(index, {}, 'x' * 201), throwsFormatException);
  });
  test('table missing vs null and stable filtered source index', () {
    final t = flatJsonTable([
      {'id': 1, 'value': null},
      {'id': 2, 'name': 'Camera'},
    ]);
    expect(t.columns, ['id', 'value', 'name']);
    expect(tableCell(t.rows[0], 'value'), 'null');
    expect(tableCell(t.rows[0], 'name'), '[missing]');
    expect(filterTableRows(t, 'camera').single.index, 1);
    expect(() => t.rows[0]['id'] = 0, throwsUnsupportedError);
    expect(
      () => flatJsonTable([
        {'nested': []},
      ]),
      throwsFormatException,
    );
    expect(
      () => flatJsonTable([
        {for (var i = 0; i < 21; i++) 'k$i': i},
      ]),
      throwsFormatException,
    );
  });
}
