import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/pro/pro.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart' hide clock;
import 'package:handy_ui/kit.dart';
import 'kanban_app_test.dart' show boot, tap, studyState, board, clock;

// The test clock is Saturday 7 November 2026, 09:00.
final today = DateTime(clock.year, clock.month, clock.day);
DateTime ago(int days) => addDays(today, -days);

/// The study board plus one card with the given dates, in its first column.
(BoardsState, String) withCard(
  String title, {
  DateTime? planned,
  DateTime? due,
  bool history = true,
  String? timeline,
}) {
  // The study template starts on a weekly timeline; most tests here look
  // at a card's own days on a plain board.
  var s = setTimeline(studyState(), board, timeline, now: clock);
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
    expect(find.byKey(const Key('week-bar')), findsNothing);
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

  testWidgets('on a weekly timeline, next week shows what is planned then, '
      'and a card added there is planned for that week', (t) async {
    final next = addDays(mondayOf(today), 9);
    final (s, id) = withCard('Report', planned: next, timeline: 'week');
    final c = await boot(t, s, size: const Size(1280, 900));
    await openBoard(t);
    expect(find.text('Report'), findsNothing);
    await tap(t, find.byKey(const Key('week-next')));
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Ahead'), findsOneWidget);
    final todo = columnsOf(c.state!, board).first;
    await tap(t, find.byKey(Key('add-card-open-${todo.id}')));
    await t.enterText(find.byKey(Key('add-card-${todo.id}')), 'Plan slides');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    final added = topTasks(
      c.state!,
      board: board,
    ).firstWhere((x) => x.str('title') == 'Plan slides');
    expect(scheduledDay(added), addDays(mondayOf(today), 7));
    expect(c.state!.get('tasks', id).str('scheduled'), isoDay(next));
    await tap(t, find.byKey(const Key('week-current')));
    expect(find.text('Plan slides'), findsNothing);
  });

  testWidgets('a week gone by is read only: unfinished cards are marked and '
      'brought to this week one by one or all at once; Undo puts them back', (
    t,
  ) async {
    final (s, id) = withCard('Assignment 2', planned: ago(8), timeline: 'week');
    final c = await boot(t, s, size: const Size(1280, 900));
    await openBoard(t);
    // This week says what is left from before.
    expect(find.text('1 not finished from earlier weeks'), findsOneWidget);
    await tap(t, find.byKey(const Key('week-prev')));
    expect(find.text('Gone by · read only'), findsOneWidget);
    expect(find.text('Assignment 2'), findsOneWidget);
    expect(find.byKey(Key('card-carry-$id')), findsOneWidget);
    expect(find.textContaining('Add card'), findsNothing);
    expect(find.byKey(Key('card-menu-$id')), findsNothing);
    // Opening it reads it, with its two actions.
    await tap(t, find.text('Assignment 2'));
    expect(find.byKey(const Key('card-past-banner')), findsOneWidget);
    await tap(t, find.byKey(const Key('past-carry')));
    expect(c.state!.get('tasks', id).str('scheduled'), isoDay(today));
    expect(find.text('Assignment 2'), findsNothing);
    await tap(t, find.text('Undo'));
    expect(c.state!.get('tasks', id).str('scheduled'), isoDay(ago(8)));
    await tap(t, find.byKey(const Key('carry-all')));
    expect(c.state!.get('tasks', id).str('scheduled'), isoDay(today));
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

  testWidgets('the Time chip turns the timeline on in one tap and brings '
      'open work to now; a shorter unit is never offered after a longer one', (
    t,
  ) async {
    final (s, id) = withCard('Old task', planned: ago(8));
    final c = await boot(t, s, size: const Size(1280, 900));
    await openBoard(t);
    expect(find.byKey(const Key('week-bar')), findsNothing);
    await tap(t, find.byKey(const Key('board-timeline')));
    await tap(t, find.byKey(const Key('timeline-month')));
    expect(boardTimeline(c.state!.get('boards', board)), 'month');
    expect(c.state!.get('tasks', id).str('scheduled'), isoDay(today));
    expect(find.byKey(const Key('week-bar')), findsOneWidget);
    expect(find.text('By month'), findsOneWidget);
    await tap(t, find.byKey(const Key('board-timeline')));
    final week = t.widget<ListTile>(find.byKey(const Key('timeline-week')));
    expect(week.enabled, isFalse);
    // Off asks first, and may archive what was finished earlier.
    await tap(t, find.byKey(const Key('timeline-off')));
    expect(find.byKey(const Key('timeline-off-confirm')), findsOneWidget);
    await tap(t, find.byKey(const Key('timeline-off-confirm')));
    expect(boardTimeline(c.state!.get('boards', board)), isNull);
    expect(find.byKey(const Key('week-bar')), findsNothing);
  });

  testWidgets('a card names its days: "Do:" for the plan, "Due:" for the '
      'deadline', (t) async {
    final (s, _) = withCard('Lab', planned: today, due: addDays(today, 1));
    await boot(t, s, size: const Size(1280, 900));
    await openBoard(t);
    expect(find.text('Do: Today'), findsOneWidget);
    expect(find.text('Due: Tomorrow'), findsOneWidget);
  });

  testWidgets('a board off the timeline has no week bar', (t) async {
    var s = setTimeline(studyState(), board, null, now: clock);
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
