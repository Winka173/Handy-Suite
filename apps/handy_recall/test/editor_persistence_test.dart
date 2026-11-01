import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_recall_app/app.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

const date = '2025-10-31T08:00:00.000Z';
RecallCard fixtureCard() => createCard(
  id: 'existing-card',
  deckId: 'deck',
  front: 'Original question',
  back: 'Original answer',
  now: date,
);

Future<void> openEditor(
  WidgetTester tester,
  Future<void> Function(RecallCard) save, {
  Files? files,
  bool newCard = false,
}) async {
  tester.view.physicalSize = const Size(420, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHandyTheme(recallAccent, Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CardEditor(
                  card: newCard ? null : fixtureCard(),
                  deckId: 'deck',
                  files: files ?? Files(),
                  onCommit: save,
                ),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

Future<void> question(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('card-front')), text);
  await tester.pump();
}

void main() {
  testWidgets(
    'deck modal preserves draft on failed write and retry stores it',
    (tester) async {
      final store = Store()..fail = true;
      await start(tester, store: store);
      await tapKey(tester, 'deck-first');
      await tester.enterText(find.byKey(const Key('deck-name')), 'Study draft');
      await tapKey(tester, 'deck-save');
      expect(find.byKey(const Key('deck-name')), findsOneWidget);
      expect(find.textContaining('disk unavailable'), findsOneWidget);
      expect(store.text, isNull);
      store.fail = false;
      await tapKey(tester, 'deck-save');
      expect(find.byKey(const Key('deck-name')), findsNothing);
      expect(find.text('Study draft'), findsOneWidget);
      expect(store.text, contains('Study draft'));
    },
  );

  testWidgets(
    'failed persistence retains card draft and retry commits once before closing',
    (tester) async {
      var fail = true, calls = 0;
      RecallCard? committed;
      await openEditor(tester, (card) async {
        calls++;
        if (fail) throw Exception('disk full');
        committed = card;
      });
      await question(tester, 'Edited question');
      await tapKey(tester, 'card-save');
      expect(find.byType(CardEditor), findsOneWidget);
      expect(find.textContaining('disk full'), findsOneWidget);
      expect(find.text('Edited question'), findsOneWidget);
      expect(committed, isNull);
      expect(calls, 1);
      fail = false;
      await tapKey(tester, 'card-save');
      expect(find.byType(CardEditor), findsNothing);
      expect(committed!.id, 'existing-card');
      expect(committed!.front, 'Edited question');
      expect(committed!.dueAt, date);
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending persistence blocks duplicate save, edits and hardware Back',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await openEditor(tester, (_) async {
        calls++;
        await pending.future;
      });
      await question(tester, 'Pending draft');
      await tapKey(tester, 'card-save', settle: false);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('card-save')))
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('card-front'))).enabled,
        isFalse,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(CardEditor), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CardEditor), findsNothing);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dirty hardware Back keeps draft or discards after PopScope rebuild',
    (tester) async {
      var calls = 0;
      await openEditor(tester, (_) async => calls++);
      await question(tester, 'Unsaved');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      expect(find.byType(CardEditor), findsNothing);
      expect(calls, 0);
    },
  );

  testWidgets('invalid card does not attempt persistence or leave editor', (
    tester,
  ) async {
    var calls = 0;
    await openEditor(tester, (_) async => calls++);
    await question(tester, '');
    await tapKey(tester, 'card-save');
    expect(find.byType(CardEditor), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('pending file picker blocks Back until operation resolves', (
    tester,
  ) async {
    final files = Files()..pending = Completer<ImportedBytes?>();
    await openEditor(tester, (_) async {}, files: files);
    await tapKey(tester, 'card-image', settle: false);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(CardEditor), findsOneWidget);
    files.pending!.complete(null);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CardEditor), findsNothing);
  });

  testWidgets('save, add another keeps the editor open and empty', (
    tester,
  ) async {
    final saved = <RecallCard>[];
    await openEditor(tester, (c) async => saved.add(c), newCard: true);
    for (final (q, a) in [('hola', 'xin chào'), ('gracias', 'cảm ơn')]) {
      await question(tester, q);
      await tester.enterText(find.byKey(const Key('card-back')), a);
      await tapKey(tester, 'card-save-next');
      expect(find.byType(CardEditor), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('card-front')))
            .controller!
            .text,
        isEmpty,
      );
    }
    expect(saved.map((c) => c.front), ['hola', 'gracias']);
    expect(find.text('2 saved'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byType(CardEditor),
      findsNothing,
      reason: 'nothing unsaved to ask about',
    );
  });
}
