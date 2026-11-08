import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

final now = DateTime(2026, 11, 9, 9);
const a = 'b0000000-0000-4000-8000-00000000000a';

void main() {
  test('fields: typed values, renames, set aside and back, backup', () {
    var s = createFromTemplate(
      BoardsState(),
      templateById('project')!,
      // Without the template's suggested fields: this test makes its own.
      answers: {'title': 'A', cardFieldsKey: <int>[]},
      now: now,
      boardId: a,
    );
    s = addField(s, a, 'Points', 'number', onCard: true);
    s = addField(s, a, 'Size', 'single', options: ['S', 'M', 'L']);
    s = addField(s, a, 'Spec', 'url');
    expect(() => addField(s, a, 'points', 'text'), throwsFormatException);
    expect(() => addField(s, a, 'Formula', 'formula'), throwsFormatException);
    final [points, size, spec] = fieldsOf(s, a);
    final t = newTask(s, a, 'Login');
    s = saveTask(s, t, now: now);
    s = setFieldValue(s, t.id, points.id, '5', now: now);
    s = setFieldValue(s, t.id, size.id, 'M', now: now);
    expect(() => setFieldValue(s, t.id, size.id, 'XL'), throwsFormatException);
    expect(
      () => setFieldValue(s, t.id, points.id, 'five'),
      throwsFormatException,
    );
    expect(
      () => setFieldValue(s, t.id, spec.id, 'javascript:alert(1)'),
      throwsFormatException,
    );
    // A choice in use cannot be removed.
    expect(
      () => updateField(s, size.id, options: ['S', 'L']),
      throwsFormatException,
    );
    s = updateField(s, points.id, title: 'Story points');
    // Set aside: hidden from the list, the value stays on the card.
    s = archiveField(s, points.id);
    expect(fieldsOf(s, a).map((f) => f.id), [size.id, spec.id]);
    expect(s.get('tasks', t.id).data['custom'][points.id], '5');
    s = archiveField(s, points.id, restore: true);
    expect(fieldsOf(s, a), hasLength(3));
    // History names the field, never the value.
    final e = cardHistory(
      s,
      t.id,
    ).where((e) => e.str('action') == 'field changed');
    expect(e, hasLength(2));
    expect('${e.first.data}', isNot(contains("'5'")));
    final back = readBackup(exportBackup(s));
    expect(back.get('tasks', t.id).data['custom'], {
      points.id: '5',
      size.id: 'M',
    });
    expect(fieldText(points, '5'), '5');
  });
}
