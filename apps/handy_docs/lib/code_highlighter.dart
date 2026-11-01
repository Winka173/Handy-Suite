import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Bounded lexical styling only. No execution, language inference or HTML output.
class LocalCodeHighlighter extends SyntaxHighlighter {
  final bool dark;
  LocalCodeHighlighter({this.dark = false});
  static const keywords = {
    'abstract',
    'as',
    'async',
    'await',
    'bool',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'def',
    'default',
    'delete',
    'do',
    'double',
    'else',
    'enum',
    'except',
    'export',
    'extends',
    'false',
    'final',
    'finally',
    'float',
    'for',
    'from',
    'function',
    'if',
    'implements',
    'import',
    'in',
    'int',
    'interface',
    'is',
    'let',
    'new',
    'None',
    'null',
    'of',
    'override',
    'pass',
    'private',
    'public',
    'return',
    'static',
    'string',
    'String',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'type',
    'typeof',
    'var',
    'void',
    'while',
    'with',
    'yield',
  };
  @override
  TextSpan format(String source) {
    if (source.length > 60000) return TextSpan(text: source);
    final spans = <TextSpan>[];
    var at = 0, plain = 0;
    bool digit(int c) => c >= 48 && c <= 57;
    bool letter(int c) =>
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c == 36;
    void styled(int start, int end, Color color) {
      if (plain < start)
        spans.add(TextSpan(text: source.substring(plain, start)));
      spans.add(
        TextSpan(
          text: source.substring(start, end),
          style: TextStyle(color: color),
        ),
      );
      plain = end;
    }

    while (at < source.length) {
      if (spans.length > 8000) return TextSpan(text: source);
      final start = at, c = source.codeUnitAt(at);
      if (c == 39 || c == 34 || c == 96) {
        at++;
        while (at < source.length) {
          final current = source.codeUnitAt(at++);
          if (current == 92 && at < source.length) {
            at++;
            continue;
          }
          if (current == c) break;
        }
        styled(
          start,
          at,
          dark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
        );
      } else if (c == 35 ||
          c == 47 &&
              at + 1 < source.length &&
              source.codeUnitAt(at + 1) == 47) {
        while (at < source.length && source.codeUnitAt(at) != 10) at++;
        styled(
          start,
          at,
          dark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        );
      } else if (c == 47 &&
          at + 1 < source.length &&
          source.codeUnitAt(at + 1) == 42) {
        at += 2;
        while (at < source.length) {
          if (source.codeUnitAt(at) == 42 &&
              at + 1 < source.length &&
              source.codeUnitAt(at + 1) == 47) {
            at += 2;
            break;
          }
          at++;
        }
        styled(
          start,
          at,
          dark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        );
      } else if (digit(c)) {
        at++;
        while (at < source.length &&
            (digit(source.codeUnitAt(at)) || source.codeUnitAt(at) == 46))
          at++;
        styled(
          start,
          at,
          dark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412),
        );
      } else if (letter(c)) {
        at++;
        while (at < source.length &&
            (letter(source.codeUnitAt(at)) || digit(source.codeUnitAt(at))))
          at++;
        if (keywords.contains(source.substring(start, at)))
          styled(
            start,
            at,
            dark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9),
          );
      } else {
        at++;
      }
    }
    if (plain < source.length)
      spans.add(TextSpan(text: source.substring(plain)));
    return TextSpan(children: spans);
  }
}
