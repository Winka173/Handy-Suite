import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

// Monday 9 November 2026, 09:00 local.
final now = DateTime(2026, 11, 9, 9);
final today = DateTime(2026, 11, 9);
DateTime d(int y, int m, int day) => DateTime(y, m, day);

const board = 'b0000000-0000-4000-8000-000000000009';

BoardsState study() => createFromTemplate(
  BoardsState(preferences: {'locale': 'en'}),
  templateById('semester')!,
  answers: {'title': 'Semester'},
  now: now,
  boardId: board,
);

/// A card in the board's [column]-th column with the given dates.
(BoardsState, String) card(
  BoardsState s,
  String title, {
  int column = 0,
  DateTime? due,
  DateTime? planned,
}) {
  final cols = columnsOf(s, board);
  var t = newTask(s, board, title).copy({
    'status': cols[column].id,
    if (due != null) 'due': {'kind': 'day', 'day': isoDay(due)},
    if (planned != null) 'scheduled': isoDay(planned),
  });
  s = saveTask(s, t, now: now.subtract(const Duration(days: 30)));
  return (s, t.id);
}

String done(BoardsState s) =>
    columnsOf(s, board).firstWhere((c) => c.flag('done')).id;

void main() {
  group('windows', () {
    test('day ranges start today and step by their own length', () {
      for (final n in [1, 2, 3]) {
        final r = TimeRange('day', n);
        final w = currentWindow(r, now);
        expect(w.first, today);
        expect(w.days, n);
        final next = shiftWindow(r, w, 1), prev = shiftWindow(r, w, -1);
        expect(next.first, w.end);
        expect(prev.end, w.first);
      }
    });

    test('weeks start on Monday; two weeks step by fourteen days', () {
      final w = currentWindow(const TimeRange('week', 2), d(2026, 11, 12));
      expect(w.first, d(2026, 11, 9));
      expect(w.end, d(2026, 11, 23));
      expect(
        shiftWindow(const TimeRange('week', 2), w, 1).first,
        d(2026, 11, 23),
      );
    });

    test('months are calendar months, not 30 days', () {
      const one = TimeRange('month'), two = TimeRange('month', 2);
      var w = currentWindow(one, d(2027, 1, 31));
      expect('$w', '2027-01-01..2027-01-31');
      w = shiftWindow(one, w, 1);
      expect('$w', '2027-02-01..2027-02-28');
      // Leap year.
      expect('${currentWindow(one, d(2028, 2, 10))}', '2028-02-01..2028-02-29');
      // Two months across the new year.
      final nd = currentWindow(two, d(2026, 11, 30));
      expect('$nd', '2026-11-01..2026-12-31');
      expect('${shiftWindow(two, nd, 1)}', '2027-01-01..2027-02-28');
      expect(
        '${shiftWindow(const TimeRange('month', 3), currentWindow(const TimeRange('month', 3), d(2026, 12, 1)), -1)}',
        '2026-09-01..2026-11-30',
      );
    });

    test('a custom span is inclusive and steps by its exact length', () {
      final r = TimeRange.custom(d(2026, 11, 9), d(2026, 12, 20));
      expect(r.days, 42);
      final w = currentWindow(r, now);
      expect('$w', '2026-11-09..2026-12-20');
      final next = shiftWindow(r, w, 1);
      expect('$next', '2026-12-21..2027-01-31');
      expect('${shiftWindow(r, next, -1)}', '$w');
      expect(TimeRange.read(r.toJson()), r);
      // Old boards keep their stored span.
      expect(
        TimeRange.read({'unit': 'month', 'count': 3}),
        const TimeRange('month', 3),
      );
      expect(
        TimeRange.read({
          'unit': 'custom',
          'first': '2026-12-01',
          'last': '2026-11-01',
        }),
        TimeRange.standard,
      );
    });

    test('day counts ignore clock changes', () {
      // 29 March 2026 and 25 October 2026 are daylight-saving days in much
      // of Europe; calendar maths never sees a 23- or 25-hour day.
      expect(daysBetween(d(2026, 3, 28), d(2026, 3, 30)), 2);
      expect(daysBetween(d(2026, 10, 24), d(2026, 10, 26)), 2);
      expect(addDays(d(2026, 3, 28), 2), d(2026, 3, 30));
      expect(
        windowIndex(
          const TimeRange('week'),
          currentWindow(const TimeRange('week'), now),
          d(2026, 11, 8),
        ),
        -1,
      );
    });
  });

  group('markers and backlog', () {
    test(
      'Scenario A: last week\'s unfinished card, moved to now, stays overdue',
      () {
        var s = study();
        String a;
        (s, a) = card(
          s,
          'Assignment 2',
          column: 1,
          planned: d(2026, 11, 3),
          due: d(2026, 11, 6),
        );
        const week = TimeRange('week');
        final current = currentWindow(week, now);
        var marks = periodMarks(s, board, week, current, today);
        expect(marks.single.index, -1);
        expect(
          marks.single.open,
          1,
          reason: 'one card, two dates, counted once',
        );
        expect(marks.single.overdue, 1);
        expect(backlogOf(s, board, today).single.card.id, a);

        final status = s.get('tasks', a).str('status');
        final before = plansOf(s, [a]);
        s = scheduleCards(s, [a], today, reason: 'move to now', now: now);
        final t = s.get('tasks', a);
        expect(t.str('scheduled'), '2026-11-09');
        expect(t.str('status'), status);
        expect(dueDay(t), d(2026, 11, 6));
        // Still overdue: the deadline's week keeps its marker.
        marks = periodMarks(s, board, week, current, today);
        expect(marks.single.overdue, 1);
        final item = backlogOf(s, board, today).single;
        expect(item.overdue, isTrue);
        expect(item.pastPlan, isFalse);
        expect(cardHistory(s, a).last.str('action'), 'scheduled');

        s = restorePlans(s, before, now: now);
        expect(s.get('tasks', a).str('scheduled'), '2026-11-03');
        expect(periodMarks(s, board, week, current, today).single.open, 1);
        final last = cardHistory(s, a).last;
        expect(last.data['details']['reason'], 'undo');
      },
    );

    test(
      'Scenario B: a card planned next month done early keeps its deadline',
      () {
        var s = study();
        String b;
        (s, b) = card(
          s,
          'Report',
          planned: d(2026, 12, 4),
          due: d(2026, 12, 20),
        );
        const month = TimeRange('month');
        final current = currentWindow(month, now);
        expect(periodMarks(s, board, month, current, today).single.later, 1);
        final before = plansOf(s, [b]);
        s = scheduleCards(s, [b], today, reason: 'do early', now: now);
        expect(scheduledDay(s.get('tasks', b)), today);
        expect(dueDay(s.get('tasks', b)), d(2026, 12, 20));
        expect(completed(s, s.get('tasks', b)), isFalse);
        s = restorePlans(s, before, now: now);
        expect(s.get('tasks', b).str('scheduled'), '2026-12-04');
      },
    );

    test('Scenario C: planning a deadline-only card leaves the deadline', () {
      var s = study();
      String c;
      (s, c) = card(s, 'Quiz', due: d(2026, 11, 16));
      s = scheduleCards(s, [c], today, now: now);
      expect(s.get('tasks', c).str('scheduled'), '2026-11-09');
      expect(dueDay(s.get('tasks', c)), d(2026, 11, 16));
    });

    test('finished, archived and trashed cards are never backlog', () {
      var s = study();
      String a, b, c, x;
      (s, a) = card(s, 'Done one', due: d(2026, 11, 2));
      (s, b) = card(s, 'Archived', due: d(2026, 11, 2));
      (s, c) = card(s, 'Trashed', due: d(2026, 11, 2));
      (s, x) = card(s, 'Still open', due: d(2026, 11, 2));
      s = changeStatus(s, a, done(s), now: now);
      s = saveTask(s, s.get('tasks', b).copy({'archived': true}), now: now);
      s = trashTasks(s, {c}, now: now);
      expect(backlogOf(s, board, today).map((i) => i.card.id), [x]);
      final m = periodMarks(
        s,
        board,
        const TimeRange('week'),
        currentWindow(const TimeRange('week'), now),
        today,
      ).single;
      expect(m.open, 1);
      expect(m.done, 1, reason: 'finished cards show as finished, not backlog');
    });

    test('a filter narrows markers the same way it narrows the board', () {
      var s = study();
      String a;
      (s, a) = card(s, 'Mine', due: d(2026, 11, 2));
      (s, _) = card(s, 'Other', due: d(2026, 11, 3));
      final m = periodMarks(
        s,
        board,
        const TimeRange('week'),
        currentWindow(const TimeRange('week'), now),
        today,
        shows: (t) => t.id == a,
      ).single;
      expect(m.open, 1);
    });
  });

  group('history', () {
    test('Scenario F: real events in order, nothing invented', () {
      var s = study();
      String a;
      (s, a) = card(s, 'Essay');
      expect(historyFromStart(s, a), isTrue);
      final cols = columnsOf(s, board);
      s = moveCard(s, a, column: cols[1].id, index: 0, now: now);
      s = setDueDay(s, a, d(2026, 11, 20), now: now);
      final sub = newTask(s, board, 'Outline', parent: a);
      s = s.put(
        'checklist',
        BoardRecord({
          'id': 'c0000000-0000-4000-8000-0000000000aa',
          'task': a,
          'title': 'Outline',
          'done': false,
          'order': 0,
        }),
      );
      s = toggleChecklist(
        s,
        'c0000000-0000-4000-8000-0000000000aa',
        true,
        now: now,
      );
      s = scheduleCards(s, [a], d(2026, 11, 12), now: now);
      s = moveCard(s, a, column: done(s), index: 0, now: now);
      s = moveCard(s, a, column: cols[1].id, index: 0, now: now);
      final actions = [for (final e in cardHistory(s, a)) e.str('action')];
      expect(actions, [
        'created',
        'status changed',
        'due changed',
        'subtask',
        'scheduled',
        'completed',
        'reopened',
      ]);
      final due = cardHistory(s, a)[2].data['details'] as Map;
      expect(due['to'], '2026-11-20');
      // The subtask's words stay out of the history.
      expect('${cardHistory(s, a)[3].data}', isNot(contains('Outline')));
      expect(sub.id, isNotEmpty);
    });

    test('a card from before history began says so; a copy starts fresh', () {
      var s = study();
      String a;
      (s, a) = card(s, 'Old');
      // As an older version left it: no events at all.
      s = s.remove('events', {for (final e in s.rows('events')) e.id});
      expect(cardHistory(s, a), isEmpty);
      expect(historyFromStart(s, a), isFalse);
      s = duplicateCard(s, a, now: now);
      final copy = topTasks(
        s,
        board: board,
      ).firstWhere((t) => t.id != a && t.str('title') == 'Old');
      expect(cardHistory(s, copy.id).first.str('action'), 'created');
      expect(cardHistory(s, a), isEmpty);
    });

    test('Scenario G: plans and history survive a backup round trip', () {
      var s = study();
      String a;
      (s, a) = card(s, 'Kept', due: d(2026, 11, 2));
      s = scheduleCards(s, [a], today, now: now);
      final back = readBackup(exportBackup(s));
      expect(back.get('tasks', a).str('scheduled'), '2026-11-09');
      expect(cardHistory(back, a).length, cardHistory(s, a).length);
      // A plan that is not a calendar day is refused.
      expect(
        () => s
            .put('tasks', s.get('tasks', a).copy({'scheduled': 'tomorrow'}))
            .validate(),
        throwsFormatException,
      );
    });

    test('a repeating card\'s next time keeps its plan one period on', () {
      var s = study();
      String a;
      (s, a) = card(
        s,
        'Weekly quiz',
        planned: d(2026, 11, 9),
        due: d(2026, 11, 10),
      );
      s = saveTask(s, s.get('tasks', a).copy({'repeat': 'weekly'}), now: now);
      s = moveCard(s, a, column: done(s), index: 0, now: now);
      final next = s.get('tasks', s.get('tasks', a).str('repeatedAs'));
      expect(next.str('scheduled'), '2026-11-16');
      expect(dueDay(next), d(2026, 11, 17));
    });
  });

  group('template time defaults', () {
    BoardRecord made(String id, [TemplateAnswers? a]) {
      final t = templateById(id)!;
      final s = createFromTemplate(
        BoardsState(),
        t,
        answers: a ?? const {},
        now: now,
        boardId: board,
      );
      return s.get('boards', board);
    }

    test('pinned and ranges follow the table; blank is unpinned', () {
      expect(timePinned(made('weekly')), isTrue);
      expect(made('weekly').data['span'], {'unit': 'week', 'count': 1});
      expect(made('sprint').data['span'], {'unit': 'week', 'count': 2});
      expect(timePinned(made('inspiration')), isFalse);
      expect(made('daily').data['view'], 'time');
      final blank = buildBoard(
        BoardsState(),
        blankPlan(title: 'Blank'),
        now: now,
        boardId: board,
      ).get('boards', board);
      expect(timePinned(blank), isFalse);
      expect(blank.data['span'], {'unit': 'week', 'count': 1});
    });

    test('"pinned if dated" pins only when a date was given', () {
      final t = templateById('launch')!;
      final dateField = t.fields.firstWhere(
        (f) => f.kind == FieldKind.date || f.kind == FieldKind.dateRange,
      );
      final TemplateAnswers noDate = {
        ...defaultAnswers(t, vi: false, now: now),
        dateField.id: null,
      };
      expect(timePinned(made('launch', noDate)), isFalse);
      final TemplateAnswers dated = {
        ...defaultAnswers(t, vi: false, now: now),
        dateField.id: '2026-12-01',
      };
      expect(timePinned(made('launch', dated)), isTrue);
      expect(made('launch', dated).data['span'], {'unit': 'month', 'count': 1});
    });

    test('the Smart Setup answer picks the unit and wins', () {
      final t = templateById('exam-revision')!;
      final TemplateAnswers month = {
        ...defaultAnswers(t, vi: false, now: now),
        'range': 'month',
      };
      expect(made('exam-revision', month).data['span'], {
        'unit': 'month',
        'count': 1,
      });
      final TemplateAnswers week = {
        ...defaultAnswers(t, vi: false, now: now),
        'range': 'week',
      };
      expect(made('exam-revision', week).data['span'], {
        'unit': 'week',
        'count': 2,
      });
    });
  });
}
