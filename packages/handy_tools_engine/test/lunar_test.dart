import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';

void main() {
  group('Tết (lunar 1/1) in Vietnam, UTC+7', () {
    for (final v in <int, String>{
      1985: '1985-01-21', // a month before China's (1985-02-20)
      2007: '2007-02-17', // a day before China's (2007-02-18)
      2020: '2020-01-25',
      2021: '2021-02-12',
      2022: '2022-02-01',
      2023: '2023-01-22',
      2024: '2024-02-10',
      2025: '2025-01-29',
      2026: '2026-02-17',
      2027: '2027-02-06',
      2028: '2028-01-26',
      2029: '2029-02-13',
      // New moon 2030-02-02 23:07 at UTC+7, 00:07 the next day in China.
      2030: '2030-02-02',
    }.entries) {
      test('${v.key}', () {
        expect(lunarToSolar(1, 1, v.key).solar, v.value);
        final back = solarToLunar(v.value);
        expect(
          [back.day, back.month, back.year, back.leap],
          [1, 1, v.key, false],
        );
        final eve = solarToLunar(
          DateTime.parse(v.value)
              .subtract(const Duration(days: 1))
              .toIso8601String()
              .substring(0, 10),
        );
        expect(eve.year, v.key - 1);
        expect(eve.month, 12);
      });
    }
  });

  group('leap months', () {
    test('known leap years', () {
      expect(lunarLeapMonth(2020), 4);
      expect(lunarLeapMonth(2023), 2);
      expect(lunarLeapMonth(2025), 6);
      expect(lunarLeapMonth(2028), 5);
      expect(lunarLeapMonth(2026), 0);
      expect(lunarLeapMonth(2024), 0);
    });
    test('2025 has a second sixth month', () {
      final regular = lunarToSolar(1, 6, 2025),
          leap = lunarToSolar(1, 6, 2025, leap: true);
      expect(regular.solar, '2025-06-25');
      expect(leap.solar, '2025-07-25');
      expect(leap.leap, isTrue);
      expect(solarToLunar('2025-07-25').leap, isTrue);
      expect(solarToLunar('2025-07-24').leap, isFalse);
      expect(lunarToSolar(1, 7, 2025).solar, '2025-08-23');
      expect(leap.monthName, regular.monthName);
    });
    test('2023 leap second month and 2020 leap fourth month', () {
      expect(lunarToSolar(1, 2, 2023, leap: true).solar, '2023-03-22');
      expect(lunarToSolar(1, 4, 2020, leap: true).solar, '2020-05-23');
    });
    test(
      'a leap month the year does not have is refused, naming the real one',
      () {
        expect(
          () => lunarToSolar(1, 5, 2025, leap: true),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('leap month 6'),
            ),
          ),
        );
        expect(
          () => lunarToSolar(1, 6, 2026, leap: true),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('no leap month'),
            ),
          ),
        );
      },
    );
  });

  group('days, can-chi and solar terms', () {
    test('Mid-autumn 2026 and its names', () {
      final d = lunarToSolar(15, 8, 2026);
      expect(d.solar, '2026-09-25');
      expect(d.yearName, 'Bính Ngọ');
      expect(d.monthName, 'Đinh Dậu');
    });
    test('day can-chi: 2000-01-01 was Mậu Ngọ', () {
      expect(solarToLunar('2000-01-01').dayName, 'Mậu Ngọ');
      expect(solarToLunar('2000-01-02').dayName, 'Kỷ Mùi');
    });
    test('month can-chi of the first month follows the year', () {
      expect(lunarToSolar(1, 1, 2026).monthName, 'Canh Dần');
      expect(lunarToSolar(1, 1, 2024).monthName, 'Bính Dần');
      expect(lunarToSolar(1, 11, 2026).monthName, 'Canh Tý');
    });
    test('year names', () {
      expect(lunarToSolar(1, 1, 2024).yearName, 'Giáp Thìn');
      expect(lunarToSolar(1, 1, 2025).yearName, 'Ất Tỵ');
      expect(lunarToSolar(1, 1, 1985).yearName, 'Ất Sửu');
    });
    test('solar terms change on the right day', () {
      expect(solarToLunar('2026-12-21').term, 'Đại tuyết');
      final solstice = solarToLunar('2026-12-22');
      expect(solstice.term, 'Đông chí');
      expect(solstice.termStarts, isTrue);
      expect(solarToLunar('2026-12-23').termStarts, isFalse);
      expect(solarToLunar('2026-02-04').term, 'Lập xuân');
      expect(solarToLunar('2026-02-03').term, 'Đại hàn');
    });
    test('month length and impossible days', () {
      final d = solarToLunar('2026-11-02');
      expect(d.monthLength, anyOf(29, 30));
      final short = [
        for (var m = 1; m <= 12; m++) lunarToSolar(1, m, 2026),
      ].firstWhere((d) => d.monthLength == 29);
      expect(() => lunarToSolar(30, short.month, 2026), throwsFormatException);
      expect(() => lunarToSolar(0, 1, 2026), throwsFormatException);
      expect(() => lunarToSolar(1, 13, 2026), throwsFormatException);
      expect(() => lunarToSolar(1, 1, 1899), throwsFormatException);
      expect(() => solarToLunar('2101-01-01'), throwsFormatException);
    });
    test('every day of 2024–2026 round trips', () {
      var day = DateTime.utc(2024, 1, 1);
      while (day.year < 2027) {
        final iso = day.toIso8601String().substring(0, 10);
        final l = solarToLunar(iso);
        expect(lunarToSolar(l.day, l.month, l.year, leap: l.leap).solar, iso);
        day = day.add(const Duration(days: 1));
      }
    });
  });

  group('registry runner', () {
    Map<String, Object?> run(String input, String options) =>
        (jsonDecode(
                  tools.singleWhere((t) => t.id == 'lunar').run(input, options),
                )
                as Map)
            .cast<String, Object?>();
    test('solar to lunar', () {
      final j = run('2026-02-17', 'solar');
      expect(
        [j['lunarDay'], j['lunarMonth'], j['lunarYear'], j['leap']],
        [1, 1, 2026, false],
      );
      expect(j['yearName'], 'Bính Ngọ');
      expect(j['weekday'], 2);
    });
    test('lunar (leap) to solar', () {
      expect(run('2025-6-1', 'lunar-leap')['solar'], '2025-07-25');
      expect(run('2026-08-15', 'lunar')['solar'], '2026-09-25');
      expect(() => run('2026/8/15', 'lunar'), throwsFormatException);
      expect(() => run('2026-08-15', 'moon'), throwsFormatException);
    });
  });
}
