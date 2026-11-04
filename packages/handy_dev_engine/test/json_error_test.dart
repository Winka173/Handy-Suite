import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev_engine/src/transforms.dart';

String error(String text) {
  try {
    parseJson(text);
  } on FormatException catch (e) {
    return e.message;
  }
  return '';
}

void main() {
  test('line and column count lines and CRLF', () {
    expect(textPlace('ab\ncd', 4), (line: 2, column: 2));
    expect(textPlace('a\r\nb', 3), (line: 2, column: 1));
    expect(textPlace('', 0), (line: 1, column: 1));
  });

  test('common mistakes are named where they are', () {
    expect(
      error('{\n  "a": 1,\n}'),
      startsWith('Line 3, column 1: remove the comma before it'),
    );
    expect(error("{'a': 1}"), contains('double quotes "…"'));
    expect(error('{a: 1}'), contains('keys need double quotes'));
    expect(error('{"a": 1 // n\n}'), contains('JSON has no comments'));
    expect(error('{"a": 1 "b": 2}'), contains('a comma is missing'));
    expect(error('[1, 2'), contains('ends early'));
  });

  test('both languages, the excerpt and the offset survive', () {
    final text = '{"url": "a / b",}';
    try {
      parseJson(text);
      fail('parsed');
    } on FormatException catch (e) {
      expect(e.offset, text.indexOf('}'));
      final i = e.message.indexOf(' / ');
      expect(e.message.substring(0, i), startsWith('Line 1, column 17'));
      expect(e.message.substring(i + 3), startsWith('Dòng 1, cột 17'));
      expect(e.message, contains('"a / b"'));
    }
  });

  test('valid JSON still parses', () {
    expect(parseJson('{"a": [1, 2]}'), {
      'a': [1, 2],
    });
  });
}
