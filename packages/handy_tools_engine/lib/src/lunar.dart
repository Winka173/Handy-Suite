part of '../handy_tools_engine.dart';

// Vietnamese lunar calendar after Hồ Ngọc Đức's published algorithm
// ("Âm lịch Việt Nam", https://www.informatik.uni-leipzig.de/~duc/amlich/),
// at UTC+7. Astronomical terms are Meeus's low-precision series, as in the
// original; results are checked against known Tết and leap-month dates.

const _lunarZone = 7.0;
const lunarMinYear = 1900, lunarMaxYear = 2100;

int _floor(double v) => v.floor();

int _jdFromDate(int dd, int mm, int yy) {
  final a = (14 - mm) ~/ 12, y = yy + 4800 - a, m = mm + 12 * a - 3;
  var jd =
      dd + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
  if (jd < 2299161) jd = dd + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - 32083;
  return jd;
}

(int, int, int) _jdToDate(int jd) {
  int b, c;
  if (jd > 2299160) {
    final a = jd + 32044;
    b = (4 * a + 3) ~/ 146097;
    c = a - (b * 146097) ~/ 4;
  } else {
    b = 0;
    c = jd + 32082;
  }
  final d = (4 * c + 3) ~/ 1461, e = c - (1461 * d) ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  return (
    e - (153 * m + 2) ~/ 5 + 1,
    m + 3 - 12 * (m ~/ 10),
    b * 100 + d - 4800 + m ~/ 10,
  );
}

double _newMoon(int k) {
  final t = k / 1236.85, t2 = t * t, t3 = t2 * t, dr = math.pi / 180;
  var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
  jd1 += 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
  final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
  final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
  final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
  var c1 =
      (0.1734 - 0.000393 * t) * math.sin(m * dr) +
      0.0021 * math.sin(2 * dr * m);
  c1 = c1 - 0.4068 * math.sin(mpr * dr) + 0.0161 * math.sin(dr * 2 * mpr);
  c1 = c1 - 0.0004 * math.sin(dr * 3 * mpr);
  c1 = c1 + 0.0104 * math.sin(dr * 2 * f) - 0.0051 * math.sin(dr * (m + mpr));
  c1 =
      c1 -
      0.0074 * math.sin(dr * (m - mpr)) +
      0.0004 * math.sin(dr * (2 * f + m));
  c1 =
      c1 -
      0.0004 * math.sin(dr * (2 * f - m)) -
      0.0006 * math.sin(dr * (2 * f + mpr));
  c1 =
      c1 +
      0.0010 * math.sin(dr * (2 * f - mpr)) +
      0.0005 * math.sin(dr * (2 * mpr + m));
  final deltaT = t < -11
      ? 0.001 +
            0.000839 * t +
            0.0002261 * t2 -
            0.00000845 * t3 -
            0.000000081 * t * t3
      : -0.000278 + 0.000265 * t + 0.000262 * t2;
  return jd1 + c1 - deltaT;
}

/// The sun's ecliptic longitude in radians, 0 ≤ L < 2π.
double _sunLongitude(double jdn) {
  final t = (jdn - 2451545.0) / 36525, t2 = t * t, dr = math.pi / 180;
  final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
  final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
  var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m);
  dl +=
      (0.019993 - 0.000101 * t) * math.sin(dr * 2 * m) +
      0.000290 * math.sin(dr * 3 * m);
  var l = (l0 + dl) * dr;
  l = l - math.pi * 2 * _floor(l / (math.pi * 2));
  return l;
}

/// Which of the 12 major-term sectors (30°) the sun is in at the start of
/// [dayNumber] local time.
int _sunSector(int dayNumber) =>
    _floor(_sunLongitude(dayNumber - 0.5 - _lunarZone / 24) / math.pi * 6);

int _newMoonDay(int k) => _floor(_newMoon(k) + 0.5 + _lunarZone / 24);

int _lunarMonth11(int yy) {
  final off = _jdFromDate(31, 12, yy) - 2415021;
  final k = _floor(off / 29.530588853);
  var nm = _newMoonDay(k);
  if (_sunSector(nm) >= 9) nm = _newMoonDay(k - 1);
  return nm;
}

int _leapMonthOffset(int a11) {
  final k = _floor((a11 - 2415021.076998695) / 29.530588853 + 0.5);
  var i = 1, arc = _sunSector(_newMoonDay(k + i)), last = 0;
  do {
    last = arc;
    i++;
    arc = _sunSector(_newMoonDay(k + i));
  } while (arc != last && i < 14);
  return i - 1;
}

const _can = [
  'Giáp',
  'Ất',
  'Bính',
  'Đinh',
  'Mậu',
  'Kỷ',
  'Canh',
  'Tân',
  'Nhâm',
  'Quý',
];
const _chi = [
  'Tý',
  'Sửu',
  'Dần',
  'Mão',
  'Thìn',
  'Tỵ',
  'Ngọ',
  'Mùi',
  'Thân',
  'Dậu',
  'Tuất',
  'Hợi',
];

/// The 24 solar terms from the March equinox, 15° each.
const solarTerms = [
  'Xuân phân',
  'Thanh minh',
  'Cốc vũ',
  'Lập hạ',
  'Tiểu mãn',
  'Mang chủng',
  'Hạ chí',
  'Tiểu thử',
  'Đại thử',
  'Lập thu',
  'Xử thử',
  'Bạch lộ',
  'Thu phân',
  'Hàn lộ',
  'Sương giáng',
  'Lập đông',
  'Tiểu tuyết',
  'Đại tuyết',
  'Đông chí',
  'Tiểu hàn',
  'Đại hàn',
  'Lập xuân',
  'Vũ thủy',
  'Kinh trập',
];

/// The term in force at the end of [jd] (local midnight that closes it).
int _termIndex(int jd) =>
    _floor(_sunLongitude(jd + 1 - 0.5 - _lunarZone / 24) / math.pi * 12);

class LunarDate {
  final int day, month, year;
  final bool leap;

  /// Julian day number of the same day.
  final int jd;
  const LunarDate(this.day, this.month, this.year, this.leap, this.jd);

  /// Solar date as `YYYY-MM-DD`.
  String get solar {
    final (d, m, y) = _jdToDate(jd);
    return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  }

  String get yearName => '${_can[(year + 6) % 10]} ${_chi[(year + 8) % 12]}';

  /// A leap month shares the can-chi of the month it repeats.
  String get monthName =>
      '${_can[(year * 12 + month + 3) % 10]} ${_chi[(month + 1) % 12]}';
  String get dayName => '${_can[(jd + 9) % 10]} ${_chi[(jd + 1) % 12]}';

  /// The solar term in force on this day, and whether it begins today.
  String get term => solarTerms[_termIndex(jd)];
  bool get termStarts => _termIndex(jd) != _termIndex(jd - 1);

  /// Days in this lunar month (29 or 30).
  int get monthLength {
    final start = jd - day + 1;
    final k = _floor((start - 2415021.076998695) / 29.530588853 + 0.5);
    for (final candidate in [k, k + 1, k + 2]) {
      final next = _newMoonDay(candidate);
      if (next > start) return next - start;
    }
    return 30;
  }
}

void _lunarRange(int year) {
  if (year < lunarMinYear || year > lunarMaxYear) {
    throw const FormatException('Years 1900–2100 only');
  }
}

/// Solar `YYYY-MM-DD` → Vietnamese lunar date.
LunarDate solarToLunar(String date) {
  final day = _day(date);
  _lunarRange(day.year);
  final dayNumber = _jdFromDate(day.day, day.month, day.year);
  final k = _floor((dayNumber - 2415021.076998695) / 29.530588853);
  var monthStart = _newMoonDay(k + 1);
  if (monthStart > dayNumber) monthStart = _newMoonDay(k);
  var a11 = _lunarMonth11(day.year), b11 = a11;
  int lunarYear;
  if (a11 >= monthStart) {
    lunarYear = day.year;
    a11 = _lunarMonth11(day.year - 1);
  } else {
    lunarYear = day.year + 1;
    b11 = _lunarMonth11(day.year + 1);
  }
  final lunarDay = dayNumber - monthStart + 1;
  final diff = _floor((monthStart - a11) / 29);
  var leap = false, lunarMonth = diff + 11;
  if (b11 - a11 > 365) {
    final leapDiff = _leapMonthOffset(a11);
    if (diff >= leapDiff) {
      lunarMonth = diff + 10;
      if (diff == leapDiff) leap = true;
    }
  }
  if (lunarMonth > 12) lunarMonth -= 12;
  if (lunarMonth >= 11 && diff < 4) lunarYear -= 1;
  return LunarDate(lunarDay, lunarMonth, lunarYear, leap, dayNumber);
}

/// The leap month of lunar [year], or 0 when it has none.
int lunarLeapMonth(int year) {
  _lunarRange(year);
  int? leapIn(int a11, int b11) {
    if (b11 - a11 <= 365) return null;
    var m = _leapMonthOffset(a11) - 2;
    if (m <= 0) m += 12;
    return m;
  }

  // Months 1–10 sit between the 11th months of the previous year and this
  // one; months 11 and 12 between this year's and the next.
  final early = leapIn(_lunarMonth11(year - 1), _lunarMonth11(year));
  if (early != null && early <= 10) return early;
  final late = leapIn(_lunarMonth11(year), _lunarMonth11(year + 1));
  if (late != null && late >= 11) return late;
  return 0;
}

/// Vietnamese lunar date → solar. Throws when the day or leap month does
/// not exist that year.
LunarDate lunarToSolar(int day, int month, int year, {bool leap = false}) {
  _lunarRange(year);
  if (month < 1 || month > 12) throw const FormatException('Month 1–12');
  if (day < 1 || day > 30) throw const FormatException('Day 1–30');
  int a11, b11;
  if (month < 11) {
    a11 = _lunarMonth11(year - 1);
    b11 = _lunarMonth11(year);
  } else {
    a11 = _lunarMonth11(year);
    b11 = _lunarMonth11(year + 1);
  }
  final k = _floor(0.5 + (a11 - 2415021.076998695) / 29.530588853);
  var off = month - 11;
  if (off < 0) off += 12;
  var leapMonth = 0;
  if (b11 - a11 > 365) {
    final leapOff = _leapMonthOffset(a11);
    leapMonth = leapOff - 2;
    if (leapMonth <= 0) leapMonth += 12;
    if (leap && month != leapMonth) {
      throw FormatException(_leapMessage(year));
    }
    if (leap || off >= leapOff) off += 1;
  } else if (leap) {
    throw FormatException(_leapMessage(year));
  }
  final start = _newMoonDay(k + off);
  final result = LunarDate(day, month, year, leap, start + day - 1);
  if (day > result.monthLength) {
    throw FormatException('This lunar month has ${result.monthLength} days');
  }
  // Round trip: the solar date must read back as the same lunar date.
  final back = solarToLunar(result.solar);
  if (back.day != day ||
      back.month != month ||
      back.year != year ||
      back.leap != leap) {
    throw const FormatException('That lunar date does not exist');
  }
  return back;
}

String _leapMessage(int year) {
  final leap = lunarLeapMonth(year);
  return leap == 0
      ? 'Lunar year $year has no leap month'
      : 'Lunar year $year has only leap month $leap';
}

/// The registry runner. [options] is `solar` (input `YYYY-MM-DD`) or
/// `lunar` / `lunar-leap` (input lunar `YYYY-M-D`).
String runLunar(String input, String options) {
  final s = input.trim();
  late final LunarDate d;
  switch (options.trim()) {
    case 'solar' || '':
      d = solarToLunar(s);
    case 'lunar' || 'lunar-leap':
      final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
      if (m == null) throw const FormatException('Use lunar YYYY-M-D');
      d = lunarToSolar(
        int.parse(m[3]!),
        int.parse(m[2]!),
        int.parse(m[1]!),
        leap: options.trim() == 'lunar-leap',
      );
    default:
      throw const FormatException('Choose solar, lunar or lunar-leap');
  }
  final weekday = DateTime.utc(
    int.parse(d.solar.substring(0, 4)),
    int.parse(d.solar.substring(5, 7)),
    int.parse(d.solar.substring(8, 10)),
  ).weekday;
  return _json({
    'solar': d.solar,
    'weekday': weekday,
    'lunarDay': d.day,
    'lunarMonth': d.month,
    'lunarYear': d.year,
    'leap': d.leap,
    'monthDays': d.monthLength,
    'dayName': d.dayName,
    'monthName': d.monthName,
    'yearName': d.yearName,
    'term': d.term,
    'termStarts': d.termStarts,
  });
}
