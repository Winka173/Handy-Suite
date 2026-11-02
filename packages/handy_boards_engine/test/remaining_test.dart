import 'dart:convert';
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
  test(
    'working calendar skips weekends/holidays and honors custom resource days',
    () {
      final calendar = {
        'weekdays': [1, 2, 3, 4, 5],
        'holidays': ['2026-11-02'],
        'minutesPerDay': 480,
        'startMinute': 540,
      };
      final p = projectWorkingDuration(calendar, '2026-10-30', 960);
      expect(p['start'], '2026-10-30');
      expect(p['finish'], '2026-11-03');
      expect(p['workingDays'], 2);
      expect(
        projectWorkingDuration(calendar, '2026-10-31', 1)['start'],
        '2026-11-03',
      );
      expect(
        () => validateWorkingCalendar({'weekdays': []}),
        throwsFormatException,
      );
      expect(
        () => validateWorkingCalendar({
          'minutesPerDay': 1000,
          'startMinute': 540,
        }),
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
      expect(
        isWorkingDay(
          boardWorkingCalendar(s, 'b', assignee: 'An'),
          '2026-11-01',
        ),
        true,
      );
      expect(isWorkingDay(boardWorkingCalendar(s, 'b'), '2026-11-01'), false);
      expect(readBackup(exportBackup(s)).toJson(), s.toJson());
    },
  );
  test('v1 state and backup metadata migrate forward without changing IDs', () {
    final s = withTask(fixture()), j = s.toJson()..['schema'] = 1;
    final migrated = BoardsState.fromJson(j);
    expect(migrated.get('tasks', 't').data, s.get('tasks', 't').data);
    expect(migrated.toJson()['schema'], 2);
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
  test(
    'Study reports retain unknown scores and provide actual task/exam counts',
    () {
      var s = withTask(fixture());
      final cat = s.get('tasks', 't').str('category');
      s = s.put(
        'subjects',
        BoardRecord({
          'id': 'subject',
          'board': 'b',
          'category': cat,
          'target': 90,
          'credits': 3,
        }),
      );
      s = s.put(
        'tasks',
        s.get('tasks', 't').copy({
          'kind': 'exam',
          'due': {'kind': 'day', 'day': '2026-11-01'},
        }),
      );
      for (final g in [
        BoardRecord({
          'id': 'g1',
          'board': 'b',
          'category': cat,
          'title': 'Midterm',
          'weight': 50,
          'possible': 10,
          'earned': 2,
        }),
        BoardRecord({
          'id': 'g2',
          'board': 'b',
          'category': cat,
          'title': 'Final',
          'weight': 50,
          'possible': 10,
        }),
      ])
        s = s.put('grades', g);
      final report = studyReport(s, 'b', DateTime.utc(2026, 11, 2)),
          row = object((report['subjects'] as List).first);
      expect(row['graded'], 1);
      expect(row['assessments'], 2);
      expect(row['exams'], 1);
      expect(object(row['grade'])['feasible'], false);
      expect(row['reasons'], contains('target infeasible'));
      expect(
        utf8.encode(studyReportCsv(s, 'b', DateTime.utc(2026, 11, 2))),
        isNotEmpty,
      );
      expect(s.get('grades', 'g2').data['earned'], null);
    },
  );
}
