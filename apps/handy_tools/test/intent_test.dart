import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tools/bench/intent.dart';
import 'package:handy_tools/bench/tape.dart';

List<String> ids(String s, {bool vi = true}) => [
  for (final r in interpret(s, vi: vi, now: DateTime(2026, 11, 1))) r.toolId,
];

void main() {
  test('numbers are read in the writer\'s own convention', () {
    expect(normalizeNumber('1.385.000', vi: true), '1385000');
    expect(normalizeNumber('1.385.000,5', vi: true), '1385000.5');
    expect(normalizeNumber('1,385,000.5', vi: false), '1385000.5');
    expect(normalizeNumber('2,5', vi: true), '2.5');
    expect(normalizeNumber('2.5', vi: true), '2.5');
    expect(normalizeNumber('1.385', vi: true), '1385');
    expect(normalizeNumber('1.385', vi: false), '1.385');
    expect(normalizeNumber('abc', vi: true), isNull);
  });

  test('arithmetic as people type it', () {
    final r = interpret('1.385.000 × 3', vi: true).single;
    expect(r.toolId, 'calculate');
    expect(r.values['expression'], '1385000 * 3');
    expect(
      interpret('4 x 125.000', vi: true).single.values['expression'],
      '4*125000',
    );
    expect(ids('sqrt(16)'), ['calculate']);
    expect(ids('42'), [
      'count',
      ...textTransforms,
    ], reason: 'a bare number is not a sum');
  });

  test('units, percent, dates and colours in Vietnamese and English', () {
    final u = interpret('5 km sang mi', vi: true).single;
    expect(u.toolId, 'units');
    expect(u.values, {
      'kind': 'length',
      'value': '5',
      'from': 'km',
      'to': 'mi',
    });
    expect(interpret('100 °C to F', vi: false).single.values['from'], 'C');
    final p = interpret('15% của 2.400.000', vi: true).single;
    expect(p.values, {'amount': '2400000', 'percent': '15'});
    final d = interpret(
      '31/12/2026 đến hôm nay',
      vi: true,
      now: DateTime(2026, 11, 1),
    );
    expect(d.first.values, {'start': '2026-12-31', 'end': '2026-11-01'});
    expect(d[1].toolId, 'business-days');
    expect(ids('#e8590c'), ['colors']);
    expect(ids('#111111 trên #ffffff'), ['contrast']);
  });

  test('links offer a QR code; prose offers counts and transforms', () {
    expect(ids('https://example.com').first, 'qr');
    expect(ids('Xin chào\nthế giới').first, 'count');
    expect(ids(''), isEmpty);
  });

  test('the tape totals exact decimals and ignores non-numbers', () {
    final tape = TapeController();
    for (final (n, a) in [('0.1', '0.1'), ('0.2', '0.2'), (null, 'HELLO')]) {
      tape.add(
        TapeEntry(
          input: a,
          answer: a,
          number: n,
          toolId: 'x',
          values: const {},
        ),
      );
    }
    expect(tape.total, '0.3');
    expect(tape.counted, 2);
    tape.clear();
    expect(tape.total, isNull);
  });
}
