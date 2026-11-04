import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

/// "Skills" with two cards due: [card] and [other].
RecallState two() => saveCard(
  fixture(),
  createCard(
    id: 'other',
    deckId: 'deck',
    front: 'Second',
    back: 'Two',
    now: at(now.subtract(const Duration(hours: 1))),
  ),
);

void main() {
  testWidgets('the cards just forgotten can be gone over at once, '
      'without moving them in the schedule', (tester) async {
    final store = stored(two());
    await start(tester, store: store);
    RecallState saved() => parseRecallBackup(store.text!);
    await tapKey(tester, 'study-start');
    // Forget the first card, know the second.
    await tapKey(tester, 'review-show');
    final first = saved().cards
        .where((c) => c.reviewCount == 0)
        .map((c) => c.id)
        .toSet();
    await tapKey(tester, 'grade-again');
    await tapKey(tester, 'review-show');
    await tapKey(tester, 'grade-good');
    // A forgotten card comes back the same day; finish it too.
    while (find.byKey(const Key('review-show')).evaluate().isNotEmpty) {
      await tapKey(tester, 'review-show');
      await tapKey(tester, 'grade-good');
    }
    final forgotten = saved().cards.where((c) => c.lapses == 1).single;
    expect(first, contains(forgotten.id));
    final before = saved().toJson();

    await tapKey(tester, 'practice-forgotten');
    expect(find.text('The ones you forgot'), findsOneWidget);
    await tapKey(tester, 'review-show');
    await tapKey(tester, 'practice-again');
    // Not yet: the same card again, then it is done.
    await tapKey(tester, 'review-show');
    await tapKey(tester, 'practice-ok');
    expect(find.byKey(const Key('practice-done')), findsOneWidget);
    expect(saved().toJson(), before);
  });

  testWidgets('a deck offers its hard cards for practice', (tester) async {
    var s = two();
    s = saveCard(
      s,
      s.cards.firstWhere((c) => c.id == 'card').copyWith({
        'lapses': 3,
        'reviewCount': 5,
        'lastReviewedAt': at(now.subtract(const Duration(days: 2))),
        'dueAt': at(now.add(const Duration(days: 3))),
      }),
    );
    final store = stored(s);
    await start(tester, store: store);
    final before = parseRecallBackup(store.text!).toJson();
    await tapKey(tester, 'deck-deck');
    expect(find.text('Practise 1 hard'), findsOneWidget);
    await tapKey(tester, 'deck-hard');
    expect(find.text('Question'), findsOneWidget);
    await tapKey(tester, 'review-show');
    await tapKey(tester, 'practice-ok');
    expect(find.byKey(const Key('practice-done')), findsOneWidget);
    expect(parseRecallBackup(store.text!).toJson(), before);
  });
}
