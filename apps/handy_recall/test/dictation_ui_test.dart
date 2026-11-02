import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

RecallState english() => saveCard(
  saveDeck(
    emptyRecallState(),
    const RecallDeck(id: 'en', name: 'English', speakBack: 'en-US'),
  ),
  createCard(
    id: 'c1',
    deckId: 'en',
    front: 'tôi đã đến Hà Nội',
    back: 'I have been to Hanoi',
    now: at(now.subtract(const Duration(hours: 1))),
  ),
);

void main() {
  testWidgets('dictation reads the answer, checks each word, then grades', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    final speaker = FakeSpeaker();
    final store = stored(english());
    await start(t, store: store, speaker: speaker);
    await tapKey(t, 'study-start');
    await tapKey(t, 'review-dictation');
    expect(speaker.spoken.last, ('I have been to Hanoi', 'en-US'));
    await tapKey(t, 'dictation-slower');
    expect(speaker.rates.last, .6);
    // Space is a letter here, not "show the answer".
    await t.enterText(
      find.byKey(const Key('dictation-input')),
      'I have bean to Hanoi',
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('dictation-check')), findsOneWidget);
    await tapKey(t, 'dictation-check');
    expect(find.text('4 of 5 words right'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'bean, should be been',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('grade-good')), findsOneWidget);
    await tapKey(t, 'grade-good');
    final s = parseRecallBackup(store.text!);
    expect(s.cards.single.reviewCount, 1);
    handle.dispose();
  });

  testWidgets('no dictation for a deck that is not read aloud', (t) async {
    await start(t, store: stored(fixture()));
    await tapKey(t, 'study-start');
    expect(find.byKey(const Key('review-dictation')), findsNothing);
  });
}
