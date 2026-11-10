library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:handy_core/portable_zip.dart';
import 'package:handy_core/csv.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;
part 'src/models.dart';
part 'src/causal.dart';
part 'src/trash.dart';
part 'src/calendar.dart';
part 'src/negative.dart';
part 'src/routines.dart';
part 'src/portable.dart';
part 'src/pauses.dart';
part 'src/review.dart';
part 'src/presets.dart';
part 'src/progress.dart';
part 'src/template_catalog.dart';

typedef Json = Map<String, dynamic>;
dynamic freezeJson(dynamic value) {
  if (value is Map<String, dynamic>)
    return Map<String, dynamic>.unmodifiable(
      value.map((k, v) => MapEntry(k, freezeJson(v))),
    );
  if (value is List) return List<dynamic>.unmodifiable(value.map(freezeJson));
  if (value == null ||
      value is String ||
      value is bool ||
      value is num && value.isFinite)
    return value;
  throw const FormatException('Invalid settings value');
}

const maxValue = 1000000000000;
const maxElapsed = 366 * 86400;
String uid() {
  final r = Random.secure(), b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String text(Object? v, {int max = 4096}) {
  if (v is! String || v.length > max)
    throw const FormatException('Invalid text');
  return v;
}

int integer(Object? v, {int min = 0, int max = maxValue}) {
  if (v is! int || v < min || v > max)
    throw const FormatException('Invalid integer');
  return v;
}

List<Json> objects(Object? v) {
  if (v is! List || v.length > 200000)
    throw const FormatException('Invalid list');
  return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

int quantity(String value) {
  if (!RegExp(r'^\d{1,9}(\.\d{1,3})?$').hasMatch(value.trim()))
    throw const FormatException('Use up to three decimal places');
  final p = value.trim().split('.');
  return integer(
    int.parse(p[0]) * 1000 +
        (p.length == 1 ? 0 : int.parse(p[1].padRight(3, '0'))),
  );
}

String amount(int value) =>
    '${value ~/ 1000}${value % 1000 == 0 ? '' : '.${(value % 1000).toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '')}'}';
String timestamp(Object? value) {
  final s = text(value, max: 50);
  final match = RegExp(
    r'^\d{4}-\d\d-\d\dT(\d\d):(\d\d):(\d\d)(?:\.\d{1,6})?(Z|[+-](\d\d):(\d\d))$',
  ).firstMatch(s);
  if (match == null) throw const FormatException('Timestamp requires offset');
  final offsetHours = int.parse(match[5] ?? '0');
  final offsetMinutes = int.parse(match[6] ?? '0');
  if (int.parse(match[1]!) > 23 ||
      int.parse(match[2]!) > 59 ||
      int.parse(match[3]!) > 59 ||
      offsetHours > 14 ||
      offsetMinutes > 59 ||
      offsetHours == 14 && offsetMinutes != 0)
    throw const FormatException('Invalid timestamp clock or offset');
  date(s.substring(0, 10));
  final d = DateTime.tryParse(s);
  if (d == null) throw const FormatException('Invalid timestamp');
  return d.toUtc().toIso8601String();
}
