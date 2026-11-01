import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_recall_app/study/schedule.dart';

void main() {
  final now = DateTime(2026, 11, 1, 9);
  String at(DateTime d) => d.toUtc().toIso8601String();
  RecallCard card(String id, DateTime due, {int reviews = 1}) =>
      RecallCard.fromJson({
        ...createCard(
          id: id,
          deckId: 'd',
          front: 'Q$id',
          back: 'A',
          now: at(due.subtract(const Duration(days: 30))),
        ).toJson(),
        'dueAt': at(due),
        'reviewCount': reviews,
        'intervalDays': reviews == 0 ? 0 : 3,
        'lastReviewedAt': reviews == 0
            ? ''
            : at(due.subtract(const Duration(days: 3))),
      });

  test('overdue cards count toward today; later ones fall on their day', () {
    var s = saveDeck(
      emptyRecallState(),
      const RecallDeck(id: 'd', name: 'Deck'),
    );
    for (final c in [
      card('1', now.subtract(const Duration(days: 4))),
      card('2', now.add(const Duration(hours: 2))),
      card('3', now.add(const Duration(days: 1))),
      card('4', now.add(const Duration(days: 13))),
      card('5', now.add(const Duration(days: 20))),
    ]) {
      s = saveCard(s, c);
    }
    final f = forecast(s, now);
    expect(f.length, 14);
    expect(f[0], 2);
    expect(f[1], 1);
    expect(f[13], 1);
    expect(
      f.fold(0, (a, b) => a + b),
      4,
      reason: 'the 20-day card is past the window',
    );
  });

  test('grade buttons name the real next interval', () {
    final c = createCard(
      id: 'n',
      deckId: 'd',
      front: 'Q',
      back: 'A',
      now: at(now),
    );
    expect(spanWords(nextInterval(c, 'again', now)), ('10 min', '10 phút'));
    expect(spanWords(nextInterval(c, 'good', now)), ('1 day', '1 ngày'));
    expect(spanWords(nextInterval(c, 'easy', now)), ('4 days', '4 ngày'));
    expect(spanWords(45), ('6 wk', '6 tuần'));
    expect(spanWords(400), ('1.1 yr', '1.1 năm'));
  });

  test('a card is new, due or due in some days', () {
    expect(dueState(card('a', now, reviews: 0), now).$1, DueState.fresh);
    expect(
      dueState(card('b', now.subtract(const Duration(minutes: 1))), now).$1,
      DueState.due,
    );
    expect(dueState(card('c', now.add(const Duration(days: 3))), now), (
      DueState.later,
      3,
    ));
    expect(minutesFor(38), 7);
    expect(minutesFor(0), 0);
  });
}
