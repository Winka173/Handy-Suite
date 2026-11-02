import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';

void main() {
  test('a calc notebook reads names, units, totals and the line above', () {
    final r = evaluateNotebook('''
Chi tiêu
Tiền nhà: 5tr
Điện 1.200.000
Ăn sáng 30 ngày x 35k
tổng
tiết kiệm = ans * 10%
tiền nhà / 2
chia 3 = 6000 / 3
45 / 0''');
    expect(r.map((l) => l.value).toList(), [
      null,
      '5000000',
      '1200000',
      '1050000',
      '7250000',
      '725000',
      '2500000',
      '2000',
      null,
    ]);
    expect(r[4].total, isTrue);
    final third = evaluateNotebook('10 / 3').single;
    expect((third.value, third.shown), ('3.33333333333333', '3.33'));
    expect(r.last.error, isNotNull);
  });
  test('percentages read the way people say them', () {
    String? v(String line) => evaluateNotebook(line).single.value;
    expect(v('15% của 2.400.000'), '360000');
    expect(v('15% of 2400000'), '360000');
    expect(v('giá 2tr4 - 15%'), isNull);
    expect(v('2.400.000 - 15%'), '2040000');
    expect(v('100 + 8%'), '108');
    expect(v('100 - 5% - 2%'), '93.1');
    expect(v('ans * 10%'), isNull);
    expect(v('200 * 10%'), '20');
    expect(v('1920 * 9 / 16'), '1080');
  });
}
