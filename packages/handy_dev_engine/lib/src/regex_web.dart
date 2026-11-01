import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('globalThis')
external JSObject get _global;
@JS('handyRe2Matches')
external JSString _matches(JSString text, JSString pattern);
@JS('handyRe2Test')
external JSString _test(JSString text, JSString pattern);

bool test(String text, String pattern) {
  final result = jsonDecode(_test(text.toJS, pattern.toJS).toDart);
  if (result is! Map || result['ok'] != true || result['value'] is! bool)
    throw const FormatException('Schema RE2 pattern could not be evaluated');
  return result['value'] as bool;
}

bool get supported => _global.hasProperty('handyRe2Matches'.toJS).toDart;
Map<String, Object?> matches(String text, String pattern) {
  if (!supported)
    throw UnsupportedError('The bundled RE2JS Web bridge is unavailable');
  final result = jsonDecode(_matches(text.toJS, pattern.toJS).toDart);
  if (result is! Map || result['ok'] != true || result['value'] is! Map) {
    throw FormatException(
      result is Map && result['error'] is String
          ? result['error'] as String
          : 'RE2 operation failed',
    );
  }
  return Map<String, Object?>.from(result['value'] as Map);
}
