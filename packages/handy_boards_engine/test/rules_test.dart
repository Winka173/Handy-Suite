import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

final now = DateTime(2026, 11, 9, 8); // Monday 08:00
const a = 'b0000000-0000-4000-8000-00000000000a';
const b = 'b0000000-0000-4000-8000-00000000000b';

BoardsState base() {
  var s = createFromTemplate(
    BoardsState(),
    templateById('project')!,
    answers: {'title': 'A'},
    now: now,
    boardId: a,
  );
  s = createFromTemplate(
    s,
    templateById('project')!,
    answers: {'title': 'B'},
    now: now,
    boardId: b,
  );
  return s.copy(preferences: {...s.preferences, 'notifications': true});
}

BoardRecord rule(
  String board,
  String trigger,
  List<Json> actions, {
  Json? when,
  int? days,
  String id = 'r1',
}) => BoardRecord({
  'id': id,
  'board': board,
  'title': 'Rule $id',
  'trigger': trigger,
  'actions': actions,
  'when': ?when,
  'days': ?days,
});

(BoardsState, String) addCard(
  BoardsState s,
  String board,
  String title, {
  Json extra = const {},
}) {
  final t = newTask(s, board, title).copy(extra);
  return (saveTask(s, t, now: now), t.id);
}

void main() {
  test('a new card gets the rule actions, once, as one change', () {
    var s = base();
    s = saveRule(
      s,
      rule(a, 'created', [
        {'type': 'priority', 'value': 3},
        {'type': 'checklist', 'value': 'Check the brief'},
      ]),
      now: now,
    );
    final before = s;
    final (after, id) = addCard(s, a, 'Write intro');
    final ran = runRules(before, after, now: now);
    ran.validate();
    expect(ran.get('tasks', id).data['priority'], 3);
    expect(subtasksOf(ran, id).map((c) => c.str('title')), ['Check the brief']);
    final log = ruleLog(ran, rule: 'r1');
    expect(log, hasLength(1));
    expect(log.single.data['steps'], ['priority', 'checklist']);
    // The rule's own changes do not start it again.
    expect(identical(runRules(after, after, now: now), after), isTrue);
    // A card on another board is not touched.
    final (other, id2) = addCard(ran, b, 'Elsewhere');
    expect(
      runRules(ran, other, now: now).get('tasks', id2).data['priority'],
      isNot(3),
    );
  });

  test('moved into a column: conditions, move action, no cascade', () {
    var s = base();
    final cols = columnsOf(s, a);
    final (s1, id) = addCard(s, a, 'Fix bug');
    s = s1;
    s = saveRule(
      s,
      rule(
        a,
        'moved',
        [
          {'type': 'suggestStatus', 'value': cols.last.id},
        ],
        when: {'status': cols[2].id},
      ),
      now: now,
    );
    // A second rule on 'moved' into the last column would cascade if rules
    // ran on their own changes.
    s = saveRule(
      s,
      rule(
        a,
        'moved',
        [
          {'type': 'priority', 'value': 0},
        ],
        when: {'status': cols.last.id},
        id: 'r2',
      ),
      now: now,
    );
    final before = s;
    final moved = moveCard(s, id, column: cols[2].id, index: 0, now: now);
    final ran = runRules(before, moved, now: now);
    expect(ran.get('tasks', id).str('status'), cols.last.id);
    expect(ran.get('tasks', id).data['priority'], isNot(0));
    expect(ruleLog(ran, rule: 'r2'), isEmpty);
  });

  test('first rule wins a field; the second is logged as skipped', () {
    var s = base();
    s = saveRule(
      s,
      rule(a, 'created', [
        {'type': 'priority', 'value': 3},
      ]),
      now: now,
    );
    s = saveRule(
      s,
      rule(a, 'created', [
        {'type': 'priority', 'value': 0},
      ], id: 'r2'),
      now: now,
    );
    final (after, id) = addCard(s, a, 'X');
    final ran = runRules(s, after, now: now);
    expect(ran.get('tasks', id).data['priority'], 3);
    expect(ruleLog(ran, rule: 'r2').single.data['steps'], [
      'priority: skipped (another rule)',
    ]);
  });

  test('disabled rules and bulk changes run nothing', () {
    var s = base();
    s = saveRule(
      s,
      rule(a, 'created', [
        {'type': 'priority', 'value': 3},
      ]).copy({'enabled': false}),
      now: now,
    );
    final (after, _) = addCard(s, a, 'X');
    expect(identical(runRules(s, after, now: now), after), isTrue);
    var on = saveRule(
      s,
      s.get('rules', 'r1').copy({'enabled': true}),
      now: now,
    );
    var bulk = on;
    for (var i = 0; i < 30; i++) bulk = addCard(bulk, a, 'Card $i').$1;
    expect(planRules(on, bulk), isEmpty);
  });

  test('template action adds its subtasks without duplicates', () {
    var s = base();
    final (s1, src) = addCard(s, a, 'Source');
    s = s1;
    s = s.put(
      'checklist',
      BoardRecord({
        'id': 'c1',
        'task': src,
        'title': 'Draft',
        'done': false,
        'order': 0,
      }),
    );
    s = cardTemplateFromCard(s, src, title: 'Tpl', now: now);
    final tpl = cardTemplates(s).single.id;
    s = saveRule(
      s,
      rule(a, 'created', [
        {'type': 'checklist', 'value': 'Draft'},
        {'type': 'template', 'value': tpl},
      ]),
      now: now,
    );
    final (after, id) = addCard(s, a, 'New');
    final ran = runRules(s, after, now: now);
    expect(subtasksOf(ran, id).map((c) => c.str('title')), ['Draft']);
    // Deleting the template later does not break the rule or the data.
    final gone = deleteCardTemplate(ran, tpl);
    gone.validate();
    final (again, id2) = addCard(gone, a, 'Newer');
    final ran2 = runRules(gone, again, now: now);
    expect(subtasksOf(ran2, id2).map((c) => c.str('title')), ['Draft']);
  });

  test(
    'due soon runs once per card and deadline, and plans a notification',
    () {
      var s = base();
      final (s1, id) = addCard(
        s,
        a,
        'Report',
        extra: {
          'due': {'kind': 'day', 'day': '2026-11-11'},
        },
      );
      s = saveRule(
        s1,
        rule(a, 'due soon', [
          {'type': 'priority', 'value': 3},
          {'type': 'notify', 'value': true},
        ], days: 2),
        now: now,
      );
      final once = runDueSoonRules(s, now: now);
      expect(once.get('tasks', id).data['priority'], 3);
      expect(ruleLog(once).single.data['due'], '2026-11-11');
      final twice = runDueSoonRules(
        once.put('tasks', once.get('tasks', id).copy({'priority': 1})),
        now: now.add(const Duration(hours: 3)),
      );
      expect(twice.get('tasks', id).data['priority'], 1);
      // The notification: on the 9th (2 days before), at 09:00, Pro only.
      final notes = planNotifications(s, now, vi: false, pro: true);
      final n = notes.singleWhere((n) => n.key.startsWith('boards:rule:'));
      expect(n.at, DateTime(2026, 11, 9, 9));
      expect(n.body, 'Report is due in 2 days');
      expect(
        planNotifications(
          s,
          now,
          vi: false,
        ).where((n) => n.key.startsWith('boards:rule:')),
        isEmpty,
      );
    },
  );

  test('notify only on due-soon rules; deleting a column prunes rules', () {
    var s = base();
    expect(
      () => saveRule(
        s,
        rule(a, 'created', [
          {'type': 'notify', 'value': true},
        ]),
        now: now,
      ).validate(),
      throwsFormatException,
    );
    final cols = columnsOf(s, a);
    s = saveRule(
      s,
      rule(a, 'created', [
        {'type': 'suggestStatus', 'value': cols[1].id},
      ]),
      now: now,
    );
    s = deleteColumn(s, cols[1].id);
    s.validate();
    expect(s.get('rules', 'r1').data['actions'], isEmpty);
    expect(s.get('rules', 'r1').flag('enabled'), isFalse);
    final cat = categoriesOf(s, a);
    if (cat.length > 1) {
      s = saveRule(
        s,
        rule(
          a,
          'created',
          [
            {'type': 'priority', 'value': 2},
          ],
          when: {'category': cat.first.id},
          id: 'r2',
        ),
        now: now,
      );
      s = deleteCategory(s, cat.first.id, moveTo: cat[1].id);
      s.validate();
      expect(s.get('rules', 'r2').data['when'], isNull);
      expect(s.get('rules', 'r2').flag('enabled'), isTrue);
    }
    // Deleting a rule drops its log.
    final (after, _) = addCard(s, a, 'Y');
    final ran = runRules(s, after, now: now);
    expect(deleteRule(ran, 'r2').rows('executions'), isEmpty);
  });

  test('a reminder action counts back from the deadline', () {
    var s = base();
    s = saveRule(
      s,
      rule(a, 'created', [
        {'type': 'remindMinutes', 'value': 24 * 60},
      ]),
      now: now,
    );
    final (after, id) = addCard(
      s,
      a,
      'Exam',
      extra: {
        'due': {'kind': 'day', 'day': '2026-11-12'},
      },
    );
    final ran = runRules(s, after, now: now);
    final r = ran.related('reminders', id).single;
    expect(DateTime.parse(r.str('at')).toLocal(), DateTime(2026, 11, 11, 9));
  });

  test('digest: one line per board with work, private sums only', () {
    var s = base();
    s = addCard(s, a, 'T', extra: {'scheduled': '2026-11-09'}).$1;
    s = addCard(s, a, 'Old', extra: {'scheduled': '2026-11-05'}).$1;
    s = addCard(
      s,
      b,
      'Soon',
      extra: {
        'due': {'kind': 'day', 'day': '2026-11-11'},
      },
    ).$1;
    s = s.copy(
      preferences: {
        ...s.preferences,
        'notify': {'digest': 'daily'},
      },
    );
    final lines = digestLines(s, DateTime(2026, 11, 9));
    expect(lines.map((l) => (l.title, l.today, l.behind, l.soon)), [
      ('A', 1, 1, 0),
      ('B', 0, 0, 1),
    ]);
    final notes = planNotifications(
      s,
      now,
      vi: false,
      pro: true,
    ).where((n) => n.key.startsWith('boards:digest:')).toList();
    expect(notes.first.body, 'A: 1 today, 1 left behind · B: 1 due soon');
    expect(
      planNotifications(
        s,
        now,
        vi: false,
      ).where((n) => n.key.startsWith('boards:digest:')),
      isEmpty,
    );
    final private = s.copy(
      preferences: {
        ...s.preferences,
        'notify': {'digest': 'weekly', 'digestDay': 1, 'private': true},
      },
    );
    final weekly = planNotifications(
      private,
      now,
      vi: true,
      pro: true,
    ).where((n) => n.key.startsWith('boards:digest:')).toList();
    expect(weekly, hasLength(1));
    expect(weekly.single.body, '1 hôm nay, 1 còn tồn, 1 sắp hạn');
    // Only the chosen boards.
    final onlyB = s.copy(
      preferences: {
        ...s.preferences,
        'notify': {
          'digest': 'daily',
          'digestBoards': [b],
        },
      },
    );
    expect(
      planNotifications(
        onlyB,
        now,
        vi: false,
        pro: true,
      ).firstWhere((n) => n.key.startsWith('boards:digest:')).body,
      'B: 1 due soon',
    );
  });
}
