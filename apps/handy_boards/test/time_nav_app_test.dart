import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/pro/pro.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart' hide clock;
import 'package:handy_ui/kit.dart';
import 'kanban_app_test.dart' show boot, settle, tap, studyState, board, clock;

// The test clock is Saturday 7 November 2026, 09:00.
final today = DateTime(clock.year, clock.month, clock.day);
DateTime ago(int days) => addDays(today, -days);

/// The study board plus one card with the given dates, in its first column.
(BoardsState, String) withCard(
  String title, {
  DateTime? planned,
  DateTime? due,
  bool history = true,
}) {
  var s = studyState();
  final t = newTask(s, board, title).copy({
    if (planned != null) 'scheduled': isoDay(planned),
    if (due != null) 'due': {'kind': 'day', 'day': isoDay(due)},
  });
  s = saveTask(s, t, now: clock.subtract(const Duration(days: 20)));
  if (!history) {
    s = s.remove('events', {
      for (final e in s.rows('events'))
        if (e.str('task') == t.id) e.id,
    });
  }
  return (s, t.id);
}

Future<void> openTime(WidgetTester t) async {
  await tap(t, find.byKey(const Key('board-$board')));
  await tap(t, find.text('Time'));
}

void main() {
  setUp(() {
    debugProOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.boards/share'),
          (call) async => call.method == 'drain' ? [] : true,
        );
  });

  testWidgets('Scenario A: a card planned last week moves to today with one '
      'tap; its column and deadline stay; Undo puts the plan back', (t) async {
    final (s, id) = withCard('Assignment 2', planned: ago(8), due: ago(6));
    final c = await boot(t, s);
    final status = s.get('tasks', id).str('status');
    await openTime(t);
    // The carry-over tray holds it, with the move right on the card.
    expect(find.text('Still open from before'), findsOneWidget);
    expect(find.textContaining('Overdue'), findsWidgets);
    await tap(t, find.byKey(Key('time-now-$id')));
    final card = c.state!.get('tasks', id);
    expect(card.str('scheduled'), isoDay(today));
    expect(card.str('status'), status);
    expect(dueDay(card), ago(6));
    expect(find.text('Planned for today'), findsOneWidget);
    await tap(t, find.text('Undo'));
    expect(c.state!.get('tasks', id).str('scheduled'), isoDay(ago(8)));
    expect(
      cardHistory(c.state!, id).map((e) => e.data['details']['reason']),
      containsAllInOrder(['move to now', 'undo']),
    );
  });

  testWidgets('Scenario C: a deadline-only card asks first and keeps its '
      'deadline', (t) async {
    final (s, id) = withCard('Quiz', due: ago(2));
    final c = await boot(t, s);
    await openTime(t);
    await tap(t, find.byKey(Key('time-now-$id')));
    expect(find.byKey(const Key('due-only-plan')), findsOneWidget);
    expect(find.textContaining('the due date stays'), findsOneWidget);
    await tap(t, find.byKey(const Key('due-only-plan')));
    final card = c.state!.get('tasks', id);
    expect(card.str('scheduled'), isoDay(today));
    expect(dueDay(card), ago(2));
  });

  testWidgets('Scenario B: a card planned next week is done early from the '
      'next window, without touching its deadline', (t) async {
    final next = addDays(mondayOf(today), 9);
    final (s, id) = withCard('Report', planned: next, due: addDays(next, 5));
    final c = await boot(t, s);
    await openTime(t);
    // A neutral marker points at it; Next goes there.
    expect(find.textContaining('Next:'), findsOneWidget);
    await tap(t, find.byKey(const Key('time-next')));
    await tap(t, find.byKey(Key('time-early-$id')));
    final card = c.state!.get('tasks', id);
    expect(card.str('scheduled'), isoDay(today));
    expect(dueDay(card), addDays(next, 5));
  });

  testWidgets('markers lead back; the backlog moves everything at once', (
    t,
  ) async {
    final (s0, a) = withCard('Old one', planned: ago(12));
    final b = newTask(s0, board, 'Older').copy({'scheduled': isoDay(ago(20))});
    final s = saveTask(s0, b, now: clock);
    final c = await boot(t, s);
    await openTime(t);
    // Last week (12 days ago) and three weeks back (20 days ago).
    expect(find.byKey(const Key('time-mark--1')), findsOneWidget);
    expect(find.byKey(const Key('time-mark--2')), findsNothing);
    expect(find.byKey(const Key('time-mark--3')), findsOneWidget);
    await tap(t, find.byKey(const Key('time-mark--1')));
    expect(find.byKey(Key('time-now-$a')), findsOneWidget);
    await tap(t, find.byKey(const Key('time-backlog')));
    expect(find.text('Still open from before'), findsWidgets);
    await tap(t, find.byKey(const Key('backlog-move')));
    expect(c.state!.get('tasks', a).str('scheduled'), isoDay(today));
    expect(c.state!.get('tasks', b.id).str('scheduled'), isoDay(today));
    expect(find.byKey(const Key('backlog-empty')), findsOneWidget);
  });

  testWidgets('Scenario D: two days, two months and a custom span step '
      'without gaps', (t) async {
    final c = await boot(t, studyState());
    await openTime(t);
    await tap(t, find.byKey(const Key('time-span')));
    await tap(t, find.byKey(const Key('span-day-2')));
    expect(c.state!.get('boards', board).data['span'], {
      'unit': 'day',
      'count': 2,
    });
    expect(find.text('Sat 7/11 – 8/11'), findsNothing);
    expect(find.text('7/11 – 8/11'), findsOneWidget);
    await tap(t, find.byKey(const Key('time-next')));
    expect(find.text('9/11 – 10/11'), findsOneWidget);
    await tap(t, find.byKey(const Key('time-span')));
    await tap(t, find.byKey(const Key('span-month-2')));
    expect(find.text('1/11 – 31/12'), findsOneWidget);
    await tap(t, find.byKey(const Key('time-next')));
    expect(find.text('1/1 – 28/2/2027'), findsOneWidget);
    // Custom, from - to: from the first day on screen, 14 days inclusive.
    await tap(t, find.byKey(const Key('time-today')));
    final start = DateTime(today.year, today.month);
    await tap(t, find.byKey(const Key('time-span')));
    await tap(t, find.byKey(const Key('span-custom')));
    await tap(t, find.text('From – to'));
    expect(find.textContaining('14 days'), findsOneWidget);
    await tap(t, find.byKey(const Key('span-apply')));
    expect(c.state!.get('boards', board).data['span'], {
      'unit': 'custom',
      'first': isoDay(start),
      'last': isoDay(addDays(start, 13)),
    });
    await tap(t, find.byKey(const Key('time-next')));
    final from = addDays(start, 14), to = addDays(start, 27);
    expect(
      find.text('${from.day}/${from.month} – ${to.day}/${to.month}'),
      findsOneWidget,
    );
  });

  testWidgets('a card plan is set apart from its due date, and its history '
      'tells what happened', (t) async {
    final (s, id) = withCard('Essay', due: addDays(today, 5));
    final c = await boot(t, s);
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.text('Essay'));
    expect(find.byKey(const Key('card-planned')), findsOneWidget);
    expect(find.text('Plan a day'), findsOneWidget);
    // History from its creation.
    await t.ensureVisible(find.byKey(const Key('card-history')));
    await tap(t, find.byKey(const Key('card-history')));
    expect(find.byKey(const Key('history-list')), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.byKey(const Key('history-partial')), findsNothing);
    expect(c.state!.get('tasks', id).data['scheduled'], isNull);
  });

  testWidgets('a card from before history keeping says so', (t) async {
    final (s, _) = withCard('Old card', history: false);
    await boot(t, s);
    await tap(t, find.byKey(const Key('board-$board')));
    await tap(t, find.text('Old card'));
    await t.ensureVisible(find.byKey(const Key('card-history')));
    await tap(t, find.byKey(const Key('card-history')));
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    expect(find.textContaining('from this version on'), findsOneWidget);
  });

  testWidgets('dropping a card on a day still sets its due day', (t) async {
    final (s, id) = withCard('Drag me', due: addDays(mondayOf(today), 3));
    final c = await boot(t, s, size: const Size(1280, 800));
    await openTime(t);
    final target = find.byKey(const Key('time-d2'));
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    final g = await t.startGesture(
      t.getCenter(find.byKey(ValueKey('time-card-$id'))),
    );
    await t.pump(const Duration(milliseconds: 700));
    await g.moveTo(t.getCenter(target));
    await t.pump();
    await g.up();
    await settle(t);
    final monday = mondayOf(today);
    expect(dueDay(c.state!.get('tasks', id)), addDays(monday, 2));
    expect(c.state!.get('tasks', id).data['scheduled'], isNull);
  });
}
