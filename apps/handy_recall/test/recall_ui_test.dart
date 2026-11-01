import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_recall_app/occlusion_editor.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

void main() {
  testWidgets('today leads with what is due and starts the review', (
    tester,
  ) async {
    await start(tester, store: stored(fixture()));
    expect(find.text('Due today'), findsOneWidget);
    expect(find.byKey(const Key('study-start')), findsOneWidget);
    expect(find.byKey(const Key('deck-review-deck')), findsOneWidget);
    await tapKey(tester, 'study-start');
    expect(find.byKey(const Key('review-front')), findsOneWidget);
  });

  testWidgets('study uses actual scheduler and persists before advancing', (
    tester,
  ) async {
    final store = stored(fixture());
    await start(tester, store: store);
    await tapKey(tester, 'deck-deck');
    await tapKey(tester, 'deck-study');
    expect(find.text('Answer'), findsNothing);
    await tapKey(tester, 'review-show');
    expect(find.text('Answer'), findsOneWidget);
    // The grade says when the card comes back, from the real scheduler.
    expect(
      find.descendant(
        of: find.byKey(const Key('grade-good')),
        matching: find.text('1 day'),
      ),
      findsOneWidget,
    );
    await tapKey(tester, 'grade-good');
    expect(parseRecallBackup(store.text!).cards.single.reviewCount, 1);
    expect(find.textContaining('Next: 1 cards tomorrow'), findsOneWidget);
    expect(find.text('Done for now'), findsOneWidget);
  });

  testWidgets('failed persistence retains question and old schedule', (
    tester,
  ) async {
    final store = stored(fixture())..fail = true;
    await start(tester, store: store);
    await tapKey(tester, 'study-start');
    await tapKey(tester, 'review-show');
    await tapKey(tester, 'grade-good');
    expect(parseRecallBackup(store.text!).cards.single.reviewCount, 0);
    expect(find.textContaining('disk unavailable'), findsOneWidget);
    expect(find.text('Question'), findsOneWidget);
    expect(find.byKey(const Key('grade-good')), findsOneWidget);
  });

  testWidgets('keys work on desktop: Space shows, 3 grades Good', (
    tester,
  ) async {
    final store = stored(fixture());
    await start(tester, store: store, size: const Size(1280, 900));
    await tapKey(tester, 'study-start');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('Answer'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pumpAndSettle();
    expect(parseRecallBackup(store.text!).cards.single.reviewCount, 1);
  });

  testWidgets(
    'multiple image masks render and answer reveal removes every mask',
    (tester) async {
      final png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLttAAAAABJRU5ErkJggg==';
      final image = RecallImage(
        dataUri: png,
        masks: const [
          OcclusionMask(x: 0, y: 0, width: 0.2, height: 0.2),
          OcclusionMask(x: 0.5, y: 0.5, width: 0.3, height: 0.3),
        ],
      );
      Future<void> show(bool hidden) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHandyTheme(const Color(0xFF4D7C0F), Brightness.light),
            home: Scaffold(
              body: SingleChildScrollView(
                child: OcclusionCanvas(image: image, hidden: hidden),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(true);
      expect(find.byType(Positioned), findsNWidgets(3));
      await show(false);
      expect(find.byType(Positioned), findsOneWidget);
    },
  );

  testWidgets(
    'corrupt persisted data is visible and never overwritten by defaults',
    (tester) async {
      final store = Store()..text = '{broken';
      await start(tester, store: store);
      expect(find.text('Recall could not read your library'), findsOneWidget);
      expect(store.text, '{broken');
    },
  );

  testWidgets('a CSV adds cards to the deck; a bad file adds none', (
    tester,
  ) async {
    final store = stored(fixture());
    final files = Files()
      ..input = ImportedText(
        'cards.csv',
        'front,back\nhola,xin chào\nadiós,tạm biệt\n',
      );
    await start(tester, store: store, files: files);
    await tapKey(tester, 'deck-deck');
    await tapKey(tester, 'more-menu');
    await tapKey(tester, 'deck-import');
    expect(parseRecallBackup(store.text!).cards.length, 3);
    expect(find.text('hola'), findsOneWidget);
    files.input = ImportedText('bad.csv', 'not,a,card,file');
    await tapKey(tester, 'more-menu');
    await tapKey(tester, 'deck-import');
    expect(parseRecallBackup(store.text!).cards.length, 3);
  });

  testWidgets('deleting a deck asks first and takes its cards', (tester) async {
    final store = stored(fixture());
    await start(tester, store: store);
    await tapKey(tester, 'deck-deck');
    await tapKey(tester, 'more-menu');
    await tapKey(tester, 'deck-delete');
    expect(parseRecallBackup(store.text!).decks.length, 1);
    await tapKey(tester, 'confirm-action');
    final s = parseRecallBackup(store.text!);
    expect((s.decks.length, s.cards.length), (0, 0));
    expect(find.byKey(const Key('deck-first')), findsOneWidget);
  });
}
