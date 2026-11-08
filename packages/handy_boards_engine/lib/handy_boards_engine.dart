library;

import 'dart:convert';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:handy_core/portable_zip.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

part 'src/model.dart';
part 'src/commands.dart';
part 'src/planning.dart';
part 'src/portable.dart';
part 'src/extras.dart';
part 'src/remaining.dart';
part 'src/snapshot.dart';
part 'src/kanban.dart';
part 'src/covers.dart';
part 'src/templates.dart';
part 'src/template_catalog.dart';
part 'src/sync.dart';
part 'src/time_nav.dart';
part 'src/card_templates.dart';
part 'src/custom_fields.dart';

typedef Json = Map<String, dynamic>;

const kinds = [
  'workspaces',
  'boards',
  'categories',
  'statuses',
  'tasks',
  'checklist',
  'tags',
  'attachments',
  'dependencies',
  'reminders',
  'recurrence',
  'occurrences',
  'sessions',
  'events',
  'views',
  'fields',
  'rules',
  'executions',
  'templates',
  'subjects',
  'classes',
  'grades',
];

String newId() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

dynamic _freeze(dynamic v) => switch (v) {
  Map m => Map<String, dynamic>.unmodifiable(
    m.map((k, v) => MapEntry(k as String, _freeze(v))),
  ),
  List l => List<dynamic>.unmodifiable(l.map(_freeze)),
  null || String() || bool() || num() => v,
  _ => throw const FormatException('Unsupported value'),
};
Json object(dynamic v) {
  if (v is! Map || v.keys.any((k) => k is! String))
    throw const FormatException('Object required');
  return Map<String, dynamic>.from(v);
}

String text(dynamic v, {int max = 1000, bool empty = true}) {
  if (v is! String ||
      v.length > max ||
      (!empty && v.trim().isEmpty) ||
      v.contains('\u0000')) {
    throw const FormatException('Invalid text');
  }
  return v;
}

String day(String v) {
  if (!RegExp(r'^\d{4}-\d\d-\d\d$').hasMatch(v))
    throw const FormatException('Invalid date');
  final d = DateTime.tryParse(v);
  if (d == null ||
      d.year < 1900 ||
      d.year > 2200 ||
      d.toIso8601String().substring(0, 10) != v) {
    throw const FormatException('Invalid date');
  }
  return v;
}

DateTime calendarDate(String value) =>
    DateTime.parse('${day(value)}T00:00:00Z');

bool _zonesReady = false;
tz.Location zone(String v) {
  if (v == 'UTC') return tz.UTC;
  if (!_zonesReady) {
    tzdata.initializeTimeZones();
    _zonesReady = true;
  }
  return tz.getLocation(v);
}

String localDay(DateTime at, String name) =>
    tz.TZDateTime.from(at, zone(name)).toIso8601String().substring(0, 10);

DateTime wallTime(String date, String clock, String name, {bool? lateFold}) {
  day(date);
  if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(clock))
    throw const FormatException('Invalid time');
  final d = DateTime.parse('${date}T$clock:00Z'), loc = zone(name);
  final offsets = loc.zones.map((z) => z.offset).toSet();
  final candidates = <DateTime>[];
  for (final offset in offsets) {
    final c = d.subtract(offset);
    final local = tz.TZDateTime.from(c, loc);
    if (local.year == d.year &&
        local.month == d.month &&
        local.day == d.day &&
        local.hour == d.hour &&
        local.minute == d.minute)
      candidates.add(c);
  }
  candidates.sort();
  if (candidates.isEmpty)
    throw const FormatException('Time falls in a DST gap');
  if (candidates.length > 1 && lateFold == null)
    throw const FormatException('Ambiguous time: choose earlier or later');
  return lateFold == true ? candidates.last : candidates.first;
}

String foldSearch(String s) {
  const from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final lower = s.toLowerCase();
  return lower.split('').map((c) {
    final i = from.indexOf(c);
    return i < 0 ? c : to[i];
  }).join();
}
