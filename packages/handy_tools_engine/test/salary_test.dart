import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';

void main() {
  final july = salaryRulesOn('2026-11-02');
  Map<String, Object?> run(String input, Map<String, Object?> options) =>
      (jsonDecode(
                tools
                    .singleWhere((t) => t.id == 'salary')
                    .run(input, jsonEncode(options)),
              )
              as Map)
          .cast<String, Object?>();

  group('dated rule table', () {
    test('the rules in force on 2026-11-02 are the cited ones', () {
      expect(july.from, '2026-07-01');
      expect(july.personal, 15500000);
      expect(july.dependant, 6200000);
      expect(july.base, 2530000);
      expect(july.regionalMinimum, [5310000, 4730000, 4140000, 3700000]);
      expect([july.social, july.health, july.unemployment], ['8', '1.5', '1']);
      expect(
        july.bracketText,
        '10000000=5; 30000000=10; 60000000=20; 100000000=30; *=35',
      );
    });
    test('each date picks the latest table that has started', () {
      expect(salaryRulesOn('2026-06-30').base, 2340000);
      expect(salaryRulesOn('2026-01-01').personal, 15500000);
      expect(salaryRulesOn('2025-12-31').personal, 11000000);
      expect(salaryRulesOn('2025-12-31').brackets.length, 7);
      expect(salaryRulesOn('2024-07-01').from, '2024-07-01');
      expect(() => salaryRulesOn('2024-06-30'), throwsFormatException);
      expect(() => salaryRulesOn('2026-02-30'), throwsFormatException);
    });
    test('the table is in date order and every entry cites a source', () {
      for (var i = 1; i < salaryRuleTable.length; i++) {
        expect(
          salaryRuleTable[i].from.compareTo(salaryRuleTable[i - 1].from),
          greaterThan(0),
        );
      }
      for (final r in salaryRuleTable) {
        expect(r.sources, isNotEmpty);
        expect(r.brackets.last.upTo, isNull);
      }
    });
  });

  group('gross to net', () {
    test('30,000,000 đ, no dependants, region I', () {
      final b = salaryFromGross('30000000', rules: july);
      expect(
        [b.social, b.health, b.unemployment, b.insurance],
        [2400000, 450000, 300000, 3150000],
      );
      expect(b.taxable, 11350000);
      expect([for (final r in b.brackets) r.tax], [500000, 135000]);
      expect([for (final r in b.brackets) r.amount], [10000000, 1350000]);
      expect(b.tax, 635000);
      expect(b.net, 26215000);
    });
    test('caps: social and health at 20 × base, unemployment at 20 × '
        'the region\'s minimum wage', () {
      final b = salaryFromGross(
        '100000000',
        rules: july,
        region: 2,
        dependants: 2,
      );
      expect(b.socialCap, 50600000);
      expect(b.unemploymentCap, 94600000);
      expect([b.social, b.health, b.unemployment], [4048000, 759000, 946000]);
      expect(b.dependants, 12400000);
      expect(b.taxable, 66347000);
      expect(
        [for (final r in b.brackets) r.tax],
        [500000, 2000000, 6000000, 1904100],
      );
      expect(b.tax, 10404100);
      expect(b.net, 83842900);
    });
    test('before July 2026 the cap follows the old base salary', () {
      final b = salaryFromGross(
        '100000000',
        rules: salaryRulesOn('2026-03-01'),
        region: 2,
        dependants: 2,
      );
      expect([b.social, b.health, b.unemployment], [3744000, 702000, 946000]);
      expect(b.tax, 10512400);
      expect(b.net, 84095600);
    });
    test('2025 rules: seven brackets and 11,000,000 đ personal deduction', () {
      final b = salaryFromGross('30000000', rules: salaryRulesOn('2025-06-01'));
      expect(b.taxable, 15850000);
      expect([for (final r in b.brackets) r.tax], [250000, 500000, 877500]);
      expect(b.net, 25222500);
    });
    test('below the deductions no tax is due', () {
      final b = salaryFromGross('10000000', rules: july, dependants: 1);
      expect(b.taxable, 0);
      expect(b.brackets, isEmpty);
      expect(b.tax, 0);
      expect(b.net, 8950000);
      expect(salaryFromGross('0', rules: july).net, 0);
    });
    test(
      'each amount rounds half up to a whole đồng and the payslip adds up',
      () {
        final b = salaryFromGross('12345678', rules: july);
        expect([b.social, b.health, b.unemployment], [987654, 185185, 123457]);
        expect(salaryFromGross('12345678.5', rules: july).gross, 12345679);
        for (final g in [7654321, 25000001, 61234567, 150000003]) {
          final b = salaryFromGross('$g', rules: july, dependants: 1);
          expect(b.gross - b.insurance - b.tax, b.net, reason: '$g');
          expect(b.brackets.fold<int>(0, (n, r) => n + r.tax), b.tax);
          expect(b.brackets.fold<int>(0, (n, r) => n + r.amount), b.taxable);
        }
      },
    );
  });

  group('net to gross', () {
    test('an exact net finds the gross that produces it', () {
      final b = salaryFromNet('26215000', rules: july);
      expect(b.gross, 30000000);
      expect(b.net, 26215000);
    });
    test('round trips within two đồng across brackets and caps', () {
      for (final g in [
        5000000,
        17000000,
        33333333,
        48000000,
        52000000,
        99999999,
        180000000,
      ]) {
        for (final dependants in [0, 3]) {
          final forward = salaryFromGross(
            '$g',
            rules: july,
            region: 3,
            dependants: dependants,
          );
          final back = salaryFromNet(
            '${forward.net}',
            rules: july,
            region: 3,
            dependants: dependants,
          );
          expect((back.gross - g).abs(), lessThanOrEqualTo(2), reason: '$g');
          expect((back.net - forward.net).abs(), lessThanOrEqualTo(2));
        }
      }
    });
  });

  group('overrides', () {
    test('insured salary at the regional minimum', () {
      final b = salaryFromGross(
        '30000000',
        rules: july,
        overrides: const SalaryOverrides(insured: 5310000),
      );
      expect([b.social, b.health, b.unemployment], [424800, 79650, 53100]);
      expect(b.tax, 894245);
      expect(b.net, 28548205);
    });
    test('every parameter can be replaced', () {
      final b = salaryFromGross(
        '40000000',
        rules: july,
        dependants: 1,
        overrides: SalaryOverrides(
          personal: 11000000,
          dependant: 4400000,
          base: 1000000,
          regionalMinimum: 1000000,
          social: '10',
          health: '2',
          unemployment: '0',
          brackets: parseSalaryBrackets('10.000.000=10; *=20'),
        ),
      );
      expect([b.social, b.health, b.unemployment], [2000000, 400000, 0]);
      expect(b.taxable, 40000000 - 2400000 - 11000000 - 4400000);
      expect(b.tax, 1000000 + (22200000 - 10000000) * 20 ~/ 100);
    });
    test('bracket text is validated whole', () {
      expect(parseSalaryBrackets('*=35'), [(upTo: null, rate: '35')]);
      expect(
        formatSalaryBrackets(parseSalaryBrackets(july.bracketText)),
        july.bracketText,
      );
      for (final bad in [
        '',
        '10000000=5',
        '*=5; 10=10',
        '20=5; 10=10; *=20',
        '10=5; *=61',
        'ten=5; *=10',
        '0=5; *=10',
      ]) {
        expect(
          () => parseSalaryBrackets(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });
    test('impossible settings are refused', () {
      expect(
        () => salaryFromGross('1', rules: july, region: 5),
        throwsFormatException,
      );
      expect(
        () => salaryFromGross('1', rules: july, dependants: 21),
        throwsFormatException,
      );
      expect(
        () => salaryFromGross(
          '1',
          rules: july,
          overrides: const SalaryOverrides(social: '21'),
        ),
        throwsFormatException,
      );
      expect(() => salaryFromGross('-1', rules: july), throwsFormatException);
      expect(
        () => salaryFromGross('100000000001', rules: july),
        throwsFormatException,
      );
      expect(() => salaryFromGross('abc', rules: july), throwsFormatException);
    });
  });

  group('registry runner', () {
    test('gross mode reports the rules, sources and breakdown', () {
      final j = run('30000000', {
        'mode': 'gross',
        'date': '2026-11-02',
        'region': 1,
        'dependants': 0,
      });
      expect(j['rulesFrom'], '2026-07-01');
      expect(j['net'], '26215000');
      expect(j['overridden'], 0);
      expect((j['sources'] as List).join(), contains('110/2025'));
      expect((j['brackets'] as List).length, 2);
    });
    test('net mode with overrides as text fields', () {
      final j = run('20000000', {
        'mode': 'net',
        'date': '2026-11-02',
        'region': 4,
        'dependants': 1,
        'overrides': {'insured': '10.000.000', 'social': '8', 'brackets': ''},
      });
      expect(j['overridden'], 2);
      expect(j['target'], '20000000');
      expect(int.parse(j['net'] as String), closeTo(20000000, 2));
      expect(j['insured'], '10000000');
    });
    test('bad options are refused', () {
      for (final o in [
        {'mode': 'both', 'date': '2026-11-02'},
        {'date': '2020-01-01'},
        {'date': '2026-11-02', 'region': 'x'},
        {
          'date': '2026-11-02',
          'overrides': {'personal': 'lots'},
        },
      ]) {
        expect(() => run('1000', o), throwsFormatException, reason: '$o');
      }
      expect(
        () => tools.singleWhere((t) => t.id == 'salary').run('1', '[]'),
        throwsFormatException,
      );
    });
  });
}
