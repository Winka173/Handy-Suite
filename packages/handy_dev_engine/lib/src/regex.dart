import 'dart:convert';
import 'regex_native.dart'
    if (dart.library.js_interop) 'regex_web.dart'
    as engine;

bool get regexSupported => engine.supported;

bool regexHasMatch(String text, String pattern) {
  if (text.length > 1000000 ||
      utf8.encode(text).length > 1000000 ||
      pattern.length > 1000 ||
      utf8.encode(pattern).length > 1000)
    throw const FormatException('Schema regex byte limit exceeded');
  return engine.test(text, pattern);
}

Map<String, Object?> regex(String text, String pattern) {
  if (text.length > 100000 ||
      utf8.encode(text).length > 100000 ||
      pattern.length > 1000 ||
      utf8.encode(pattern).length > 1000) {
    throw const FormatException(
      'RE2 limits: 100 KB input / 1000 UTF-8 bytes pattern',
    );
  }
  return engine.matches(text, pattern);
}
