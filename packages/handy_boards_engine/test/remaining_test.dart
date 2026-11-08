import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'engine_test.dart' show fixture, withTask;

Json trello() => {
  'name': 'Bảng của tôi',
  'lists': [
    {'id': 'l1', 'name': 'Work'},
    {'id': 'l2', 'name': 'Finished'},
  ],
  'cards': [
    {
      'id': 'c1',
      'idList': 'l1',
      'name': 'Bài tập',
      'desc': 'Ghi chú',
      'due': '2026-11-02T12:00:00Z',
      'dueComplete': true,
      'labels': [
        {'id': 'tag', 'name': 'School'},
      ],
      'attachments': [
        {'name': 'Guide', 'url': 'https://example.com/guide'},
      ],
    },
    {'id': 'c2', 'idList': 'l2', 'name': 'Done', 'closed': false},
  ],
  'checklists': [
    {
      'id': 'check',
      'idCard': 'c1',
      'checkItems': [
        {'name': 'Read', 'state': 'complete'},
        {'name': 'Review', 'state': 'incomplete'},
      ],
    },
  ],
};
void main() {
  test('saved working calendars stay valid data and round-trip in backups', () {
    final calendar = {
      'weekdays': [1, 2, 3, 4, 5],
      'holidays': ['2026-11-02'],
      'minutesPerDay': 480,
      'startMinute': 540,
    };
    expect(
      () => validateWorkingCalendar({'weekdays': []}),
      throwsFormatException,
    );
    expect(
      () =>
          validateWorkingCalendar({'minutesPerDay': 1000, 'startMinute': 540}),
      throwsFormatException,
    );
    var s = fixture();
    s = s.put(
      'boards',
      s.get('boards', 'b').copy({
        'workingCalendar': calendar,
        'resourceCalendars': {
          'An': {
            'weekdays': [6, 7],
            'minutesPerDay': 240,
            'startMinute': 600,
          },
        },
      }),
    );
    expect(readBackup(exportBackup(s)).toJson(), s.toJson());
  });
  test('v1 state and backup metadata migrate forward without changing IDs', () {
    final s = withTask(fixture()), j = s.toJson()..['schema'] = 1;
    final migrated = BoardsState.fromJson(j);
    expect(migrated.get('tasks', 't').data, s.get('tasks', 't').data);
    expect(migrated.toJson()['schema'], 4);
  });
  test(
    'Trello import separates categories/status/tags, does not guess completion, preserves subset round trip',
    () {
      final plan = previewTrello(trello());
      expect(plan.cards, 2);
      expect(plan.warnings, isNotEmpty);
      final s = importTrello(
        BoardsState(),
        plan,
        title: 'Imported',
        completedLists: {'l2'},
        includeLinks: true,
        confirmed: true,
      );
      final first = s
              .rows('tasks')
              .firstWhere((t) => t.str('title') == 'Bài tập'),
          second = s.rows('tasks').firstWhere((t) => t.str('title') == 'Done');
      expect(first.data['category'], null);
      expect(completed(s, first), false);
      expect(completed(s, second), true);
      expect(first.flag('trelloDueComplete'), true);
      expect(first.str('notes'), 'Ghi chú');
      expect(s.rows('checklist').where((c) => c.flag('done')).length, 1);
      expect(
        s.rows('attachments').single.str('url'),
        'https://example.com/guide',
      );
      expect(readBackup(exportBackup(s)).toJson(), s.toJson());
      expect(
        () => importTrello(s, plan, title: 'No', confirmed: false),
        throwsFormatException,
      );
      final bad = trello();
      (bad['cards'] as List).first['idList'] = 'missing';
      expect(() => previewTrello(bad), throwsFormatException);
      final unsafe = trello();
      (unsafe['cards'] as List).first['attachments'] = [
        {'url': 'javascript:alert(1)'},
      ];
      expect(
        () => importTrello(
          BoardsState(),
          previewTrello(unsafe),
          title: 'Unsafe',
          confirmed: true,
          includeLinks: true,
        ),
        throwsFormatException,
      );
    },
  );
}
