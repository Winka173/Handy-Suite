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

Future<void> openBoard(WidgetTester t) =>
    tap(t, find.byKey(const Key('board-$board')));

Future<void> cardMenuOf(WidgetTester t, String id) async {
  await t.ensureVisible(find.byKey(Key('card-menu-$id')));
  await t.pumpAndSettle();
  await tap(t, find.byKey(Key('card-menu-$id')));
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

  testWidgets('a board with dates opens on this week; work left from before '
      'stays in sight and moves to today in one tap; Undo puts it back', (
    t,
  ) async {
    final (s, id) = withCard('Assignment 2', planned: ago(8), due: ago(6));
    final c = await boot(t, s, size: const Size(1280, 900));
    final status = s.get('tasks', id).str('status');
    await openBoard(t);
    expect(find.byKey(const Key('week-bar')), findsOneWidget);
    expect(find.text('Assignment 2'), findsOneWidget);
    expect(find.textContaining('late'), findsWidgets);
    expect(find.text('1 still open from before'), findsOneWidget);
    await tap(t, find.byKey(const Key('backlog-today')));
    final card = c.state!.get('tasks', id);
    expect(card.str('scheduled'), isoDay(today));
    expect(card.str('status'), status);
    expect(dueDay(card), ago(6));
    expect(find.byKey(const Key('backlog-line')), findsNothing);
    await tap(t, find.text('Undo'));
    expect(c.state!.get('tasks', id).str('scheduled'), isoDay(ago(8)));
  });

  testWidgets('next week shows what is planned then; card ⋯ › Do it today '
      'moves only the plan, never the deadline', (t) async {
    final next = addDays(mondayOf(today), 9);
    final (s, id) = withCard('Report', planned: next, due: addDays(next, 5));
    final c = await boot(t, s, size: const Size(1280, 900));
    await openBoard(t);
    expect(find.text('Report'), findsNothing);
    await tap(t, find.byKey(const Key('week-next')));
    expect(find.text('Report'), findsOneWidget);
    expect(find.byKey(const Key('week-current')), findsOneWidget);
    await cardMenuOf(t, id);
    await tap(t, find.byKey(const Key('menu-do-today')));
    final card = c.state!.get('tasks', id);
    expect(card.str('scheduled'), isoDay(today));
    expect(dueDay(card), addDays(next, 5));
    // Back to this week, where it now is.
    await tap(t, find.byKey(const Key('week-current')));
    expect(find.text('Report'), findsOneWidget);
  });

  testWidgets('a card with only a deadline asks first and keeps it', (t) async {
    final (s, id) = withCard('Quiz', due: ago(2));
    final c = await boot(t, s, size: const Size(1280, 900));
    await openBoard(t);
    await cardMenuOf(t, id);
    await tap(t, find.byKey(const Key('menu-do-today')));
    expect(find.byKey(const Key('due-only-plan')), findsOneWidget);
    await tap(t, find.byKey(const Key('due-only-plan')));
    final card = c.state!.get('tasks', id);
    expect(card.str('scheduled'), isoDay(today));
    expect(dueDay(card), ago(2));
  });

  testWidgets('cards with no date show in this week only; All shows every '
      'card; the planned day can be taken off', (t) async {
    final (s0, undated) = withCard('Someday');
    var s = s0;
    final dated = newTask(
      s,
      board,
      'Later',
    ).copy({'scheduled': isoDay(addDays(today, 30))});
    s = saveTask(s, dated, now: clock);
    final c = await boot(t, s, size: const Size(1280, 900));
    await openBoard(t);
    expect(find.text('Someday'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    await tap(t, find.byKey(const Key('week-next')));
    expect(find.text('Someday'), findsNothing);
    await tap(t, find.byKey(const Key('week-all')));
    expect(find.text('Someday'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('All cards'), findsOneWidget);
    await cardMenuOf(t, dated.id);
    await tap(t, find.byKey(const Key('menu-unplan')));
    expect(c.state!.get('tasks', dated.id).data['scheduled'], isNull);
    expect(c.state!.maybe('tasks', undated), isNotNull);
  });

  testWidgets('a card names its days: "Do:" for the plan, "Due:" for the '
      'deadline', (t) async {
    final (s, _) = withCard('Lab', planned: today, due: addDays(today, 1));
    await boot(t, s, size: const Size(1280, 900));
    await openBoard(t);
    expect(find.text('Do: Today'), findsOneWidget);
    expect(find.text('Due: Tomorrow'), findsOneWidget);
  });

  testWidgets('a board with no dates has no week bar and shows every card', (
    t,
  ) async {
    var s = studyState();
    for (final c in s.rows('tasks').toList()) {
      s = s.put('tasks', c.copy({'due': null, 'scheduled': null}));
    }
    await boot(t, s);
    await openBoard(t);
    expect(find.byKey(const Key('week-bar')), findsNothing);
  });

  testWidgets('a card plan is set apart from its due date, and its history '
      'tells what happened', (t) async {
    // Due tomorrow: inside the week the board opens on.
    final (s, id) = withCard('Essay', due: addDays(today, 1));
    final c = await boot(t, s, size: const Size(1280, 900));
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
}
