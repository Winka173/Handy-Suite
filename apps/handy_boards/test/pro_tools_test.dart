import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/pro/pro.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart' hide clock;
import 'package:handy_ui/kit.dart';
import 'kanban_app_test.dart' show boot, tap, menuTap, studyState, board, clock;

final today = DateTime(clock.year, clock.month, clock.day);

void main() {
  setUp(() {
    debugProOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.boards/share'),
          (call) async => call.method == 'drain' ? [] : true,
        );
  });

  testWidgets('a card saved as a template makes fresh cards in any column', (
    t,
  ) async {
    debugProOverride = true;
    final s = studyState();
    final card = topTasks(s, board: board).first;
    final c = await boot(t, s);
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.text(card.str('title')).first);
    await tap(t, find.byKey(const Key('card-more')));
    await menuTap(t, 'menu-save-template');
    await tap(t, find.byKey(const Key('ask-text-save')));
    expect(cardTemplates(c.state!), hasLength(1));
    // Close the card if it is still open; stay on the board.
    if (find.byKey(const Key('card-more')).evaluate().isNotEmpty) {
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
    }
    expect(find.byKey(const Key('kanban-pages')), findsOneWidget);
    // Let the "Saved" bar go: it sits over the column's foot.
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    // Back to the first column on the phone's paged board.
    await t.fling(
      find.byKey(const Key('kanban-pages')),
      const Offset(800, 0),
      2000,
    );
    await t.pumpAndSettle();
    final col = columnsOf(c.state!, board).first.id;
    final before = cardsIn(c.state!, col).length;
    // Tapped in place: scrolling would page the phone's columns away.
    await t.tap(find.byKey(Key('add-from-template-$col')));
    await t.pumpAndSettle();
    final tpl = cardTemplates(c.state!).single.id;
    await tap(t, find.byKey(Key('card-template-$tpl')));
    expect(cardsIn(c.state!, col), hasLength(before + 1));
    expect(cardsIn(c.state!, col).first.id, isNot(card.id));
  });

  testWidgets('without Pro the templates list is shown and making one asks', (
    t,
  ) async {
    var s = studyState();
    s = saveCardTemplate(s, title: 'Weekly review', now: clock);
    final c = await boot(t, s);
    await tap(t, find.byKey(const Key('board-$board')));
    final col = columnsOf(c.state!, board).first.id;
    // Tapped in place: scrolling would page the phone's columns away.
    await t.tap(find.byKey(Key('add-from-template-$col')));
    await t.pumpAndSettle();
    expect(find.text('Weekly review'), findsOneWidget);
    await tap(t, find.text('Weekly review'));
    expect(find.text('Pay once. Keep it.'), findsOneWidget);
    expect(
      topTasks(
        c.state!,
        board: board,
      ).where((x) => x.str('title') == 'Weekly review'),
      isEmpty,
    );
  });

  testWidgets('My Work lists every board; a move changes the card itself', (
    t,
  ) async {
    var s = studyState();
    final old = newTask(
      s,
      board,
      'Left from Monday',
    ).copy({'scheduled': isoDay(addDays(today, -5))});
    s = saveTask(s, old, now: clock);
    // Without Pro: visible, acting asks.
    final c = await boot(t, s);
    await tap(t, find.byKey(const Key('home-my-work')));
    expect(find.byKey(const Key('work-unlock')), findsOneWidget);
    expect(find.text('Left from Monday'), findsOneWidget);
    debugProOverride = true;
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(Key('work-move-${old.id}')));
    await tap(t, find.byKey(Key('work-move-${old.id}')));
    expect(c.state!.get('tasks', old.id).str('scheduled'), isoDay(today));
  });

  testWidgets('automatic carry-over is previewed, then runs once a day', (
    t,
  ) async {
    debugProOverride = true;
    var s = studyState();
    final old = newTask(
      s,
      board,
      'Planned Tuesday',
    ).copy({'scheduled': isoDay(addDays(today, -4))});
    s = saveTask(s, old, now: clock);
    final c = await boot(t, s);
    await tap(t, find.byKey(const Key('home-settings')));
    await t.scrollUntilVisible(
      find.byKey(const Key('settings-carry-over')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(t, find.byKey(const Key('settings-carry-over')));
    await tap(t, find.byKey(const Key('carry-auto')));
    expect(find.textContaining('move 1 cards'), findsOneWidget);
    await tap(t, find.byKey(const Key('carry-confirm')));
    expect(c.state!.preferences['carryOver'], {'mode': 'auto'});
    // The next start moves it, once.
    final run = runCarryOver(c.state!, clock, now: clock);
    expect(run.state.get('tasks', old.id).str('scheduled'), isoDay(today));
    expect(runCarryOver(run.state, clock, now: clock).state, same(run.state));
  });

  testWidgets('custom fields: Pro adds them; values show on the card', (
    t,
  ) async {
    final s = studyState();
    final c = await boot(t, s);
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-more')));
    await menuTap(t, 'menu-fields');
    await tap(t, find.byKey(const Key('field-add')));
    // Free: asked for Pro, nothing made.
    expect(find.text('Pay once. Keep it.'), findsOneWidget);
    expect(fieldsOf(c.state!, board), isEmpty);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    debugProOverride = true;
    await t.pumpAndSettle();
    await tap(t, find.byKey(const Key('field-add')));
    await t.enterText(find.byKey(const Key('field-name')), 'Points');
    await tap(t, find.byKey(const Key('field-save')));
    expect(fieldsOf(c.state!, board).single.str('title'), 'Points');
  });
}
