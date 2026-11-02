import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'engine_test.dart' show fixture, withTask;

void main() {
  test(
    'same-board move preserves subtask parent; cross-board move detaches explicitly',
    () {
      var s = withTask(withTask(fixture()), id: 'child', parent: 't');
      final cat = s.rows('categories').last.id;
      s = moveTasks(s, {'child'}, 'b', category: cat);
      expect(s.get('tasks', 'child').str('parent'), 't');
      s = createBoard(s, 'Other', boardId: 'other');
      s = moveTasks(s, {'child'}, 'other');
      expect(s.get('tasks', 'child').data['parent'], isNull);
    },
  );
  test(
    'restoring parent never restores a previously trashed independent child',
    () {
      var s = withTask(withTask(fixture()), id: 'child', parent: 't');
      s = trashTasks(s, {'child'});
      s = trashTasks(s, {'t'});
      s = trashTasks(s, {'t'}, restore: true);
      expect(s.get('tasks', 't').flag('trashed'), false);
      expect(s.get('tasks', 'child').flag('trashed'), true);
    },
  );
  test(
    'safe duplicate creates new subtree/checklist IDs and resets completion',
    () {
      var s = withTask(withTask(fixture()), id: 'child', parent: 't');
      s = s.put(
        'checklist',
        BoardRecord({
          'id': 'check',
          'task': 'child',
          'title': 'Read',
          'done': true,
          'completedAt': '2026-01-01T00:00:00Z',
        }),
      );
      final next = duplicateTask(s, 't');
      expect(next.rows('tasks').length, 4);
      final copies = next
          .rows('tasks')
          .where((r) => !['t', 'child'].contains(r.id))
          .toList();
      expect(copies.where((r) => r.data['parent'] == null).length, 1);
      final check = next.rows('checklist').firstWhere((r) => r.id != 'check');
      expect(check.flag('done'), false);
      expect(check.data['completedAt'], isNull);
      next.validate();
    },
  );
  test(
    'custom defaults apply to new tasks and incompatible type changes refuse',
    () {
      var s = fixture();
      s = s.put(
        'fields',
        BoardRecord({
          'id': 'field',
          'board': 'b',
          'title': 'Budget',
          'type': 'number',
          'default': '12.50',
        }),
      );
      s.validate();
      final task = newTask(s, 'b', 'Work');
      expect(object(task.data['custom'])['field'], '12.50');
      s = saveTask(s, task);
      expect(
        () => s
            .put('fields', s.get('fields', 'field').copy({'type': 'checkbox'}))
            .validate(),
        throwsFormatException,
      );
    },
  );
  test(
    'editing status through generic editor keeps completion event and occurrence state',
    () {
      var s = withTask(fixture());
      s = s.put(
        'recurrence',
        BoardRecord({
          'id': 'rule',
          'task': 't',
          'board': 'b',
          'start': '2026-11-01',
          'frequency': 'daily',
          'zone': 'Asia/Ho_Chi_Minh',
        }),
      );
      s = generateOccurrences(s, 'rule', '2026-11-01');
      final id = s.rows('occurrences').single.str('task'),
          done = s.rows('statuses').firstWhere((r) => r.flag('done')).id;
      s = saveTask(
        s,
        s.get('tasks', id).copy({'status': done}),
        now: DateTime.utc(2026, 11, 2),
      );
      expect(
        s.get('tasks', id).data['completedAt'],
        '2026-11-02T00:00:00.000Z',
      );
      expect(s.rows('occurrences').single.str('state'), 'completed');
      expect(s.rows('events').last.str('action'), 'completed');
    },
  );
  test(
    'focus crosses midnight with exact allocation; reviewed duration stays unallocated',
    () {
      var s = withTask(fixture());
      final start = DateTime.utc(2026, 11, 1, 16, 59);
      s = startFocus(s, 't', start);
      final id = s.rows('sessions').single.id;
      s = pauseFocus(s, id, start.add(const Duration(minutes: 2)));
      final report = workloadReport(s, 'b'), days = object(report['days']);
      expect(object(days['2026-11-01'])['actualSeconds'], 60);
      expect(object(days['2026-11-02'])['actualSeconds'], 60);
      s = resumeFocus(s, id, start.add(const Duration(days: 2)));
      s = reviewInterruptedFocus(
        s,
        id,
        300,
        start.add(const Duration(days: 5)),
      );
      expect(workloadReport(s, 'b')['unallocatedActualSeconds'], 300);
      expect(s.rows('sessions').single.data['runningAt'], isNull);
    },
  );
  test('personal grade scale mapping and invalid thresholds', () {
    expect(presentGrade(80, '10'), '8.00 / 10');
    expect(
      presentGrade(80, 'letter', letters: {'A': 90, 'B': 80, 'C': 60}),
      'B',
    );
    expect(() => presentGrade(80, 'letter'), throwsFormatException);
  });
}
