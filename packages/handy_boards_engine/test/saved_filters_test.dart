import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

const a = 'b0000000-0000-4000-8000-00000000000a';
final now = DateTime(2026, 11, 9, 9);

void main() {
  test('saved filters: AND, OR, validated, removable', () {
    var s = createFromTemplate(
      BoardsState(),
      templateById('semester')!,
      answers: {'title': 'S'},
      now: now,
      boardId: a,
    );
    final [maths, lit, ...] = categoriesOf(s, a);
    final first = columnsOf(s, a).first.id;
    final x = newTask(
      s,
      a,
      'x',
      category: maths.id,
    ).copy({'status': first, 'priority': 3});
    final y = newTask(
      s,
      a,
      'y',
      category: lit.id,
    ).copy({'status': first, 'priority': 1});
    s = saveTask(saveTask(s, x, now: now), y, now: now);
    s = saveFilter(s, a, 'Urgent maths', [
      {'category': maths.id},
      {'priority': 3},
    ]);
    final f = savedFilters(s, a).single;
    expect(filterMatches(s, f, s.get('tasks', x.id)), isTrue);
    expect(filterMatches(s, f, s.get('tasks', y.id)), isFalse);
    s = saveFilter(s, a, 'Either', [
      {'category': maths.id},
      {'category': lit.id},
    ], any: true);
    final either = savedFilters(
      s,
      a,
    ).firstWhere((v) => v.str('title') == 'Either');
    expect(filterMatches(s, either, s.get('tasks', y.id)), isTrue);
    expect(
      () => saveFilter(s, a, 'Bad', [
        {'formula': 1},
      ]),
      throwsFormatException,
    );
    expect(() => saveFilter(s, a, 'Empty', []), throwsFormatException);
    s = deleteFilter(s, f.id);
    expect(savedFilters(s, a), hasLength(1));
  });
}
