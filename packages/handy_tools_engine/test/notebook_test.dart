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
}
