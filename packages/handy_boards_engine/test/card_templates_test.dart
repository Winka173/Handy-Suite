import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

final now = DateTime(2026, 11, 9, 9);
const a = 'b0000000-0000-4000-8000-00000000000a';
const b = 'b0000000-0000-4000-8000-00000000000b';

BoardsState two() {
  var s = createFromTemplate(
    BoardsState(),
    templateById('semester')!,
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
  return s;
}

void main() {
  test('a template keeps the pattern of a card, never its state', () {
    var s = two();
    final col = columnsOf(s, a).first.id;
    final cat = categoriesOf(s, a).first;
    var t = newTask(s, a, 'Lab report', category: cat.id).copy({
      'status': col,
      'notes': 'Intro, method, result',
      'due': {'kind': 'day', 'day': '2026-11-01'},
      'scheduled': '2026-10-30',
      'priority': 2,
    });
    s = saveTask(s, t, now: now);
    s = s.put(
      'checklist',
      BoardRecord({
        'id': 'c0000000-0000-4000-8000-000000000001',
        'task': t.id,
        'title': 'Draft',
        'done': true,
        'order': 0,
      }),
    );
    s = cardTemplateFromCard(s, t.id, now: now);
    final tpl = cardTemplates(s).single;
    expect(tpl.str('title'), 'Lab report');
    expect(tpl.data['checklist'], ['Draft']);
    expect(tpl.str('category'), cat.str('title'));
    final json = '${tpl.toJson()}';
    for (final leak in [
      t.id,
      '2026-11-01',
      '2026-10-30',
      'completedAt',
      'done',
    ])
      expect(json, isNot(contains(leak)), reason: leak);
    // Applied elsewhere: a fresh card, subtasks unticked, history its own.
    s = trashTasks(s, {t.id}, now: now);
    s = permanentlyDelete(s, {t.id}, confirmed: true);
    s = saveCardTemplate(
      s,
      id: tpl.id,
      title: 'Lab report',
      notes: tpl.str('notes'),
      checklist: ['Draft'],
      planIn: 1,
      dueIn: 3,
      category: cat.str('title'),
      now: now,
    );
    final r = applyCardTemplate(s, tpl.id, columnsOf(s, a).first.id, now: now);
    s = r.state;
    final card = s.get('tasks', r.card);
    expect(card.id, isNot(t.id));
    expect(card.str('category'), cat.id);
    expect(card.str('scheduled'), '2026-11-10');
    expect(dueDay(card), DateTime(2026, 11, 12));
    expect(subtasksOf(s, r.card).single.flag('done'), isFalse);
    expect(cardHistory(s, r.card).map((e) => e.str('action')), [
      'created',
      'from template',
    ]);
    expect(cardsIn(s, columnsOf(s, a).first.id).first.id, r.card);
  });

  test('across boards: a category by name, unknown fields skipped', () {
    var s = two();
    s = saveCardTemplate(
      s,
      title: 'Standup',
      category: 'No such group',
      custom: [
        {'name': 'Points', 'type': 'number', 'value': 3},
      ],
      now: now,
    );
    final r = applyCardTemplate(
      s,
      cardTemplates(s).single.id,
      columnsOf(s, b).first.id,
      now: now,
    );
    expect(r.state.get('tasks', r.card).data['category'], isNull);
    expect(r.skippedFields, ['Points']);
    expect(r.state.get('tasks', r.card).data['scheduled'], isNull);
  });

  test('templates are validated, survive a backup and can be deleted', () {
    var s = two();
    expect(() => saveCardTemplate(s, title: '  '), throwsFormatException);
    expect(
      () => saveCardTemplate(s, title: 'x', dueIn: 400),
      throwsFormatException,
    );
    s = saveCardTemplate(
      s,
      title: 'Weekly review',
      checklist: ['Inbox', 'Calendar'],
      now: now,
    );
    final back = readBackup(exportBackup(s));
    expect(cardTemplates(back).single.data['checklist'], ['Inbox', 'Calendar']);
    s = deleteCardTemplate(s, cardTemplates(s).single.id);
    expect(cardTemplates(s), isEmpty);
  });
}
