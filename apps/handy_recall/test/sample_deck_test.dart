import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall/handy_recall.dart';
import 'helpers.dart';

void main() {
  testWidgets('a sample deck to review at once, removed in one tap', (
    tester,
  ) async {
    final store = Store();
    await start(tester, store: store);
    await tapKey(tester, 'deck-sample');
    RecallState saved() => parseRecallBackup(store.text!);
    expect(saved().decks.single.name, contains('sample'));
    expect(saved().cards, hasLength(20));
    // All due now: the first review starts straight away.
    await tapKey(tester, 'study-start');
    await tapKey(tester, 'review-show');
    await tapKey(tester, 'grade-good');
    expect(saved().cards.where((c) => c.reviewCount == 1), hasLength(1));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tapKey(tester, 'deck-${saved().decks.single.id}');
    await tapKey(tester, 'sample-remove');
    expect(saved().decks, isEmpty);
    expect(saved().cards, isEmpty);
  });
}
