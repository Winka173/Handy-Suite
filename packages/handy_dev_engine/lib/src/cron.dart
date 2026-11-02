/// Cron expressions: five fields (minute hour day month weekday), an optional
/// leading seconds field, names and `@daily`-style macros. Explained in
/// English and Vietnamese, with the next run times in a chosen zone.
library;

import 'time.dart';

class _Unit {
  final String en, vi, enPlural;
  final int min, max;
  const _Unit(this.en, this.vi, this.enPlural, this.min, this.max);
}

const _second = _Unit('second', 'giây', 'seconds', 0, 59);
const _minute = _Unit('minute', 'phút', 'minutes', 0, 59);
const _hour = _Unit('hour', 'giờ', 'hours', 0, 23);
const _dom = _Unit('day of month', 'ngày trong tháng', 'days', 1, 31);
const _month = _Unit('month', 'tháng', 'months', 1, 12);
const _dow = _Unit('day of week', 'thứ', 'days of the week', 0, 7);

const _fieldNames = {
  _second: ('Second', 'Giây'),
  _minute: ('Minute', 'Phút'),
  _hour: ('Hour', 'Giờ'),
  _dom: ('Day of month', 'Ngày trong tháng'),
  _month: ('Month', 'Tháng'),
  _dow: ('Day of week', 'Thứ'),
};

const _monthNames = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];
const _dayNames = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
const _monthsEn = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _daysEn = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', //
  'Saturday',
];
const _daysVi = [
  'Chủ nhật', 'thứ Hai', 'thứ Ba', 'thứ Tư', 'thứ Năm', 'thứ Sáu', //
  'thứ Bảy',
];

const macros = {
  '@yearly': '0 0 1 1 *',
  '@annually': '0 0 1 1 *',
  '@monthly': '0 0 1 * *',
  '@weekly': '0 0 * * 0',
  '@daily': '0 0 * * *',
  '@midnight': '0 0 * * *',
  '@hourly': '0 * * * *',
};

/// One comma-separated part of a field: `*`, `5`, `1-5`, `*/15`, `10-40/5`.
class _Term {
  final int start, end, step;
  final bool any, range;
  const _Term(
    this.start,
    this.end,
    this.step, {
    this.any = false,
    this.range = false,
  });
}

class CronField {
  final _Unit _unit;
  final String raw;
  final List<_Term> _terms;
  final Set<int> values;
  CronField._(this._unit, this.raw, this._terms, this.values);

  /// `*` or `?`: no restriction.
  bool get any =>
      _terms.length == 1 && _terms.single.any && _terms.single.step == 1;
  bool has(int v) => values.contains(v);
  String get nameEn => _fieldNames[_unit]!.$1;
  String get nameVi => _fieldNames[_unit]!.$2;
  int? get single =>
      _terms.length == 1 &&
          !_terms.single.any &&
          !_terms.single.range &&
          _terms.single.step == 1
      ? _terms.single.start
      : null;

  /// Only plain values (`0,15,30`), no ranges or steps.
  List<int>? get plainValues =>
      _terms.every((t) => !t.any && !t.range && t.step == 1)
      ? [for (final t in _terms) t.start]
      : null;
}

FormatException _err(_Unit u, String en, String vi) =>
    FormatException('${_fieldNames[u]!.$1}: $en / ${_fieldNames[u]!.$2}: $vi');

int _value(_Unit u, String s) {
  final t = s.toUpperCase();
  if (u == _month && _monthNames.contains(t)) return _monthNames.indexOf(t) + 1;
  if (u == _dow && _dayNames.contains(t)) return _dayNames.indexOf(t);
  final n = RegExp(r'^\d{1,2}$').hasMatch(t) ? int.parse(t) : null;
  if (n == null) {
    throw _err(
      u,
      '"$s" is not a number or a name',
      '"$s" không phải số hay tên',
    );
  }
  if (n < u.min || n > u.max) {
    throw _err(
      u,
      '$n is outside ${u.min}–${u.max}',
      '$n nằm ngoài ${u.min}–${u.max}',
    );
  }
  return n;
}

CronField _field(_Unit u, String raw) {
  if (raw.length > 200) throw _err(u, 'too long', 'quá dài');
  final terms = <_Term>[];
  final values = <int>{};
  for (final part in raw.split(',')) {
    if (part.isEmpty)
      throw _err(u, 'empty list item', 'mục trống trong danh sách');
    final slash = part.split('/');
    if (slash.length > 2)
      throw _err(u, 'more than one "/"', 'có hơn một dấu "/"');
    var step = 1;
    if (slash.length == 2) {
      if (!RegExp(r'^\d{1,2}$').hasMatch(slash[1])) {
        throw _err(
          u,
          'step "${slash[1]}" is not a number',
          'bước "${slash[1]}" không phải số',
        );
      }
      step = int.parse(slash[1]);
      if (step < 1 || step > u.max - u.min + 1) {
        throw _err(
          u,
          'step $step is out of range',
          'bước $step ngoài khoảng cho phép',
        );
      }
    }
    final base = slash[0];
    late int start, end;
    var any = false, range = false;
    if (base == '*' || base == '?') {
      if (base == '?' && u != _dom && u != _dow) {
        throw _err(
          u,
          '"?" only fits day fields',
          '"?" chỉ dùng cho trường ngày',
        );
      }
      any = true;
      start = u.min;
      end = u == _dow ? 6 : u.max;
    } else if (base.contains('-')) {
      final ab = base.split('-');
      if (ab.length != 2)
        throw _err(u, '"$base" is not a range', '"$base" không phải khoảng');
      start = _value(u, ab[0]);
      end = _value(u, ab[1]);
      if (start > end) {
        throw _err(u, 'range $base runs backwards', 'khoảng $base bị ngược');
      }
      range = true;
    } else {
      start = _value(u, base);
      end = slash.length == 2 ? (u == _dow ? 6 : u.max) : start;
      range = slash.length == 2;
    }
    terms.add(_Term(start, end, step, any: any, range: range));
    for (var v = start; v <= end; v += step) {
      values.add(u == _dow ? v % 7 : v);
    }
  }
  return CronField._(u, raw, terms, values);
}

class CronSchedule {
  final String expression;
  final CronField? second;
  final CronField minute, hour, dayOfMonth, month, dayOfWeek;
  CronSchedule._(
    this.expression,
    this.second,
    this.minute,
    this.hour,
    this.dayOfMonth,
    this.month,
    this.dayOfWeek,
  );

  List<CronField> get fields => [
    ?second,
    minute,
    hour,
    dayOfMonth,
    month,
    dayOfWeek,
  ];

  bool _day(DateTime w) {
    final dom = dayOfMonth.has(w.day), dow = dayOfWeek.has(w.weekday % 7);
    if (dayOfMonth.any && dayOfWeek.any) return true;
    if (dayOfMonth.any) return dow;
    if (dayOfWeek.any) return dom;
    // Both restricted: classic cron runs when either matches.
    return dom || dow;
  }

  /// Up to [count] runs after [from], read on the wall clock of [zone].
  /// Searches eight years ahead; an impossible date gives no runs.
  List<DateTime> next(int count, ZoneChoice zone, {DateTime? from}) {
    final start = from ?? DateTime.now();
    final w0 = zone.wall(start);
    var t = second == null
        ? DateTime.utc(w0.year, w0.month, w0.day, w0.hour, w0.minute + 1)
        : DateTime.utc(
            w0.year,
            w0.month,
            w0.day,
            w0.hour,
            w0.minute,
            w0.second + 1,
          );
    final stop = w0.year + 8;
    final out = <DateTime>[];
    while (out.length < count && t.year <= stop) {
      if (!month.has(t.month)) {
        t = DateTime.utc(t.year, t.month + 1);
      } else if (!_day(t)) {
        t = DateTime.utc(t.year, t.month, t.day + 1);
      } else if (!hour.has(t.hour)) {
        t = DateTime.utc(t.year, t.month, t.day, t.hour + 1);
      } else if (!minute.has(t.minute)) {
        t = DateTime.utc(t.year, t.month, t.day, t.hour, t.minute + 1);
      } else if (second != null && !second!.has(t.second)) {
        t = DateTime.utc(
          t.year,
          t.month,
          t.day,
          t.hour,
          t.minute,
          t.second + 1,
        );
      } else {
        final at = zone.instant(
          t.year,
          t.month,
          t.day,
          t.hour,
          t.minute,
          t.second,
        );
        // A wall time skipped or repeated by a daylight-saving change in the
        // device zone runs once, in order.
        if (at.isAfter(start) && (out.isEmpty || at.isAfter(out.last))) {
          out.add(at);
        }
        t = second == null
            ? DateTime.utc(t.year, t.month, t.day, t.hour, t.minute + 1)
            : DateTime.utc(
                t.year,
                t.month,
                t.day,
                t.hour,
                t.minute,
                t.second + 1,
              );
      }
    }
    return out;
  }

  String describe({bool vi = false}) => _describe(this, vi);
}

/// Parses five fields, six with a leading seconds field, or a macro.
CronSchedule parseCron(String input) {
  final s = input.trim();
  if (s.length > 500) {
    throw const FormatException('Cron line too long / Dòng cron quá dài');
  }
  if (s.startsWith('@')) {
    if (s.toLowerCase() == '@reboot') {
      throw const FormatException(
        '@reboot runs at startup, not on a schedule / '
        '@reboot chạy khi khởi động, không theo lịch',
      );
    }
    final m = macros[s.toLowerCase()];
    if (m == null) {
      throw FormatException(
        'Unknown macro $s; use ${macros.keys.join(', ')} / '
        'Không có macro $s',
      );
    }
    final p = parseCron(m);
    return CronSchedule._(
      s,
      null,
      p.minute,
      p.hour,
      p.dayOfMonth,
      p.month,
      p.dayOfWeek,
    );
  }
  final f = s.split(RegExp(r'\s+'));
  if (f.length != 5 && f.length != 6) {
    throw FormatException(
      'Expected 5 fields (minute hour day month weekday) or 6 with seconds; '
      'found ${f.length} / Cần 5 trường (phút giờ ngày tháng thứ) hoặc 6 '
      'khi có giây; đang có ${f.length}',
    );
  }
  final o = f.length - 5;
  return CronSchedule._(
    s,
    o == 1 ? _field(_second, f[0]) : null,
    _field(_minute, f[o]),
    _field(_hour, f[o + 1]),
    _field(_dom, f[o + 2]),
    _field(_month, f[o + 3]),
    _field(_dow, f[o + 4]),
  );
}

String _two(int n) => n.toString().padLeft(2, '0');

String _list(List<String> items, bool vi) {
  if (items.length == 1) return items.single;
  return '${items.sublist(0, items.length - 1).join(', ')} ${vi ? 'và' : 'and'} ${items.last}';
}

String _name(_Unit u, int v, bool vi) => u == _month
    ? (vi ? 'tháng $v' : _monthsEn[v - 1])
    : u == _dow
    ? (vi ? _daysVi[v % 7] : _daysEn[v % 7])
    : '$v';

/// One field in words, e.g. "every 15 minutes", "minutes 0 and 30",
/// "hours 9 through 17".
String _phrase(CronField f, bool vi) {
  final u = f._unit;
  final named = u == _month || u == _dow;
  final unitEn = u == _dom ? 'day' : u.en;
  final unitVi = u == _dom ? 'ngày' : u.vi;
  if (named) {
    // Names read best as a list, or as one range.
    final t = f._terms;
    if (t.length == 1 && t.single.range && t.single.step == 1) {
      return vi
          ? '${_name(u, t.single.start, vi)} đến ${_name(u, t.single.end, vi)}'
          : '${_name(u, t.single.start, vi)} through ${_name(u, t.single.end, vi)}';
    }
    final vs = f.values.toList()..sort();
    if (u == _dow && vs.first == 0) vs.add(vs.removeAt(0));
    return _list([for (final v in vs) _name(u, v, vi)], vi);
  }
  final parts = <String>[];
  final plain = <int>[];
  for (final t in f._terms) {
    if (!t.any && !t.range && t.step == 1) {
      plain.add(t.start);
      continue;
    }
    final every = vi
        ? (t.step == 1 ? 'mỗi $unitVi' : 'cứ ${t.step} $unitVi')
        : (t.step == 1
              ? 'every $unitEn'
              : 'every ${t.step} ${u == _dom ? 'days' : u.enPlural}');
    if (t.any) {
      parts.add(every);
    } else if (t.step == 1) {
      parts.add(
        vi
            ? '$unitVi ${t.start} đến ${t.end}'
            : '${u == _dom ? 'days' : u.enPlural} ${t.start} through ${t.end}',
      );
    } else {
      parts.add(
        vi
            ? '$every từ ${t.start} đến ${t.end}'
            : '$every from ${t.start} through ${t.end}',
      );
    }
  }
  if (plain.isNotEmpty) {
    final items = _list([for (final v in plain) '$v'], vi);
    parts.insert(
      0,
      vi
          ? '$unitVi $items'
          : '${plain.length == 1 ? unitEn : (u == _dom ? 'days' : u.enPlural)} $items',
    );
  }
  return _list(parts, vi);
}

String _describe(CronSchedule c, bool vi) {
  final out = <String>[];
  final sec = c.second;
  final secPlain = sec == null ? [0] : sec.plainValues;
  final mins = c.minute.plainValues, hours = c.hour.plainValues;
  var fixedTimes = false;
  if (secPlain != null &&
      secPlain.length == 1 &&
      mins != null &&
      mins.length == 1 &&
      hours != null &&
      hours.length <= 8) {
    // Clock times: "At 09:00 and 17:30".
    final s = secPlain.single;
    final times = [
      for (final h in hours)
        '${_two(h)}:${_two(mins.single)}${s == 0 ? '' : ':${_two(s)}'}',
    ];
    out.add('${vi ? 'Lúc' : 'At'} ${_list(times, vi)}');
    fixedTimes = true;
  } else {
    final timeParts = <String>[];
    if (sec != null && !(sec.single == 0)) {
      timeParts.add(
        sec.any ? (vi ? 'mỗi giây' : 'every second') : _at(sec, vi),
      );
    }
    if (c.minute.any) {
      if (sec == null || sec.single == 0) {
        timeParts.add(vi ? 'mỗi phút' : 'every minute');
      }
    } else {
      final m = _at(c.minute, vi);
      timeParts.add(
        c.hour.any && c.minute.plainValues != null
            ? (vi ? '$m mỗi giờ' : '$m of every hour')
            : m,
      );
    }
    if (!c.hour.any) {
      final h = _phrase(c.hour, vi);
      timeParts.add(
        c.hour._terms.first.any ? h : (vi ? 'trong $h' : 'past $h'),
      );
    }
    out.add(timeParts.join(', '));
  }
  final dom = c.dayOfMonth, dow = c.dayOfWeek;
  if (!dom.any && !dow.any) {
    out.add(
      vi
          ? '${_phrase(dom, vi)} trong tháng hoặc vào ${_phrase(dow, vi)}'
          : 'on ${_phrase(dom, vi)} of the month or on ${_phrase(dow, vi)}',
    );
  } else if (!dom.any) {
    out.add(
      vi
          ? '${_phrase(dom, vi)} trong tháng'
          : 'on ${_phrase(dom, vi)} of the month',
    );
  } else if (!dow.any) {
    out.add(vi ? 'vào ${_phrase(dow, vi)}' : 'on ${_phrase(dow, vi)}');
  } else if (fixedTimes && c.month.any) {
    out.add(vi ? 'mỗi ngày' : 'every day');
  }
  if (!c.month.any) {
    out.add(vi ? 'vào ${_phrase(c.month, vi)}' : 'in ${_phrase(c.month, vi)}');
  }
  final text = out.join(', ');
  return text[0].toUpperCase() + text.substring(1);
}

/// "at minute 30", "every 15 minutes", "at minutes 0 and 30".
String _at(CronField f, bool vi) {
  final p = _phrase(f, vi);
  final plain = f.plainValues != null;
  return plain ? (vi ? 'vào $p' : 'at $p') : p;
}

/// The `cron` tool's options: a zone and a count in any order (`UTC 5`,
/// `+07:00`, `local 10`).
({ZoneChoice zone, int count}) cronOptions(String options) {
  var zone = const ZoneChoice.utc(), count = 5;
  for (final t in options.trim().split(RegExp(r'\s+'))) {
    if (t.isEmpty) continue;
    if (RegExp(r'^\d{1,3}$').hasMatch(t)) {
      count = int.parse(t);
      if (count < 1 || count > 100) {
        throw const FormatException(
          'Ask for 1 to 100 run times / Chọn từ 1 đến 100 lần chạy',
        );
      }
    } else {
      zone = ZoneChoice.parse(t);
    }
  }
  return (zone: zone, count: count);
}

Map<String, dynamic> cronReport(
  CronSchedule c,
  ZoneChoice zone,
  int count, {
  DateTime? from,
}) {
  final runs = c.next(count, zone, from: from);
  return {
    'expression': c.expression,
    'fields': {for (final f in c.fields) f.nameEn: f.raw},
    'en': c.describe(),
    'vi': c.describe(vi: true),
    'zone': zone.label(from ?? DateTime.now()),
    'next': [for (final r in runs) isoInZone(r, zone)],
  };
}
