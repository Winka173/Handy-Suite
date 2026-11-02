/// HMAC-SHA256/SHA512. The key is a secret: no message here ever repeats it.
library;

import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

const maxHmacKeyBytes = 10000;

List<int> _key(String key, String format) {
  switch (format) {
    case 'text':
      return utf8.encode(key);
    case 'hex':
      final h = key.replaceAll(RegExp(r'\s'), '');
      if (h.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(h)) {
        throw const FormatException(
          'The key is not valid hex / Khóa không phải hex hợp lệ',
        );
      }
      return [
        for (var i = 0; i < h.length; i += 2)
          int.parse(h.substring(i, i + 2), radix: 16),
      ];
    case 'base64':
      try {
        var b = key.trim().replaceAll('-', '+').replaceAll('_', '/');
        b = b.padRight((b.length + 3) ~/ 4 * 4, '=');
        return base64.decode(b);
      } catch (_) {
        throw const FormatException(
          'The key is not valid Base64 / Khóa không phải Base64 hợp lệ',
        );
      }
    default:
      throw const FormatException(
        'Key format must be text, hex or base64 / '
        'Dạng khóa phải là text, hex hoặc base64',
      );
  }
}

/// HMAC of the UTF-8 [message] (exactly as given, whitespace included).
String hmacSign(
  String message,
  String key, {
  String hash = 'sha256',
  String keyFormat = 'text',
  String output = 'hex',
}) {
  if (key.isEmpty) {
    throw const FormatException('Enter the key / Nhập khóa');
  }
  final k = _key(key, keyFormat);
  if (k.isEmpty || k.length > maxHmacKeyBytes) {
    throw const FormatException(
      'The key must be 1–$maxHmacKeyBytes bytes / Khóa phải từ 1 đến $maxHmacKeyBytes byte',
    );
  }
  final h = switch (hash) {
    'sha256' => crypto.sha256,
    'sha512' => crypto.sha512,
    _ => throw const FormatException(
      'Hash must be sha256 or sha512 / Hàm băm phải là sha256 hoặc sha512',
    ),
  };
  final mac = crypto.Hmac(h, k).convert(utf8.encode(message));
  return switch (output) {
    'hex' => mac.toString(),
    'base64' => base64.encode(mac.bytes),
    _ => throw const FormatException(
      'Output must be hex or base64 / Kết quả phải là hex hoặc base64',
    ),
  };
}

/// The `hmac` tool's options, as JSON:
/// `{"key": "…", "hash": "sha256", "keyFormat": "text", "output": "hex"}`.
String hmacTool(String message, String options) {
  dynamic o;
  try {
    o = jsonDecode(options);
  } catch (_) {
    // Never echo the options: they hold the key.
    throw const FormatException(
      'HMAC options must be a JSON object with a key / '
      'Tùy chọn HMAC phải là JSON có khóa',
    );
  }
  if (o is! Map || o['key'] is! String) {
    throw const FormatException(
      'HMAC options must be a JSON object with a key / '
      'Tùy chọn HMAC phải là JSON có khóa',
    );
  }
  String pick(String name, String fallback) =>
      o[name] is String ? o[name] as String : fallback;
  return hmacSign(
    message,
    o['key'] as String,
    hash: pick('hash', 'sha256'),
    keyFormat: pick('keyFormat', 'text'),
    output: pick('output', 'hex'),
  );
}
