import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'engine_test.dart' show fixture, withTask;

void main() {
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
}
