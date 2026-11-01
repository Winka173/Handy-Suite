import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs/code_highlighter.dart';

void main() {
  test(
    'literal code text is preserved while distinct token classes receive local styles',
    () {
      const code =
          'const tên = "// private <script> 😀";\r\n/* comment */\nreturn 123.4; # chú thích\n';
      for (final dark in [false, true]) {
        final span = LocalCodeHighlighter(dark: dark).format(code);
        expect(span.toPlainText(), code);
        final children = span.children!;
        expect(
          children.where((s) => s.toPlainText() == 'const').single.style,
          isNotNull,
        );
        expect(
          children
              .where((s) => s.toPlainText().startsWith('"//'))
              .single
              .toPlainText(),
          '"// private <script> 😀"',
        );
        expect(
          children.where((s) => s.toPlainText() == '123.4').single.style,
          isNotNull,
        );
      }
    },
  );
  test(
    'unterminated strings/comments, token floods and large blocks stay bounded and exact',
    () {
      for (final code in [
        '"unterminated\\',
        '/* unfinished',
        '// x\n' * 10000,
        'const x=1; ' * 10000,
        '',
      ]) {
        final output = LocalCodeHighlighter().format(code);
        expect(output.toPlainText(), code);
        if (code.length > 60000) expect(output.children, isNull);
      }
    },
  );
}
