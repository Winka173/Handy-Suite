import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';

void main() {
  test('literal find retains Unicode point columns and CRLF lines', () {
    final r = findMarkdownLiteral('🧪 foo\r\nbar foo foo', 'foo');
    expect(r.count, 3);
    expect(r.first, (line: 1, column: 3));
    expect(findMarkdownLiteral('aaa', 'aa').count, 1);
    expect(findMarkdownLiteral('abc', 'missing').first, null);
    expect(() => findMarkdownLiteral('abc', ''), throwsFormatException);
  });
  test('replacement treats dollar tokens and backslashes as literal data', () {
    expect(
      replaceMarkdownLiteral('a a', 'a', r'$& $1 $$ \'),
      r'$& $1 $$ \ $& $1 $$ \',
    );
    expect(
      () => replaceMarkdownLiteral('a' * 1000000, 'a', 'bb'),
      throwsFormatException,
    );
  });
  test('templates append preserve newline and source without truncation', () {
    expect(
      insertMarkdownTemplate('source\r\n', 'heading'),
      'source\r\n\r\n## Heading\r\n',
    );
    expect(
      insertMarkdownTemplate('', 'checklist', locale: 'vi'),
      contains('Việc cần làm'),
    );
    expect(() => insertMarkdownTemplate('', 'bad'), throwsFormatException);
    expect(
      () => insertMarkdownTemplate('', 'heading', locale: 'xx'),
      throwsFormatException,
    );
  });
  test(
    'legacy PDF page selection preserves duplicates/order with strict bounds',
    () {
      expect(pageRange('1,3-5,1', 5), [0, 2, 3, 4, 0]);
      for (final bad in ['', '0', '2-1', '1-6', '1,,2', '1;2', '-1']) {
        expect(() => pageRange(bad, 5), throwsFormatException);
      }
      expect(() => pageRange('1', 0), throwsFormatException);
      expect(() => pageRange('1-501', 1000), throwsFormatException);
    },
  );
}
