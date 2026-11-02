import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:test/test.dart';

void main() {
  test('an even count prints odds, then evens last first', () {
    final p = duplexPlan(6);
    expect(p.fronts, [0, 2, 4]);
    expect(p.backs, [5, 3, 1]);
    expect(p.lastFrontAlone, isFalse);
  });
  test('an odd count leaves the last front without a back', () {
    final p = duplexPlan(5);
    expect(p.fronts, [0, 2, 4]);
    expect(p.backs, [3, 1]);
    expect(p.lastFrontAlone, isTrue);
    expect(duplexPlan(2).backs, [1]);
    expect(() => duplexPlan(1), throwsFormatException);
  });
  test('page numbers start where asked and can skip the cover', () {
    expect(pageNumberFor(0), 1);
    expect(pageNumberFor(4, start: 3), 7);
    expect(pageNumberFor(0, skipFirst: true), isNull);
    expect(pageNumberFor(1, skipFirst: true), 1);
  });
}
