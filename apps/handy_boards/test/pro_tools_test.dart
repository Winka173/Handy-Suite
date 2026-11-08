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

  testWidgets('without Pro, From my templates opens the Pro page first', (
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
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    // The card template's own demo may say "Weekly review"; no card was
    // made (checked on the board's data below).
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
    // Without Pro: the Pro page opens instead.
    final c = await boot(t, s);
    await tap(t, find.byKey(const Key('home-my-work')));
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    debugProOverride = true;
    await tap(t, find.byKey(const Key('home-my-work')));
    expect(find.text('Left from Monday'), findsOneWidget);
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
    // Free: the Pro page opens at once, not the fields first.
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    expect(find.byKey(const Key('field-add')), findsNothing);
    // Only the field the template suggested.
    expect(fieldsOf(c.state!, board).map((f) => f.str('title')), ['Grade']);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    debugProOverride = true;
    await tap(t, find.byKey(const Key('board-more')));
    await menuTap(t, 'menu-fields');
    await tap(t, find.byKey(const Key('field-add')));
    await t.enterText(find.byKey(const Key('field-name')), 'Points');
    await tap(t, find.byKey(const Key('field-save')));
    expect(fieldsOf(c.state!, board).map((f) => f.str('title')), [
      'Grade',
      'Points',
    ]);
  });

  testWidgets('a field that came with the template is free to fill, right '
      'in the card', (t) async {
    final s = studyState();
    final c = await boot(t, s, size: const Size(1280, 900));
    await tap(t, find.byKey(const Key('board-$board')));
    final grade = fieldsOf(c.state!, board).single;
    final card = topTasks(c.state!, board: board).first;
    await tap(t, find.byKey(ValueKey('card-${card.id}')));
    await t.ensureVisible(find.byKey(const Key('card-fields')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('card-fields-add')), findsOneWidget);
    await tap(t, find.byKey(Key('card-field-${grade.id}')));
    expect(find.byKey(const Key('pro-page')), findsNothing);
    await t.enterText(find.byType(TextField).last, '9');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    final saved = object(c.state!.get('tasks', card.id).data['custom'] ?? {});
    expect('${saved[grade.id]}', '9');
  });

  testWidgets('board history: Pro opens a read-only day-by-day list of '
      'what happened', (t) async {
    final s = studyState();
    final c = await boot(t, s);
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-more')));
    await menuTap(t, 'menu-board-history');
    expect(find.byKey(const Key('pro-page')), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    debugProOverride = true;
    await tap(t, find.byKey(const Key('board-more')));
    await menuTap(t, 'menu-board-history');
    expect(find.byKey(const Key('board-history')), findsOneWidget);
    expect(boardHistory(c.state!, board), isNotEmpty);
    expect(find.textContaining('Due date'), findsWidgets);
    await tap(t, find.text('All'));
    // Read only: tapping a line changes nothing and goes nowhere.
    final before = c.state;
    await t.tap(find.textContaining('Due date').first, warnIfMissed: false);
    await t.pumpAndSettle();
    expect(identical(c.state, before), isTrue);
    expect(find.byKey(const Key('board-history')), findsOneWidget);
  });

  testWidgets('a saved filter narrows the board; a custom repeat is kept', (
    t,
  ) async {
    debugProOverride = true;
    var s = studyState();
    final cat = categoriesOf(s, board).first;
    s = saveFilter(s, board, 'First subject', [
      {'category': cat.id},
    ]);
    final c = await boot(t, s);
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.byKey(const Key('board-filters')));
    final f = savedFilters(c.state!, board).single;
    await tap(t, find.byKey(Key('filter-${f.id}')));
    expect(find.text('First subject'), findsOneWidget);
    final shown = topTasks(
      c.state!,
      board: board,
    ).where((x) => x.data['category'] == cat.id).first;
    final hidden = topTasks(
      c.state!,
      board: board,
    ).where((x) => x.data['category'] != cat.id).first;
    expect(find.text(shown.str('title')), findsWidgets);
    expect(find.text(hidden.str('title')), findsNothing);
    // Custom repeat on that card: every 2 weeks.
    await tap(t, find.text(shown.str('title')).first);
    await tap(t, find.byKey(const Key('card-repeat')));
    await tap(t, find.byKey(const Key('card-repeat-custom')));
    await tap(t, find.byKey(const Key('repeat-more')));
    await tap(t, find.byKey(const Key('repeat-save')));
    final card = c.state!.get('tasks', shown.id);
    expect(card.str('repeat'), 'weekly');
    expect(card.data['repeatEvery'], 2);
  });
}
