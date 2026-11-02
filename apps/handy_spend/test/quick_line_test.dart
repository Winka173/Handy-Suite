import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend/entry/quick_line.dart';

void main() {
  test('one line reads the amount, its direction and the words', () {
    BigInt n(int v) => BigInt.from(v);
    var l = parseQuickLine('cà phê 45k', 'VND', vi: true);
    expect((l.amount, l.kind, l.words), (n(45000), 'expense', 'cà phê'));
    l = parseQuickLine('45.000 bánh mì', 'VND', vi: true);
    expect((l.amount, l.words), (n(45000), 'bánh mì'));
    l = parseQuickLine('tiền nhà 1tr2', 'VND', vi: true);
    expect((l.amount, l.words), (n(1200000), 'tiền nhà'));
    l = parseQuickLine('+5 triệu lương', 'VND', vi: true);
    expect((l.amount, l.kind, l.words), (n(5000000), 'income', 'lương'));
    l = parseQuickLine('grab 2 xe 30k', 'VND', vi: true);
    expect((l.amount, l.words), (n(30000), 'grab 2 xe'));
    expect(
      () => parseQuickLine('cà phê', 'VND', vi: true),
      throwsFormatException,
    );
  });
}
