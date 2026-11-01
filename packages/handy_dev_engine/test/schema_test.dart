import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';

void main() {
  if (!regexSupported) return;
  bool valid(Object? data, Object schema) =>
      validateJsonSchema(jsonEncode(data), jsonEncode(schema))['valid'] as bool;
  test(
    'draft-07 objects, tuple arrays, composition and local references are real validation',
    () {
      final schema = {
        'type': 'object',
        'required': ['name', 'tags'],
        'properties': {
          'name': {'type': 'string', 'minLength': 2},
          'tags': {
            'type': 'array',
            'items': {r'$ref': '#/definitions/tag'},
            'uniqueItems': true,
          },
        },
        'definitions': {
          'tag': {'type': 'string', 'pattern': r'^\p{L}+$'},
        },
        'additionalProperties': false,
      };
      expect(
        valid({
          'name': 'An',
          'tags': ['Việt'],
        }, schema),
        isTrue,
      );
      expect(
        valid({
          'name': 'A',
          'tags': ['x', 'x'],
          'extra': 1,
        }, schema),
        isFalse,
      );
      expect(
        valid(
          [1, 'two'],
          {
            'type': 'array',
            'items': [
              {'type': 'integer'},
              {'type': 'string'},
            ],
            'additionalItems': false,
          },
        ),
        isTrue,
      );
      expect(
        valid(
          [1, 'two', 3],
          {
            'items': [true, true],
            'additionalItems': false,
          },
        ),
        isFalse,
      );
      expect(
        valid(2, {
          'allOf': [
            {'minimum': 1},
            {'maximum': 3},
          ],
        }),
        isTrue,
      );
      expect(
        valid(2, {
          'oneOf': [
            {'type': 'number'},
            {'type': 'integer'},
          ],
        }),
        isFalse,
      );
      expect(valid(null, false), isFalse);
      expect(valid(null, true), isTrue);
    },
  );
  test(
    'conditionals, dependencies, propertyNames, contains, const and patternProperties',
    () {
      expect(
        valid(
          {'kind': 'a', 'value': 1},
          {
            'if': {
              'properties': {
                'kind': {'const': 'a'},
              },
            },
            'then': {
              'required': ['value'],
            },
            'else': {
              'required': ['other'],
            },
          },
        ),
        isTrue,
      );
      expect(
        valid(
          {'kind': 'b'},
          {
            'if': {
              'properties': {
                'kind': {'const': 'a'},
              },
            },
            'then': {
              'required': ['value'],
            },
            'else': {
              'required': ['other'],
            },
          },
        ),
        isFalse,
      );
      expect(
        valid(
          {'a': 1},
          {
            'dependencies': {
              'a': ['b'],
            },
          },
        ),
        isFalse,
      );
      expect(
        valid(
          {'x': 1},
          {
            'propertyNames': {'pattern': '^[a-z]+\$'},
          },
        ),
        isTrue,
      );
      expect(
        valid(
          ['a', 2],
          {
            'contains': {'type': 'integer'},
          },
        ),
        isTrue,
      );
      expect(
        valid(
          {'item1': 2},
          {
            'patternProperties': {
              '^item': {'type': 'integer'},
            },
            'additionalProperties': false,
          },
        ),
        isTrue,
      );
      expect(
        valid(
          {'item1': 'bad'},
          {
            'patternProperties': {
              '^item': {'type': 'integer'},
            },
          },
        ),
        isFalse,
      );
    },
  );
  test(
    'RE2 schema patterns reject unsafe syntax and hostile input finishes',
    () {
      for (final pattern in [r'(a)\1', r'a(?=b)']) {
        expect(
          () => valid('aaa', {'pattern': pattern}),
          throwsA(isA<Exception>()),
        );
      }
      expect(valid('${'a' * 99999}!', {'pattern': r'(a+)+$'}), isFalse);
    },
  );
  test(
    'formats remain annotations across compositions; inputs are not mutated',
    () {
      expect(valid('not an email', {'format': 'email'}), isTrue);
      expect(
        valid('not an email', {
          'allOf': [
            {'format': 'email'},
          ],
        }),
        isTrue,
      );
      final input = {'name': 'An'};
      final raw = jsonEncode(input);
      expect(
        valid(input, {
          'properties': {
            'extra': {'default': 1},
          },
        }),
        isTrue,
      );
      expect(jsonEncode(input), raw);
    },
  );
  test(
    'remote refs, unknown dialect/keywords, schema size and output explosion reject',
    () {
      for (final schema in [
        {r'$ref': 'https://example.invalid/schema.json'},
        {r'$ref': 'file:///private/schema'},
        {'unknownKeyword': true},
        {r'$schema': 'https://json-schema.org/draft/2020-12/schema'},
      ]) {
        expect(() => valid({}, schema), throwsA(isA<Exception>()));
      }
      expect(
        () => validateJsonSchema('{}', ' ' * 20001),
        throwsFormatException,
      );
      expect(
        () => valid(List.generate(2000, (i) => i), {'uniqueItems': true}),
        throwsFormatException,
      );
    },
  );
  test(
    'validation never opens a network client and preserves JSON error paths',
    () {
      HttpOverrides.runZoned(
        () {
          final output = validateJsonSchema(
            '{"x":"bad"}',
            '{"properties":{"x":{"type":"integer"}}}',
          );
          expect(output['valid'], isFalse);
          expect((output['errors'] as List).first['instancePath'], '/x');
          expect(
            () => valid({}, {r'$ref': 'https://example.invalid/schema'}),
            throwsA(isA<Exception>()),
          );
        },
        createHttpClient: (_) => throw StateError('Unexpected network client'),
      );
    },
  );
}
