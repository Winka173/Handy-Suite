/// UUID v4/v7 and ULID: generated from a secure random source, and read back.
library;

import 'dart:math';

enum IdKind { v4, v7, ulid }

/// Most IDs one request may make or inspect.
const maxIds = 1000;

const _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// [value] as [n] big-endian bytes. Division, not shifts, so it is exact on
/// the web too (values up to 2^53).
List<int> _bytes(int value, int n) {
  final out = List<int>.filled(n, 0);
  for (var i = n - 1; i >= 0; i--) {
    out[i] = value % 256;
    value ~/= 256;
  }
  return out;
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

String _canonical(String hex32) =>
    '${hex32.substring(0, 8)}-${hex32.substring(8, 12)}-'
    '${hex32.substring(12, 16)}-${hex32.substring(16, 20)}-'
    '${hex32.substring(20)}';

/// [count] new IDs of [kind]. v7 and ULID batches are sorted, so a batch made
/// within one millisecond is still in creation order.
List<String> generateIds(
  IdKind kind,
  int count, {
  Random? random,
  DateTime? now,
}) {
  if (count < 1 || count > maxIds) {
    throw const FormatException(
      'Make between 1 and $maxIds IDs / Tạo từ 1 đến $maxIds ID',
    );
  }
  final r = random ?? Random.secure();
  final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
  if (ms < 0 || ms >= 281474976710656) {
    throw const FormatException('Clock outside the ID range');
  }
  String one() {
    switch (kind) {
      case IdKind.v4:
        final b = List<int>.generate(16, (_) => r.nextInt(256));
        b[6] = (b[6] & 0x0f) | 0x40;
        b[8] = (b[8] & 0x3f) | 0x80;
        return _canonical(_hex(b));
      case IdKind.v7:
        final b = [
          ..._bytes(ms, 6),
          ...List.generate(10, (_) => r.nextInt(256)),
        ];
        b[6] = (b[6] & 0x0f) | 0x70;
        b[8] = (b[8] & 0x3f) | 0x80;
        return _canonical(_hex(b));
      case IdKind.ulid:
        final out = StringBuffer();
        var t = ms;
        final time = List<String>.filled(10, '0');
        for (var i = 9; i >= 0; i--) {
          time[i] = _crockford[t % 32];
          t ~/= 32;
        }
        out.writeAll(time);
        for (var i = 0; i < 16; i++) {
          out.write(_crockford[r.nextInt(32)]);
        }
        return out.toString();
    }
  }

  final ids = List<String>.generate(count, (_) => one());
  if (kind != IdKind.v4) ids.sort();
  return ids;
}

final _uuid = RegExp(
  r'^(?:urn:uuid:|\{)?([0-9a-f]{8})-?([0-9a-f]{4})-?([0-9a-f]{4})-?([0-9a-f]{4})-?([0-9a-f]{12})\}?$',
  caseSensitive: false,
);
final _ulid = RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$', caseSensitive: false);

const _versionNames = {
  1: 'Gregorian time and node',
  2: 'DCE security',
  3: 'MD5 name-based',
  4: 'random',
  5: 'SHA-1 name-based',
  6: 'reordered Gregorian time',
  7: 'Unix time-ordered',
  8: 'custom',
};

bool looksLikeId(String s) {
  final t = s.trim();
  return _uuid.hasMatch(t) || _ulid.hasMatch(t);
}

// 100-ns ticks between 1582-10-15 and 1970-01-01.
final _gregorian = BigInt.parse('122192928000000000');

/// What one UUID or ULID says about itself. Throws when it is neither.
Map<String, dynamic> inspectId(String raw) {
  final s = raw.trim();
  final u = _uuid.firstMatch(s);
  if (u != null) {
    final hex = [for (var i = 1; i <= 5; i++) u[i]!].join().toLowerCase();
    final out = <String, dynamic>{'kind': 'UUID', 'canonical': _canonical(hex)};
    if (hex == '0' * 32) return {...out, 'special': 'nil'};
    if (hex == 'f' * 32) return {...out, 'special': 'max'};
    final version = int.parse(hex[12], radix: 16);
    final v = int.parse(hex[16], radix: 16);
    final variant = v < 8
        ? 'NCS (reserved)'
        : v < 12
        ? 'RFC 9562'
        : v < 14
        ? 'Microsoft (reserved)'
        : 'future (reserved)';
    out['version'] = version;
    out['versionName'] = _versionNames[version] ?? 'unknown';
    out['variant'] = variant;
    DateTime? time;
    if (variant == 'RFC 9562') {
      if (version == 7) {
        time = DateTime.fromMillisecondsSinceEpoch(
          int.parse(hex.substring(0, 12), radix: 16),
          isUtc: true,
        );
      } else if (version == 1 || version == 6) {
        final ticks = BigInt.parse(
          version == 1
              ? '${hex.substring(13, 16)}${hex.substring(8, 12)}${hex.substring(0, 8)}'
              : '${hex.substring(0, 12)}${hex.substring(13, 16)}',
          radix: 16,
        );
        final micros = (ticks - _gregorian) ~/ BigInt.from(10);
        if (micros.abs() < BigInt.parse('8640000000000000000')) {
          time = DateTime.fromMicrosecondsSinceEpoch(
            micros.toInt(),
            isUtc: true,
          );
        }
      }
    }
    if (time != null) out['timestamp'] = time.toIso8601String();
    return out;
  }
  if (_ulid.hasMatch(s)) {
    final up = s.toUpperCase();
    if (up.codeUnitAt(0) > '7'.codeUnitAt(0)) {
      throw const FormatException(
        'ULID time overflows 48 bits / Thời gian ULID vượt 48 bit',
      );
    }
    var ms = 0;
    for (var i = 0; i < 10; i++) {
      ms = ms * 32 + _crockford.indexOf(up[i]);
    }
    return {
      'kind': 'ULID',
      'canonical': up,
      'timestamp': DateTime.fromMillisecondsSinceEpoch(
        ms,
        isUtc: true,
      ).toIso8601String(),
    };
  }
  throw const FormatException('Not a UUID or ULID / Không phải UUID hay ULID');
}

/// Each non-blank line inspected; a bad line says why instead of failing the
/// rest.
List<Map<String, dynamic>> inspectIds(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length > maxIds) {
    throw const FormatException(
      'At most $maxIds IDs at once / Tối đa $maxIds ID mỗi lần',
    );
  }
  return [
    for (final l in lines)
      () {
        try {
          return {'input': l, 'valid': true, ...inspectId(l)};
        } on FormatException catch (e) {
          return {'input': l, 'valid': false, 'error': e.message};
        }
      }(),
  ];
}

IdKind idKind(String s) => switch (s.trim().toLowerCase()) {
  '' || 'v4' || '4' => IdKind.v4,
  'v7' || '7' => IdKind.v7,
  'ulid' => IdKind.ulid,
  _ => throw const FormatException(
    'Kind must be v4, v7 or ulid / Loại phải là v4, v7 hoặc ulid',
  ),
};
