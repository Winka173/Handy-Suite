import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';

void main() {
  String run(String id, String input, [String options = '']) =>
      tools.singleWhere((t) => t.id == id).run(input, options);
  group('calculator fixture parity', () {
    for (final vector in <String, String>{
      '0.1+0.2': '0.3',
      '2+3*4': '14',
      '(2+3)*4': '20',
      '2^3^2': '512',
      'sqrt(9)+abs(-2)': '5',
      '1e3/4': '250',
      '-3+1': '-2',
      '-2^2': '-4',
      '2^-2': '0.25',
      '(-2)^2': '4',
      'sin(0)+cos(0)': '1',
      '1/3': '0.333333333333333',
      '1e21': '1e+21',
      '1e-7': '1e-7',
      '1e-6': '0.000001',
      '1.000000000000001': '1',
      '999999999999999.9': '1000000000000000',
      '7%3': '1',
      '-7%3': '-1',
    }.entries) {
      test(vector.key, () => expect(calculate(vector.key), vector.value));
    }
    for (final source in [
      '1/0',
      '1%0',
      'process.exit()',
      '2**3',
      'sqrt(-1)',
      'log(0)',
      '(2+3',
      '2+',
      '9^1001',
      '2' * 2001,
      '()',
      '1 2',
      'NaN',
      'Infinity',
      'sin 0',
    ]) {
      test(
        'reject ${source.length > 40 ? 'oversized input' : source}',
        () => expect(() => calculate(source), throwsFormatException),
      );
    }
    test(
      'nesting budget',
      () => expect(
        () => calculate('${'(' * 60}1${')' * 60}'),
        throwsFormatException,
      ),
    );
    test(
      'integer large exponent preserves finite decimal range',
      () => expect(calculate('10^1000'), '1e+1000'),
    );
    test('sqrt preserves arbitrary decimal range', () {
      expect(calculate('sqrt(1e1000)'), '1e+500');
      expect(calculate('sqrt(1e-1000)'), '1e-500');
      expect(calculate('sqrt(2)'), '1.4142135623731');
      expect(calculate('sqrt(0)'), '0');
      expect(calculate('(1e-1000)^0.5'), '1e-500');
      expect(() => calculate('(1e-1000)^0.25'), throwsFormatException);
    });
    test(
      'reject explosive powers before allocating their result',
      () => expect(() => calculate('(1e1000)^1000'), throwsFormatException),
    );
  });
  group('unit fixtures and round trips', () {
    for (final v in [
      ['1', 'm', 'cm', '100'],
      ['32', 'F', 'C', '0'],
      ['0', 'C', 'K', '273.15'],
      ['1', 'MiB', 'B', '1048576'],
      ['1', 'lb', 'g', '453.59237'],
    ]) {
      test(v.join(' '), () => expect(convert(v[0], v[1], v[2]), v[3]));
    }
    for (final group in unitGroups.entries) {
      test('${group.key} every unit round trip', () {
        for (final from in group.value) {
          for (final to in group.value) {
            final converted = convert('123.45', from, to),
                restored = double.parse(convert(converted, to, from));
            expect(restored, closeTo(123.45, 1e-8));
          }
        }
      });
    }
    for (final v in [
      ['1', 'm', 'kg'],
      ['NaN', 'm', 'cm'],
      ['-274', 'C', 'F'],
      ['-0.1', 'K', 'C'],
      ['1', 'bad', 'm'],
    ]) {
      test(
        'reject ${v.join(' ')}',
        () => expect(() => convert(v[0], v[1], v[2]), throwsFormatException),
      );
    }
  });
  group('financial calculations', () {
    test('zero-rate full loan', () {
      final rows = loan('1200', '0', 12).split('\n');
      expect(rows.length, 13);
      expect(rows[1], '1,100.00,0.00,100.00,1100.00');
      expect(rows.last, '12,100.00,0.00,100.00,0.00');
    });
    test(
      'fixed rate 360 month vector',
      () => expect(
        loan('100000', '6', 360).split('\n')[1].split(',')[1],
        '599.55',
      ),
    );
    test('tax', () {
      expect(tax('110', '10', true), {
        'base': '100.00',
        'tax': '10.00',
        'total': '110.00',
      });
      expect(tax('100', '10', false), {
        'base': '100.00',
        'tax': '10.00',
        'total': '110.00',
      });
      expect(() => tax('-1', '10', false), throwsFormatException);
    });
    test(
      'half-up currency',
      () => expect(tax('1.005', '0', true)['total'], '1.01'),
    );
    test('split cents', () {
      expect(splitBill('10', '0', 3), {
        'total': '10.00',
        'shares': ['3.34', '3.33', '3.33'],
      });
      expect(splitBill('120', '10', 3)['shares'], ['44.00', '44.00', '44.00']);
      expect(() => splitBill('1', '0', 0), throwsFormatException);
    });
    test('split allocation all totals', () {
      for (var cents = 1; cents < 100; cents++) {
        for (var people = 1; people < 10; people++) {
          final result = splitBill((cents / 100).toString(), '0', people);
          final sum = (result['shares'] as List<String>).fold<int>(
            0,
            (a, s) => a + (double.parse(s) * 100).round(),
          );
          expect(sum, cents);
        }
      }
    });
    test('compound', () => expect(run('compound', '1000,5,10,12'), '1647.01'));
    test(
      'compound supports all permitted integer periods',
      () => expect(run('compound', '1000,0,100,365'), '1000.00'),
    );
    test('tiny rate maximum loan remains bounded', () {
      final rows = loan('1200', '1e-1000', 1200).split('\n');
      expect(rows.length, 1201);
      expect(rows[1], '1,1.00,0.00,1.00,1199.00');
      expect(rows.last.endsWith(',0.00'), true);
    });
    test(
      'percentage',
      () => expect(jsonDecode(run('percent', '200,15')), {
        'percent': '30',
        'afterDiscount': '170',
      }),
    );
    test('ratio', () => expect(run('ratio', '16,9,1920'), '1080'));
    test(
      'manual exchange preserves supplied date',
      () =>
          expect(jsonDecode(run('manual-exchange', '12.5,25000,2026-10-31')), {
            'amount': '312500.00',
            'rate': '25000',
            'rateDate': '2026-10-31',
            'source': 'user supplied',
          }),
    );
    test('malformed financial inputs', () {
      for (final input in ['100,-1,12', '100,6,0', '-1,6,12', '1,6,1.5']) {
        expect(() => run('loan', input), throwsFormatException);
      }
      expect(() => run('ratio', '0,2,3'), throwsFormatException);
      expect(() => run('compound', '100,5,101,12'), throwsFormatException);
      expect(
        () => run('manual-exchange', '1,0,2026-10-31'),
        throwsFormatException,
      );
    });
  });
  group('calendar dates', () {
    test('leap and DST independent', () {
      expect(dateDiff('2024-02-28', '2024-03-01'), 2);
      expect(dateDiff('2026-03-07', '2026-03-09'), 2);
      expect(dateDiff('2026-03-09', '2026-03-07'), -2);
    });
    for (final bad in [
      '2023-02-29',
      '2026-13-01',
      '2026-04-31',
      '2026-1-01',
      '0000-01-01',
    ]) {
      test(
        'invalid $bad',
        () => expect(() => dateDiff(bad, '2026-03-01'), throwsFormatException),
      );
    }
    test('business days', () {
      expect(businessDays('2026-10-26', '2026-11-02'), 5);
      expect(
        businessDays('2026-10-26', '2026-11-02', [0, 6], ['2026-10-30']),
        4,
      );
      expect(businessDays('2024-02-28', '2024-03-01', []), 2);
      expect(
        () => businessDays('2026-10-30', '2026-10-01'),
        throwsFormatException,
      );
      expect(
        () => businessDays('2026-10-01', '2026-10-30', [7]),
        throwsFormatException,
      );
    });
  });
  group('Unicode and text bounds', () {
    test('23 unique tools', () {
      expect(tools.length, 23);
      expect(tools.map((t) => t.id).toSet().length, 23);
    });
    test(
      'NFC whitespace',
      () => expect(
        run('normalize', '  Tiếng\t  Việt  \r\n  x  '),
        'Tiếng Việt\nx',
      ),
    );
    test(
      'remove Vietnamese accents',
      () => expect(
        removeAccents('Đặng Thị Hồng — Tiếng Việt'),
        'Dang Thi Hong — Tieng Viet',
      ),
    );
    test(
      'codepoints and UTF16',
      () => expect(textStats('A 😀\nB'), {
        'codePoints': 5,
        'utf16Units': 6,
        'words': 3,
        'lines': 2,
      }),
    );
    test(
      'first occurrence dedup',
      () => expect(run('deduplicate', 'a\nb\na'), 'a\nb'),
    );
    test(
      'codepoint sort astral vs BMP',
      () => expect(run('sort', '😀\n\uE000\na'), 'a\n\uE000\n😀'),
    );
    test('uppercase/lowercase', () {
      expect(run('uppercase', 'Tiếng Việt'), 'TIẾNG VIỆT');
      expect(run('lowercase', 'TIẾNG VIỆT'), 'tiếng việt');
    });
    test('title/sentence case', () {
      expect(run('title-case', 'XIN CHÀO thế GIỚI'), 'Xin Chào Thế Giới');
      expect(
        run('sentence-case', 'XIN CHÀO. THẾ GIỚI!'),
        'Xin chào. Thế giới!',
      );
    });
    test('literal dollar text', () {
      expect(replaceLiteral('a a', 'a', r'$&', true), r'$& $&');
      expect(replaceLiteral('a a', 'a', 'b', false), 'b a');
    });
    test('replacement bomb', () {
      expect(
        () => replaceLiteral('a' * 200000, 'a', '1234567890', true),
        throwsFormatException,
      );
      expect(() => replaceLiteral('a', '', 'b', true), throwsFormatException);
      expect(() => run('count', 'a' * 1000001), throwsFormatException);
    });
    test(
      'replace option validation',
      () => expect(
        () => run('literal-replace', 'a', '{"find":1,"replace":"b"}'),
        throwsFormatException,
      ),
    );
  });
  group('colors', () {
    test('black white WCAG', () => expect(contrast('#000000', '#ffffff'), 21));
    for (final v in <String, Map<String, num>>{
      '#ff0000': {'h': 0, 's': 100, 'l': 50},
      '#00ff00': {'h': 120, 's': 100, 'l': 50},
      '#0000ff': {'h': 240, 's': 100, 'l': 50},
      '#ffffff': {'h': 0, 's': 0, 'l': 100},
      '#000000': {'h': 0, 's': 0, 'l': 0},
    }.entries) {
      test(v.key, () => expect(colors(v.key)['hsl'], v.value));
    }
    test(
      'invalid hex',
      () => expect(() => colors('#fff'), throwsFormatException),
    );
  });
  group('secure password generation', () {
    test('default secure entropy and required groups', () {
      final seen = <String>{};
      for (var i = 0; i < 50; i++) {
        final value = securePassword();
        expect(value.length, 20);
        for (final pattern in [r'[A-Z]', r'[a-z]', r'[0-9]', r'[^a-zA-Z0-9]']) {
          expect(RegExp(pattern).hasMatch(value), true);
        }
        seen.add(value);
      }
      expect(seen.length, 50);
    });
    test('exclude ambiguous', () {
      final result = generatePassword(
        const PasswordOptions(excludeAmbiguous: true),
        randomInt: Random(42).nextInt,
      );
      expect(RegExp('[0O1Il]').hasMatch(result), false);
    });
    test(
      'one class allowed',
      () => expect(
        RegExp(r'^\d{16}$').hasMatch(
          securePassword(
            length: 16,
            upper: false,
            lower: false,
            symbols: false,
          ),
        ),
        true,
      ),
    );
    test('reject sampler does not modulo-bias rejected bytes', () {
      var calls = 0;
      final value = generatePassword(
        const PasswordOptions(
          length: 8,
          upper: false,
          lower: false,
          symbols: false,
        ),
        randomInt: (_) => calls++ % 2 == 0 ? 255 : 9,
      );
      expect(value, '99999999');
      expect(calls, 16);
    });
    test('invalid configuration and failed random', () {
      expect(() => securePassword(length: 7), throwsFormatException);
      expect(() => securePassword(length: 129), throwsFormatException);
      expect(
        () => securePassword(
          upper: false,
          lower: false,
          digits: false,
          symbols: false,
        ),
        throwsFormatException,
      );
      expect(
        () => generatePassword(const PasswordOptions(), randomInt: (_) => 300),
        throwsFormatException,
      );
      expect(
        () => generatePassword(
          const PasswordOptions(
            length: 8,
            upper: false,
            lower: false,
            symbols: false,
          ),
          randomInt: (_) => 255,
        ),
        throwsFormatException,
      );
    });
  });
  group('structured QR safety', () {
    test(
      'WiFi escapes delimiters',
      () => expect(
        wifiQr('A;B', 'p:ass\\word', 'WPA', true),
        r'WIFI:T:WPA;S:A\;B;P:p\:ass\\word;H:true;;',
      ),
    );
    test(
      'open WiFi omits credentials',
      () => expect(
        wifiQr('Guest', 'secret', 'nopass'),
        isNot(contains('secret')),
      ),
    );
    test('contact vCard', () {
      final value = contactQr('Nguyễn, A', '+84123456789', 'a@example.com');
      expect(value, contains('FN:Nguyễn\\, A'));
      expect(value.endsWith('END:VCARD'), true);
    });
    test('event UTC', () {
      final value = eventQr(
        'Review',
        '2026-10-31T08:00:00Z',
        '2026-10-31T09:00:00Z',
        'Office',
      );
      expect(value, contains('DTSTART:20261031T080000Z'));
      expect(qrPreview(value)['kind'], 'Event');
    });
    test('malformed dates and injection', () {
      expect(
        () => eventQr('a', '2026-02-30T08:00:00Z', '2026-03-01T09:00:00Z', ''),
        throwsFormatException,
      );
      expect(
        () => eventQr('a', '2026-10-31T09:00:00Z', '2026-10-31T08:00:00Z', ''),
        throwsFormatException,
      );
      expect(() => contactQr('A\r\nURL:evil', '', ''), throwsFormatException);
      expect(() => wifiQr('a', 'b', 'evil'), throwsFormatException);
      expect(() => contactQr('a', '', 'bad'), throwsFormatException);
    });
    test('preview never opens URLs', () {
      expect(qrPreview('javascript:alert(1)')['warning'], contains('unsafe'));
      expect(
        qrPreview('https://user:pass@example.com')['warning'],
        contains('unsafe'),
      );
      expect(
        qrPreview('https://example.com')['warning'],
        contains('example.com'),
      );
    });
    test('history validates bounded roundtrip', () {
      final original = [
        {'at': '2026-10-31T08:00:00Z', 'text': 'hello'},
      ];
      expect(parseQrHistory(jsonEncode(original)), original);
      expect(
        () => parseQrHistory(jsonEncode(List.filled(51, original.first))),
        throwsFormatException,
      );
      expect(() => qrPreview('a' * 1201), throwsFormatException);
    });
  });
}
