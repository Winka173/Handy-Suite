import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'time_nav_test.dart' show study, card, done, now, today, board, d;

void main() {
  test('a card sits in the period of its plan, else of the day it was made, '
      'never of its deadline', () {
    var s = study();
    final String planned, made, dueOnly;
    (s, planned) = card(s, 'Planned', planned: d(2026, 11, 20));
    (s, made) = card(s, 'Made');
    (s, dueOnly) = card(s, 'Due', due: d(2026, 12, 1));
    expect(cardDay(s.get('tasks', planned)), d(2026, 11, 20));
    // card() saves 30 days before now: 10 October.
    expect(cardDay(s.get('tasks', made)), d(2026, 10, 10));
    expect(cardDay(s.get('tasks', dueOnly)), d(2026, 10, 10));
  });

  test('turning the timeline on brings open work from earlier periods to '
      'today; finished and later cards stay', () {
    var s = study();
    final String old, later, finished;
    (s, old) = card(s, 'Old');
    (s, later) = card(s, 'Later', planned: d(2026, 11, 25));
    (s, finished) = card(s, 'Finished', column: 0);
    s = moveCard(s, finished, column: done(s), index: 0, now: now);
    s = setTimeline(s, board, 'week', now: now);
    final b = s.get('boards', board);
    expect(boardTimeline(b), 'week');
    expect(timelineFloor(b), 'week');
    expect(scheduledDay(s.get('tasks', old)), today);
    expect(scheduledDay(s.get('tasks', later)), d(2026, 11, 25));
    expect(scheduledDay(s.get('tasks', finished)), isNull);
    // The move is in the card's history like any other plan change.
    expect(
      cardHistory(s, old).any((e) => e.str('action') == 'scheduled'),
      isTrue,
    );
  });

  test('a longer unit is allowed, a shorter one never', () {
    var s = study();
    s = setTimeline(s, board, 'week', now: now);
    s = setTimeline(s, board, 'month', now: now);
    final b = s.get('boards', board);
    expect(boardTimeline(b), 'month');
    expect(timelineAllowed(b, 'week'), isFalse);
    expect(() => setTimeline(s, board, 'week', now: now), throwsStateError);
    // Off and on again keeps the floor.
    s = setTimeline(s, board, null, now: now);
    expect(boardTimeline(s.get('boards', board)), isNull);
    expect(timelineAllowed(s.get('boards', board), 'day'), isFalse);
    expect(() => setTimeline(s, board, 'day', now: now), throwsStateError);
  });

  test('turning it off moves nothing; archiving finished cards from earlier '
      'periods is a choice', () {
    var s = study();
    final String old, finished;
    (s, finished) = card(s, 'Finished');
    s = moveCard(s, finished, column: done(s), index: 0, now: now);
    s = setTimeline(s, board, 'week', now: now);
    (s, old) = card(s, 'Open now');
    final summary = timelineOffSummary(s, board, now);
    expect(summary.doneBefore, 1);
    final kept = setTimeline(s, board, null, now: now);
    expect(kept.get('tasks', finished).flag('archived'), isFalse);
    expect(
      kept.get('tasks', old).data['scheduled'],
      s.get('tasks', old).data['scheduled'],
    );
    final tidy = setTimeline(s, board, null, now: now, archiveDone: true);
    expect(tidy.get('tasks', finished).flag('archived'), isTrue);
    expect(tidy.get('tasks', old).flag('archived'), isFalse);
  });

  test('open work before a period, and in it', () {
    var s = study();
    final String a, b;
    (s, a) = card(s, 'Last week', planned: d(2026, 11, 3));
    (s, b) = card(s, 'This week', planned: d(2026, 11, 10));
    final week = timelineWindow('week', now);
    expect(openBefore(s, board, week.first).map((t) => t.id), contains(a));
    expect(
      openBefore(s, board, week.first).map((t) => t.id),
      isNot(contains(b)),
    );
    expect(openIn(s, board, week).map((t) => t.id), [b]);
  });

  test('a repeating card on a timeline comes back in its next period', () {
    var s = study();
    s = setTimeline(s, board, 'week', now: now);
    final String scrum;
    (s, scrum) = card(s, 'Scrum', planned: today);
    s = s.put(
      'tasks',
      s.get('tasks', scrum).copy({
        'repeat': 'weekly',
        'repeatDays': [1],
      }),
    );
    s = moveCard(s, scrum, column: done(s), index: 0, now: now);
    final next = s.get('tasks', s.get('tasks', scrum).str('repeatedAs'));
    expect(scheduledDay(next), d(2026, 11, 16));
    expect(
      timelineWindow('week', d(2026, 11, 16)).contains(cardDay(next)),
      isTrue,
    );
  });

  test('a saved filter may hold several categories', () {
    var s = study();
    final cats = s
        .rows('categories')
        .where((c) => c.str('board') == board)
        .toList();
    final String a, b, c;
    (s, a) = card(s, 'A');
    (s, b) = card(s, 'B');
    (s, c) = card(s, 'C');
    s = s.put('tasks', s.get('tasks', a).copy({'category': cats[0].id}));
    s = s.put('tasks', s.get('tasks', b).copy({'category': cats[1].id}));
    final filter = {
      'categories': [cats[0].id, cats[1].id],
    };
    validateTaskFilter(filter);
    expect(taskMatches(s, s.get('tasks', a), filter: filter), isTrue);
    expect(taskMatches(s, s.get('tasks', b), filter: filter), isTrue);
    expect(taskMatches(s, s.get('tasks', c), filter: filter), isFalse);
  });

  test('templates that live by time start on their timeline unless the '
      'person picks Not by time', () {
    final semester = templateById('semester')!;
    final on = createFromTemplate(
      BoardsState(preferences: {'locale': 'en'}),
      semester,
      answers: {'title': 'S'},
      now: now,
      boardId: board,
    );
    expect(boardTimeline(on.get('boards', board)), isNotNull);
    final range = semester.fields.where((f) => f.role == FieldRole.timeRange);
    if (range.isEmpty) return;
    final off = createFromTemplate(
      BoardsState(preferences: {'locale': 'en'}),
      semester,
      answers: {'title': 'S', range.first.id: 'none'},
      now: now,
      boardId: board,
    );
    expect(boardTimeline(off.get('boards', board)), isNull);
  });
}
