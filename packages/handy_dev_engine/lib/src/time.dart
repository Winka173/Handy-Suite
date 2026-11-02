/// Time zones, Unix timestamps and relative descriptions, without a time
/// zone database: UTC, the device's own zone, or a fixed UTC offset.
library;

/// Where wall-clock times are read: UTC, the device zone, or a fixed offset.
class ZoneChoice {
  final bool local;

  /// Offset from UTC in minutes for a fixed zone (0 for UTC).
  final int offsetMinutes;
  const ZoneChoice.utc() : local = false, offsetMinutes = 0;
  const ZoneChoice.local() : local = true, offsetMinutes = 0;
  const ZoneChoice.fixed(this.offsetMinutes) : local = false;

  /// `''`, `utc`, `z` → UTC; `local` → device zone; `+07:00`, `-0530`,
  /// `UTC+7` → a fixed offset between −12:00 and +14:00.
  static ZoneChoice parse(String text) {
    final s = text.trim().toLowerCase();
    if (s.isEmpty || s == 'utc' || s == 'z' || s == 'gmt') {
      return const ZoneChoice.utc();
    }
    if (s == 'local') return const ZoneChoice.local();
    final m = RegExp(
      r'^(?:utc|gmt)?\s*([+-])(\d{1,2})(?::?(\d{2}))?$',
    ).firstMatch(s);
    if (m != null) {
      final h = int.parse(m[2]!), min = int.parse(m[3] ?? '0');
      final total = (h * 60 + min) * (m[1] == '-' ? -1 : 1);
      if (min < 60 && total >= -12 * 60 && total <= 14 * 60) {
        return ZoneChoice.fixed(total);
      }
    }
    throw const FormatException(
      'Unknown time zone. Use UTC, local or an offset such as +07:00 / '
      'Múi giờ không hợp lệ. Dùng UTC, local hoặc độ lệch như +07:00',
    );
  }

  int offsetAt(DateTime instant) =>
      local ? instant.toLocal().timeZoneOffset.inMinutes : offsetMinutes;

  /// The wall-clock time at [instant], as a UTC DateTime used as a plain
  /// calendar value.
  DateTime wall(DateTime instant) =>
      instant.toUtc().add(Duration(minutes: offsetAt(instant)));

  /// The instant at which the wall clock in this zone shows these fields.
  DateTime instant(
    int y, [
    int mo = 1,
    int d = 1,
    int h = 0,
    int mi = 0,
    int s = 0,
    int ms = 0,
    int us = 0,
  ]) => local
      ? DateTime(y, mo, d, h, mi, s, ms, us).toUtc()
      : DateTime.utc(
          y,
          mo,
          d,
          h,
          mi,
          s,
          ms,
          us,
        ).subtract(Duration(minutes: offsetMinutes));

  /// `UTC`, `UTC+07:00`, or `local (UTC+07:00)` at [instant].
  String label(DateTime instant) {
    final o = offsetAt(instant);
    final fixed = o == 0 && !local ? 'UTC' : 'UTC${formatOffset(o)}';
    return local ? 'local ($fixed)' : fixed;
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// `+07:00`, `-05:30`, `+00:00`.
String formatOffset(int minutes) =>
    '${minutes < 0 ? '-' : '+'}${_two(minutes.abs() ~/ 60)}:${_two(minutes.abs() % 60)}';

/// ISO-8601 with the zone's offset (`Z` for UTC).
String isoInZone(DateTime instant, ZoneChoice zone) {
  final o = zone.offsetAt(instant);
  final wall = zone.wall(instant).toIso8601String();
  final base = wall.substring(0, wall.length - 1);
  return o == 0 && !zone.local ? '${base}Z' : '$base${formatOffset(o)}';
}

/// `2026-11-02 07:00:00` in the zone, seconds precision, for reading.
String wallText(DateTime instant, ZoneChoice zone) {
  final w = zone.wall(instant);
  return '${w.year.toString().padLeft(4, '0')}-${_two(w.month)}-${_two(w.day)} '
      '${_two(w.hour)}:${_two(w.minute)}:${_two(w.second)}';
}

/// "3 days ago" / "3 ngày trước", "in 2 hours" / "2 giờ nữa".
({String en, String vi}) relativeTime(DateTime instant, DateTime now) {
  final secs = instant.difference(now).inMilliseconds / 1000;
  final past = secs < 0, a = secs.abs();
  if (a < 45) return (en: 'just now', vi: 'vừa xong');
  const day = 86400.0;
  final (int n, String en, String vi) = a < 90
      ? (1, 'minute', 'phút')
      : a < 45 * 60
      ? ((a / 60).round(), 'minute', 'phút')
      : a < 90 * 60
      ? (1, 'hour', 'giờ')
      : a < 22 * 3600
      ? ((a / 3600).round(), 'hour', 'giờ')
      : a < 36 * 3600
      ? (1, 'day', 'ngày')
      : a < 26 * day
      ? ((a / day).round(), 'day', 'ngày')
      : a < 46 * day
      ? (1, 'month', 'tháng')
      : a < 320 * day
      ? ((a / (30.44 * day)).round(), 'month', 'tháng')
      : a < 548 * day
      ? (1, 'year', 'năm')
      : ((a / (365.25 * day)).round(), 'year', 'năm');
  final unit = n == 1 ? en : '${en}s';
  return past
      ? (en: '$n $unit ago', vi: '$n $vi trước')
      : (en: 'in $n $unit', vi: '$n $vi nữa');
}

/// How a timestamp was read.
enum TimeSource { seconds, milliseconds, microseconds, nanoseconds, iso, now }

class TimestampReading {
  final DateTime instant;
  final TimeSource source;
  final ZoneChoice zone;
  final DateTime now;
  const TimestampReading(this.instant, this.source, this.zone, this.now);

  int get unixSeconds => (instant.microsecondsSinceEpoch / 1000000).floor();
  int get unixMilliseconds => (instant.microsecondsSinceEpoch / 1000).floor();
  ({String en, String vi}) get relative => relativeTime(instant, now);

  Map<String, dynamic> toJson() => {
    'readAs': source.name,
    'unixSeconds': unixSeconds,
    'unixMilliseconds': unixMilliseconds,
    'utc': instant.toUtc().toIso8601String(),
    'zone': zone.label(instant),
    'inZone': isoInZone(instant, zone),
    'relativeEn': relative.en,
    'relativeVi': relative.vi,
  };
}

final _isoPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d{1,9})?)?)?\s*(Z|[+-]\d{2}(?::?\d{2})?)?$',
  caseSensitive: false,
);
final _numberPattern = RegExp(r'^(-?)(\d{1,20})(?:\.(\d{1,9}))?$');

// ±8.64e15 ms is DateTime's whole range.
final _maxMicros = BigInt.parse('8640000000000000000');

/// Reads `1730505600` (unit guessed from size), `1730505600123`,
/// `2026-11-02T07:00:00+07:00`, `2026-11-02 07:00` (wall time in [zone]) or
/// `now`. [unit] forces `s`, `ms`, `us` or `ns`.
TimestampReading readTimestamp(
  String input, {
  ZoneChoice zone = const ZoneChoice.utc(),
  String unit = '',
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final s = input.trim();
  if (s.length > 64) {
    throw const FormatException(
      'A timestamp is at most 64 characters / Mốc thời gian tối đa 64 ký tự',
    );
  }
  if (s.toLowerCase() == 'now') {
    return TimestampReading(at.toUtc(), TimeSource.now, zone, at);
  }
  final n = _numberPattern.firstMatch(s);
  if (n != null) {
    final whole = BigInt.parse(n[2]!);
    final source = switch (unit.trim().toLowerCase()) {
      's' => TimeSource.seconds,
      'ms' => TimeSource.milliseconds,
      'us' || 'µs' => TimeSource.microseconds,
      'ns' => TimeSource.nanoseconds,
      '' =>
        whole < BigInt.from(100000000000)
            ? TimeSource.seconds
            : whole < BigInt.from(100000000000000)
            ? TimeSource.milliseconds
            : whole < BigInt.parse('100000000000000000')
            ? TimeSource.microseconds
            : TimeSource.nanoseconds,
      _ => throw const FormatException(
        'Unit must be s, ms, us or ns / Đơn vị phải là s, ms, us hoặc ns',
      ),
    };
    final frac = n[3] ?? '';
    // micros = value × unit, done in integers so 19-digit values stay exact.
    final digits = BigInt.parse('${n[2]}$frac');
    final scale = BigInt.from(10).pow(frac.length);
    final (mul, div) = switch (source) {
      TimeSource.seconds => (BigInt.from(1000000), BigInt.one),
      TimeSource.milliseconds => (BigInt.from(1000), BigInt.one),
      TimeSource.microseconds => (BigInt.one, BigInt.one),
      _ => (BigInt.one, BigInt.from(1000)),
    };
    var micros = digits * mul ~/ (scale * div);
    if (n[1] == '-') micros = -micros;
    if (micros.abs() > _maxMicros) {
      throw const FormatException(
        'Outside the supported date range / Ngoài khoảng ngày hỗ trợ',
      );
    }
    final instant = DateTime.fromMicrosecondsSinceEpoch(
      micros.toInt(),
      isUtc: true,
    );
    return TimestampReading(instant, source, zone, at);
  }
  final iso = _isoPattern.firstMatch(s);
  final parsed = iso == null ? null : DateTime.tryParse(s.replaceAll(',', '.'));
  // DateTime.parse rolls 2024-13-45 over into 2025; a calendar check refuses it.
  bool real(RegExpMatch m) {
    final f = [for (var i = 1; i <= 6; i++) int.parse(m[i] ?? '0')];
    final d = DateTime.utc(f[0], f[1], f[2], f[3], f[4], f[5]);
    return d.month == f[1] &&
        d.day == f[2] &&
        f[3] < 24 &&
        f[4] < 60 &&
        f[5] < 60;
  }

  if (parsed == null || !real(iso!)) {
    throw const FormatException(
      'Not a Unix timestamp or ISO-8601 date / '
      'Không phải mốc Unix hay ngày ISO-8601',
    );
  }
  final instant = iso[7] != null
      ? parsed.toUtc()
      : zone.instant(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
  return TimestampReading(instant, TimeSource.iso, zone, at);
}

/// The `timestamp` tool's options: a zone and, optionally, a unit, in any
/// order (`+07:00 ms`, `local`, `utc s`).
({ZoneChoice zone, String unit}) timestampOptions(String options) {
  var zone = const ZoneChoice.utc(), unit = '';
  for (final t in options.trim().split(RegExp(r'\s+'))) {
    if (t.isEmpty) continue;
    if (const {'s', 'ms', 'us', 'µs', 'ns'}.contains(t.toLowerCase())) {
      unit = t;
    } else {
      zone = ZoneChoice.parse(t);
    }
  }
  return (zone: zone, unit: unit);
}
