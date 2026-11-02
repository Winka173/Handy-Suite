part of '../handy_trip_engine.dart';

String newId() {
  final r = Random.secure(), b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

String string(Object? v, {int max = 10000, bool required = false}) {
  if (v is! String || v.length > max || required && v.trim().isEmpty)
    throw const FormatException('Invalid text');
  return v;
}

String id(Object? v) {
  final s = string(v, max: 100, required: true);
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(s))
    throw const FormatException('Invalid ID');
  return s;
}

String boundedLabel(String value, int limit) {
  final out = StringBuffer();
  var units = 0;
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    if (units + char.length > limit) break;
    out.write(char);
    units += char.length;
  }
  return out.toString();
}

int integer(Object? v, {int min = 0, int max = 1000000000}) {
  if (v is! int || v < min || v > max)
    throw const FormatException('Invalid integer');
  return v;
}

List<String> strings(Object? v, {int max = 1000}) {
  if (v is! List || v.length > max) throw const FormatException('Invalid list');
  return List.unmodifiable(v.map((x) => string(x, max: 500)));
}

Json object(Object? v) {
  if (v is! Map) throw const FormatException('Expected object');
  return Map<String, dynamic>.from(v);
}

dynamic freeze(dynamic v) {
  if (v is Map)
    return Map<String, dynamic>.unmodifiable(
      v.map((k, v) => MapEntry(string(k), freeze(v))),
    );
  if (v is List) return List<dynamic>.unmodifiable(v.map(freeze));
  if (v == null || v is String || v is bool || v is num && v.isFinite) return v;
  throw const FormatException('Invalid JSON');
}

DateTime date(String s) {
  if (!RegExp(r'^\d{4}-\d\d-\d\d$').hasMatch(s))
    throw const FormatException('Expected YYYY-MM-DD');
  final d = DateTime.tryParse(s);
  if (d == null || d.year < 1900 || d.year > 2200 || day(d) != s)
    throw const FormatException('Invalid calendar date');
  return DateTime.utc(d.year, d.month, d.day);
}

String day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String addDays(String d, int n) => day(date(d).add(Duration(days: n)));
String instant(Object? v) {
  final s = string(v, max: 40),
      m = RegExp(
        r'^\d{4}-\d\d-\d\dT(\d\d):(\d\d):(\d\d)(?:\.\d{1,6})?(Z|[+-](\d\d):(\d\d))$',
      ).firstMatch(s);
  if (m == null ||
      int.parse(m[1]!) > 23 ||
      int.parse(m[2]!) > 59 ||
      int.parse(m[3]!) > 59 ||
      int.parse(m[5] ?? '0') > 14 ||
      int.parse(m[6] ?? '0') > 59 ||
      m[5] == '14' && m[6] != '00')
    throw const FormatException('Invalid instant');
  date(s.substring(0, 10));
  return DateTime.parse(s).toUtc().toIso8601String();
}

bool _zonesReady = false;
tz.Location location(String zone) {
  if (!_zonesReady) {
    zones.initializeTimeZones();
    _zonesReady = true;
  }
  if (zone == 'UTC' || zone == 'Etc/UTC') return tz.UTC;
  try {
    return tz.getLocation(zone);
  } catch (_) {
    throw const FormatException('Unknown timezone');
  }
}

tz.TZDateTime localTime(DateTime d, String zone) =>
    tz.TZDateTime.from(d, location(zone));
String localClock(DateTime d, String zone) {
  final t = localTime(d, zone);
  return "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
}

bool lateFoldAt(String? at, String zone) {
  if (at == null) return false;
  final value = DateTime.parse(at);
  final first = localInstant(
    localDay(value, zone),
    localClock(value, zone),
    zone,
    lateFold: false,
  );
  return value.toUtc().difference(first).inMinutes >= 30;
}

/// An unrelated edit must not round off original seconds or switch DST folds.
DateTime editedInstant(
  String? old,
  String? oldZone,
  String on,
  String clock,
  String zone, {
  bool lateFold = false,
}) {
  if (old != null &&
      oldZone == zone &&
      localDay(DateTime.parse(old), zone) == on &&
      localClock(DateTime.parse(old), zone) == clock &&
      lateFoldAt(old, zone) == lateFold)
    return DateTime.parse(old).toUtc();
  return localInstant(on, clock, zone, lateFold: lateFold);
}

String localDay(DateTime d, String zone) =>
    day(tz.TZDateTime.from(d, location(zone)));
int minute(String s) {
  if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s))
    throw const FormatException('Expected HH:mm');
  return int.parse(s.substring(0, 2)) * 60 + int.parse(s.substring(3));
}

DateTime localInstant(String d, String time, String zone, {bool? lateFold}) {
  final a = date(d), n = minute(time), loc = location(zone);
  final t = tz.TZDateTime(loc, a.year, a.month, a.day, n ~/ 60, n % 60);
  if (day(t) != d || t.hour * 60 + t.minute != n)
    throw const FormatException('Time does not exist (DST)');
  final alternatives = <DateTime>{t.toUtc()};
  for (final offset in [-120, -60, 60, 120]) {
    final other = tz.TZDateTime.from(t.add(Duration(minutes: offset)), loc);
    if (day(other) == d && other.hour * 60 + other.minute == n)
      alternatives.add(other.toUtc());
  }
  if (alternatives.length > 1 && lateFold == null)
    throw const FormatException('Ambiguous DST time: select earlier/later');
  final sorted = alternatives.toList()..sort();
  return lateFold == true ? sorted.last : sorted.first;
}

const currencyScales = {
  'VND': 0,
  'JPY': 0,
  'KRW': 0,
  'USD': 2,
  'EUR': 2,
  'GBP': 2,
  'AUD': 2,
  'CAD': 2,
  'SGD': 2,
  'THB': 2,
  'CHF': 2,
  'CNY': 2,
  'INR': 2,
  'MYR': 2,
  'IDR': 2,
  'KWD': 3,
  'BHD': 3,
};
int currencyScale(String c) =>
    currencyScales[c] ??
    (throw const FormatException('Unsupported currency; no assumed scale'));
BigInt money(String value, String currency) {
  final scale = currencyScale(currency);
  if (!RegExp(r'^\d{1,18}(?:\.\d{1,3})?$').hasMatch(value))
    throw const FormatException(
      'Use a non-negative exact amount, decimal point, no grouping',
    );
  final p = value.split('.');
  if (p.length == 2 && p[1].length > scale)
    throw const FormatException('Too many decimal places');
  return BigInt.parse(p[0]) * BigInt.from(10).pow(scale) +
      (p.length == 1 ? BigInt.zero : BigInt.parse(p[1].padRight(scale, '0')));
}

String amount(BigInt minor, String currency) {
  final scale = currencyScale(currency),
      sign = minor.isNegative ? '-' : '',
      s = minor.abs().toString().padLeft(scale + 1, '0');
  return '$sign${scale == 0 ? s : '${s.substring(0, s.length - scale)}.${s.substring(s.length - scale)}'}';
}

BigInt minorValue(Object? v) {
  final s = string(v, max: 30);
  if (!RegExp(r'^\d{1,24}$').hasMatch(s))
    throw const FormatException('Invalid minor units');
  return BigInt.parse(s);
}

String? safeUrl(Object? v) {
  if (v == null || v == '') return null;
  final s = string(v, max: 4096), u = Uri.tryParse(s);
  if (u == null ||
      !['https', 'http'].contains(u.scheme) ||
      u.host.isEmpty ||
      u.userInfo.isNotEmpty)
    throw const FormatException('Only HTTP(S) links without credentials');
  return s;
}

class Geo {
  final double lat, lon;
  Geo(num latitude, num longitude)
    : lat = latitude.toDouble(),
      lon = longitude.toDouble() {
    if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180)
      throw const FormatException('Invalid coordinate');
  }
  Json toJson() => {'lat': lat, 'lon': lon};
  factory Geo.fromJson(Json j) => Geo(j['lat'] as num, j['lon'] as num);
}

abstract class Entity {
  final Json data;
  Entity(Json j) : data = freeze(j) as Json {
    id(j['id']);
  }
  String get key => data['id'] as String;
  Json toJson() => Map.of(data);
  String text(String k, {String fallback = ''}) => string(data[k] ?? fallback);
  String? ref(String k) => data[k] == null ? null : id(data[k]);
  List<String> list(String k) => strings(data[k] ?? []);
}
