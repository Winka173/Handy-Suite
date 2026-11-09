import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

void main() {
  test('a trashed card goes for good 30 days after it was trashed', () {
    final day0 = DateTime.utc(2026, 11, 1, 9);
    var s = createFromTemplate(
      BoardsState(),
      templateById('semester')!,
      answers: {'title': 'Semester 1'},
      examples: true,
      now: day0,
    );
    final cards = s
        .rows('tasks')
        .where((t) => t.str('parent').isEmpty)
        .toList();
    final gone = cards.first.id, kept = cards[1].id;
    s = trashTasks(s, {gone}, now: day0);
    s = trashTasks(s, {kept}, now: day0.add(const Duration(days: 20)));
    expect(trashExpiry(s.get('tasks', gone)), day0.add(trashRetention));
    expect(expiredTrash(s, day0.add(const Duration(days: 29))), isEmpty);
    final due = expiredTrash(s, day0.add(const Duration(days: 30)));
    expect(due, contains(gone));
    expect(due, isNot(contains(kept)));
    s = permanentlyDelete(s, due, confirmed: true);
    expect(s.maybe('tasks', gone), isNull);
    expect(s.get('tasks', kept).flag('trashed'), isTrue);
    expect(trashExpiry(s.get('tasks', cards[2].id)), isNull);
  });
}
