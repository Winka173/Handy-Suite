import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';

void main() {
  test(
    'Unicode source draft roundtrip preserves exact BOM, CRLF and content',
    () {
      const source = '\ufeff# Tiếng Việt\r\n\r\n- [x] Done\r\n';
      final raw = serializeMarkdownDraft(source);
      expect(parseMarkdownDraft(raw), source);
      expect(serializeMarkdownDraft(parseMarkdownDraft(raw)), raw);
      expect(parseMarkdownDraft(serializeMarkdownDraft('')), '');
      for (final raw in [
        'bad',
        '{}',
        '{"format":"handy-docs-markdown","version":2,"source":"x"}',
        '{"format":"handy-docs-markdown","version":1,"source":0}',
      ]) {
        expect(() => parseMarkdownDraft(raw), throwsFormatException);
      }
    },
  );
  test('safe HTML escapes raw HTML, disables images and unsafe link schemes', () {
    final result = parseMarkdownDocument(
      '<script>alert(1)</script>\n\n<img src="https://secret.invalid/x" onerror="alert(1)">\n\n![alt](file:///private) [bad](javascript:alert) [good](https://example.org/?a=1&b=2)',
    );
    expect(result.html, isNot(contains('<script>')));
    expect(result.html, isNot(contains('<img')));
    expect(result.html, isNot(contains('href="javascript:')));
    expect(result.html, contains('href="https://example.org/?a=1&amp;b=2"'));
    expect(result.html, contains("default-src 'none'"));
    expect(result.text, contains('alt'));
    expect(result.source, contains('file:///private'));
  });
  test(
    'GFM heading/table/checklist/fenced code and Unicode text are real output',
    () {
      final result = parseMarkdownDocument(
        '# Tiếng Việt\n\n| A | B |\n| --- | --- |\n| one | two |\n\n- [x] Done\n- [ ] Next\n\n```dart\nx < 2 && y > 0\n```',
      );
      expect(result.html, contains('<h1>Tiếng Việt</h1>'));
      expect(result.html, contains('<table>'));
      expect(result.html, contains('[x]'));
      expect(result.html, contains('[ ]'));
      expect(result.html, contains('x &lt; 2 &amp;&amp; y &gt; 0'));
      expect(result.text, contains('one\ttwo'));
      expect(utf8.decode(utf8.encode(result.html)), result.html);
    },
  );
  test(
    'invalid draft fields and UTF-8 byte limits are rejected before replacing data',
    () {
      expect(() => serializeMarkdownDraft('€' * 340000), throwsFormatException);
      expect(() => parseMarkdownDocument('€' * 340000), throwsFormatException);
      expect(
        () => parseMarkdownDraft(
          jsonEncode({
            'format': 'handy-docs-markdown',
            'version': 1,
            'source': 'ok',
            'pro': true,
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => parseMarkdownDocument(('**x** ' * 40000)),
        throwsFormatException,
      );
      expect(
        () => parseMarkdownDocument('${'[' * 61}x${']' * 61}'),
        throwsFormatException,
      );
      expect(
        () => parseMarkdownDocument('${'> ' * 61}x'),
        throwsFormatException,
      );
    },
  );
}
