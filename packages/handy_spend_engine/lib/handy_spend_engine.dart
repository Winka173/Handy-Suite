library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:handy_core/portable_zip.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;
import 'package:xml/xml.dart';
part 'src/models.dart';
part 'src/planning.dart';
part 'src/portable.dart';

Object? _freeze(Object? value, [int depth = 0]) {
  if (depth > 64) throw const FormatException('Data nesting limit');
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((k, v) => MapEntry(k as String, _freeze(v, depth + 1))),
    );
  }
  if (value is List)
    return List<dynamic>.unmodifiable(value.map((v) => _freeze(v, depth + 1)));
  if (value == null || value is String || value is bool || value is int)
    return value;
  throw const FormatException('Expected JSON data');
}

Map<String, dynamic> _frozenMap(Map<String, dynamic> value) =>
    _freeze(value) as Map<String, dynamic>;

String newId() {
  final r = Random.secure(), b = List.generate(16, (_) => 0);
  for (var i = 0; i < 16; i++) {
    b[i] = r.nextInt(256);
  }
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

const scales = {
  'VND': 0,
  'JPY': 0,
  'USD': 2,
  'EUR': 2,
  'GBP': 2,
  'AUD': 2,
  'CAD': 2,
  'SGD': 2,
  'THB': 2,
  'KWD': 3,
  'BHD': 3,
};
int scale(String currency) =>
    scales[currency] ?? (throw const FormatException('Unsupported currency'));
BigInt minor(String value, String currency, {String decimal = '.'}) {
  if (value.length > 80) throw const FormatException('Amount too long');
  final text = value.trim().replaceAll(decimal, '.');
  if (!RegExp(r'^[+-]?\d+(?:\.\d+)?$').hasMatch(text))
    throw const FormatException('Invalid amount');
  final s = scale(currency),
      parts = text.replaceFirst(RegExp(r'^[+-]'), '').split('.'),
      f = parts.length > 1 ? parts[1] : '';
  if (f.length > s) throw const FormatException('Too many currency decimals');
  final n =
      BigInt.parse(parts[0]) * BigInt.from(10).pow(s) +
      BigInt.parse(f.padRight(s, '0').isEmpty ? '0' : f.padRight(s, '0'));
  if (n.toString().length > 30)
    throw const FormatException('Amount exceeds limit');
  return text.startsWith('-') ? -n : n;
}

String decimalMoney(BigInt value, String currency) {
  final s = scale(currency), d = value.abs().toString().padLeft(s + 1, '0');
  return '${value.isNegative ? '-' : ''}${s == 0 ? d : '${d.substring(0, d.length - s)}.${d.substring(d.length - s)}'}';
}

BigInt roundedRatio(BigInt n, BigInt d) {
  if (d <= BigInt.zero)
    throw const FormatException('Positive denominator required');
  final a = n.abs(),
      v = a ~/ d + ((a % d) * BigInt.two >= d ? BigInt.one : BigInt.zero);
  return n.isNegative ? -v : v;
}

BigInt convert(BigInt amount, String from, String to, String rate) {
  final m = RegExp(r'^(\d+)(?:\.(\d{1,12}))?$').firstMatch(rate);
  if (m == null || rate.length > 40)
    throw const FormatException('Explicit positive rate required');
  final f = m[2] ?? '', n = BigInt.parse('${m[1]}$f');
  if (n <= BigInt.zero) throw const FormatException('Invalid rate');
  return roundedRatio(
    amount * n * BigInt.from(10).pow(scale(to)),
    BigInt.from(10).pow(scale(from) + f.length),
  );
}

String timestamp(String value) {
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|[+-](\d{2}):(\d{2}))$',
  ).firstMatch(value);
  if (match == null)
    throw const FormatException(
      'Timestamp requires explicit time and timezone',
    );
  calendar(match[1]!);
  if (int.parse(match[2]!) > 23 ||
      int.parse(match[3]!) > 59 ||
      int.parse(match[4]!) > 59 ||
      match[7] != null &&
          (int.parse(match[7]!) > 14 ||
              int.parse(match[8]!) > 59 ||
              int.parse(match[7]!) == 14 && int.parse(match[8]!) != 0))
    throw const FormatException('Invalid timestamp fields');
  return DateTime.parse(value).toUtc().toIso8601String();
}

String day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime calendar(String text) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text))
    throw const FormatException('Use YYYY-MM-DD');
  final d = DateTime.parse('${text}T00:00:00Z');
  if (day(d) != text) throw const FormatException('Invalid date');
  return d;
}

bool _ready = false;
tz.Location location(String name) {
  if (!_ready) {
    zones.initializeTimeZones();
    _ready = true;
  }
  return tz.getLocation(name);
}

String reportDay(String utc, String zone) =>
    day(tz.TZDateTime.from(DateTime.parse(timestamp(utc)), location(zone)));
String localTimestamp(String date, String zone) {
  final d = calendar(date);
  return tz.TZDateTime(
    location(zone),
    d.year,
    d.month,
    d.day,
    12,
  ).toUtc().toIso8601String();
}

String _text(dynamic v, [int max = 8192]) {
  if (v is! String || v.length > max)
    throw const FormatException('Invalid text');
  return v;
}

BigInt _big(dynamic v) {
  final t = _text(v, 32);
  if (!RegExp(r'^-?\d{1,30}$').hasMatch(t))
    throw const FormatException('Invalid minor amount');
  return BigInt.parse(t);
}

Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);
List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) make) {
  if (v is! List || v.length > 200000)
    throw const FormatException('Invalid list');
  return v.map((e) => make(_map(e))).toList();
}
