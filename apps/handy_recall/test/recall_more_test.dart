import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import 'apkg.dart';
import 'helpers.dart';

RecallState japanese({String front = '', String back = ''}) => saveCard(
  saveDeck(
    emptyRecallState(),
    RecallDeck(id: 'jp', name: 'Nihongo', speakFront: front, speakBack: back),
  ),
  createCard(
    id: 'mizu',
    deckId: 'jp',
    front: '水',
    back: 'nước',
    now: at(now.subtract(const Duration(hours: 1))),
  ),
);

/// Distinct ids, one after another (a clock can repeat).
String Function() ids() {
  var n = 0;
  return () => 'n${++n}';
}

void main() {
  group('Anki import', () {
    testWidgets('previews everything, writes nothing until Add', (t) async {
      final store = stored(fixture());
      final before = store.text;
      final files = Files()..bytes = ImportedBytes('spanish.apkg', apkg());
      await start(t, store: store, files: files);
      await tapKey(t, 'anki-open');
      expect(find.byKey(const Key('anki-count')), findsOneWidget);
      expect(find.textContaining('5'), findsWidgets);
      expect(find.text('Spanish › Basics'), findsOneWidget);
      expect(find.byKey(const Key('anki-left-out')), findsOneWidget);
      expect(find.textContaining('1 sounds and videos'), findsOneWidget);
      expect(find.byKey(const Key('anki-keep-schedule')), findsOneWidget);
      // Previewing wrote nothing.
      expect(store.text, before);
      await tapKey(t, 'anki-import');
      final s = parseRecallBackup(store.text!);
      expect(s.decks.map((d) => d.name), ['Skills', 'Spanish › Basics']);
      expect(s.cards.length, 6);
      final reviewed = s.cards.firstWhere((c) => c.front == 'gato');
      expect(reviewed.reviewCount, 6);
      expect(reviewed.back, 'cat');
      expect(s.cards.where((c) => c.reversed).single.question, 'dog');
      expect(s.cards.where((c) => c.cloze > 0).length, 2);
      expect(find.textContaining('Added 5 cards'), findsOneWidget);
    });

    testWidgets('import as new starts every card fresh', (t) async {
      final store = stored(emptyRecallState());
      final files = Files()..bytes = ImportedBytes('spanish.apkg', apkg());
      await start(t, store: store, files: files);
      await tapKey(t, 'anki-first');
      await tapKey(t, 'anki-keep-schedule');
      await tapKey(t, 'anki-import');
      final s = parseRecallBackup(store.text!);
      expect(s.cards.every((c) => c.reviewCount == 0), isTrue);
    });

    testWidgets('a failed write keeps the preview and the library', (t) async {
      final store = stored(fixture())..fail = true;
      final files = Files()..bytes = ImportedBytes('spanish.apkg', apkg());
      await start(t, store: store, files: files);
      await tapKey(t, 'anki-open');
      await tapKey(t, 'anki-import');
      expect(find.textContaining('Nothing changed'), findsOneWidget);
      expect(find.byKey(const Key('anki-import')), findsOneWidget);
      expect(parseRecallBackup(store.text!).cards.length, 1);
    });

    testWidgets('a file that is not Anki says so and adds nothing', (t) async {
      final store = stored(fixture());
      final files = Files()
        ..bytes = ImportedBytes('notes.apkg', Uint8List.fromList([1, 2, 3]));
      await start(t, store: store, files: files);
      await tapKey(t, 'anki-open');
      expect(find.text('Nothing was added'), findsOneWidget);
      expect(find.textContaining('not an Anki package'), findsOneWidget);
      expect(parseRecallBackup(store.text!).cards.length, 1);
    });

    testWidgets('cancelling the picker goes back', (t) async {
      await start(t, store: stored(fixture()));
      await tapKey(t, 'anki-open');
      expect(find.byKey(const Key('anki-count')), findsNothing);
      expect(find.byKey(const Key('study-start')), findsOneWidget);
    });
  });

  group('cloze and reverse cards', () {
    testWidgets('select words, make a cloze, one card per blank', (t) async {
      final store = stored(fixture());
      await start(t, store: store, size: const Size(420, 1200));
      await tapKey(t, 'deck-deck');
      await tapKey(t, 'card-new');
      final field = find.byKey(const Key('card-front'));
      await t.enterText(field, 'Paris is in France');
      final editable = t.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      editable.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tapKey(t, 'card-cloze');
      editable.controller.selection = TextSelection(
        baseOffset: editable.controller.text.length - 6,
        extentOffset: editable.controller.text.length,
      );
      await tapKey(t, 'card-cloze');
      expect(editable.controller.text, '{{c1::Paris}} is in {{c2::France}}');
      expect(find.textContaining('Makes 2 cards'), findsOneWidget);
      // Cloze cards are asked one way: the reverse switch is off and says why.
      expect(find.textContaining('asked one way only'), findsOneWidget);
      await tapKey(t, 'card-save');
      final cards = parseRecallBackup(store.text!).cards;
      expect(cards.where((c) => c.cloze > 0).map((c) => c.cloze), [1, 2]);
    });

    testWidgets('Ctrl+Shift+C makes a cloze from the keyboard', (t) async {
      final store = stored(fixture());
      await start(t, store: store, size: const Size(1200, 900));
      await tapKey(t, 'deck-deck');
      await tapKey(t, 'card-new');
      await t.enterText(find.byKey(const Key('card-front')), 'H2O is water');
      final editable = t.widget<EditableText>(find.byType(EditableText).first);
      editable.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyC);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pump();
      expect(editable.controller.text, '{{c1::H2O}} is water');
    });

    testWidgets('review shows the blank with its hint, then fills it', (
      t,
    ) async {
      final s = saveNote(
        saveDeck(emptyRecallState(), const RecallDeck(id: 'g', name: 'Geo')),
        deckId: 'g',
        front: '{{c1::Paris}} is the capital of {{c2::France::country}}',
        back: 'Europe',
        newId: ids(),
        now: at(now.subtract(const Duration(hours: 1))),
      );
      await start(t, store: stored(s));
      await tapKey(t, 'study-start');
      final front = find.byKey(const Key('review-front'));
      String shown() =>
          (t.widget<SelectableText>(front).textSpan!).toPlainText();
      expect(
        shown(),
        anyOf(
          '[…] is the capital of France',
          'Paris is the capital of [country]',
        ),
      );
      await tapKey(t, 'review-show');
      expect(shown(), 'Paris is the capital of France');
      expect(find.text('Europe'), findsOneWidget);
    });

    testWidgets('a deck that makes reverse cards: two cards, asked apart', (
      t,
    ) async {
      final store = stored(
        saveDeck(
          emptyRecallState(),
          const RecallDeck(id: 'd', name: 'Words', reverse: true),
        ),
      );
      await start(t, store: store, size: const Size(420, 1200));
      await tapKey(t, 'deck-d');
      await tapKey(t, 'card-new');
      await t.enterText(find.byKey(const Key('card-front')), 'perro');
      await t.enterText(find.byKey(const Key('card-back')), 'dog');
      await tapKey(t, 'card-save');
      var cards = parseRecallBackup(store.text!).cards;
      expect(cards.length, 2);
      expect(cards.last.reversed, isTrue);
      // Turning it off on the card drops only the reverse card.
      await tapKey(t, 'card-${cards.first.id}');
      expect(find.textContaining('Asks the answer'), findsOneWidget);
      await tapKey(t, 'card-reverse');
      expect(
        find.textContaining('Saving removes the reverse card'),
        findsOneWidget,
      );
      await tapKey(t, 'card-save');
      cards = parseRecallBackup(store.text!).cards;
      expect(cards.single.reversed, isFalse);
    });

    testWidgets('deleting a card deletes its linked cards too', (t) async {
      final s = saveNote(
        saveDeck(emptyRecallState(), const RecallDeck(id: 'd', name: 'W')),
        deckId: 'd',
        front: 'a',
        back: 'b',
        reverse: true,
        newId: ids(),
      );
      final store = stored(s);
      await start(t, store: store);
      await tapKey(t, 'deck-d');
      await tapKey(t, 'card-${s.cards.first.id}');
      await tapKey(t, 'card-delete');
      expect(find.textContaining('1 linked cards'), findsOneWidget);
      await tapKey(t, 'confirm-action');
      expect(parseRecallBackup(store.text!).cards, isEmpty);
    });
  });

  group('read aloud', () {
    testWidgets('speakers read each side in its deck language', (t) async {
      final speaker = FakeSpeaker();
      await start(
        t,
        store: stored(japanese(front: 'ja-JP', back: 'vi-VN')),
        speaker: speaker,
      );
      await tapKey(t, 'study-start');
      expect(find.byKey(const Key('speak-answer')), findsNothing);
      await tapKey(t, 'speak-question');
      await tapKey(t, 'review-show');
      await tapKey(t, 'speak-answer');
      expect(speaker.spoken, [('水', 'ja-JP'), ('nước', 'vi-VN')]);
      // R reads the side in front of the reader.
      await t.sendKeyEvent(LogicalKeyboardKey.keyR);
      await t.pump();
      expect(speaker.spoken.last, ('nước', 'vi-VN'));
    });

    testWidgets('no speaker without a language; no voice says so', (t) async {
      await start(t, store: stored(japanese()));
      await tapKey(t, 'study-start');
      expect(find.byKey(const Key('speak-question')), findsNothing);
    });

    testWidgets('a missing voice is explained, not silent', (t) async {
      await start(
        t,
        store: stored(japanese(front: 'ko-KR')),
        speaker: FakeSpeaker(['en-US']),
      );
      await tapKey(t, 'study-start');
      await tapKey(t, 'speak-question');
      expect(find.textContaining('No voice for ko-KR'), findsOneWidget);
    });

    testWidgets('deck settings choose from the device voices', (t) async {
      final store = stored(japanese());
      await start(t, store: store);
      await tapKey(t, 'deck-jp');
      await tapKey(t, 'more-menu');
      await tapKey(t, 'deck-rename');
      await tapKey(t, 'deck-speak-front');
      await t.tap(find.text('Japanese · ja-JP').last);
      await t.pumpAndSettle();
      await tapKey(t, 'deck-reverse');
      await tapKey(t, 'deck-save');
      final deck = parseRecallBackup(store.text!).decks.single;
      expect(deck.speakFront, 'ja-JP');
      expect(deck.reverse, isTrue);
    });

    testWidgets('a device without voices says how to add one', (t) async {
      await start(t, store: stored(japanese()), speaker: FakeSpeaker([]));
      await tapKey(t, 'deck-new');
      expect(find.byKey(const Key('deck-no-voices')), findsOneWidget);
    });
  });
}
