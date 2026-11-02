import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'engine_test.dart' show fixture, withTask;

BoardRecord recurrence(String id, {String start = '2026-11-01'}) =>
    BoardRecord({
      'id': id,
      'task': 't',
      'board': 'b',
      'frequency': 'daily',
      'start': start,
      'zone': 'Asia/Ho_Chi_Minh',
      'interval': 1,
    });
void main() {
  test('exam metadata validates bounds and stays canonical through backup', () {
    var s = withTask(fixture());
    s = s.put(
      'tasks',
      s.get('tasks', 't').copy({
        'kind': 'exam',
        'exam': {
          'durationMinutes': 90,
          'location': 'Phòng A',
          'materials': 'Máy tính',
        },
      }),
    );
    expect(readBackup(exportBackup(s)).toJson(), s.toJson());
    for (final duration in [0, -1, 1441, '90'])
      expect(
        () => s
            .put(
              'tasks',
              s.get('tasks', 't').copy({
                'exam': {'durationMinutes': duration},
              }),
            )
            .validate(),
        throwsFormatException,
      );
  });
  test(
    'image attachment original and preview paths survive validation and ZIP merge',
    () {
      var s = withTask(fixture());
      final original = img.encodePng(img.Image(width: 12, height: 8)),
          preview = attachmentPreview(original);
      s = s
          .copy(
            files: {
              'assets/original.png': original,
              'assets/preview.jpg': preview,
            },
          )
          .put(
            'attachments',
            BoardRecord({
              'id': 'image',
              'task': 't',
              'board': 'b',
              'name': 'Image',
              'path': 'assets/original.png',
              'preview': 'assets/preview.jpg',
              'sha256': sha256.convert(original).toString(),
            }),
          );
      s.validate();
      final restored = readBackup(exportBackup(s));
      expect(restored.toJson(), s.toJson());
      final merged = restoreBackup(
            BoardsState(),
            restored,
            replace: false,
            confirmed: true,
          ),
          attachment = merged.rows('attachments').single;
      expect(merged.files[attachment.str('path')], original);
      expect(merged.files[attachment.str('preview')], preview);
      expect(
        () => s
            .put(
              'events',
              BoardRecord({
                'id': 'bad',
                'task': 't',
                'at': 'bad',
                'action': 'completed',
              }),
            )
            .validate(),
        throwsFormatException,
      );
    },
  );
  test(
    'malformed UI-facing backup fields are rejected before publishing state',
    () {
      final s = withTask(fixture()), category = s.rows('categories').first;
      for (final field in [
        {'color': 'blue'},
        {'preview': -1},
        {'priorityWeight': -1},
      ])
        expect(
          () => readBackup(
            exportBackup(s.put('categories', category.copy(field))),
          ),
          throwsFormatException,
        );
      for (final prefs in [
        {'locale': 3},
        {'locale': 'invalid-locale'},
        {'theme': 'invalid-theme'},
        {'homeWidget': 'true'},
        {'notifications': 1},
        {'historyDays': 'forever'},
        {
          'tableColumns': {'b': 'bad'},
        },
        {
          'categoryLayout': {
            'b': {'collapsed': 42},
          },
        },
      ])
        expect(
          () => s.copy(preferences: prefs).validate(),
          throwsFormatException,
        );
      expect(
        () => s
            .put(
              'views',
              BoardRecord({
                'id': 'view',
                'board': 'b',
                'sort': 'unknown',
                'conditions': [],
              }),
            )
            .validate(),
        throwsFormatException,
      );
    },
  );
  test(
    'templates clone checklist structure with new IDs and reset completion',
    () {
      var s = withTask(fixture());
      s = s.put(
        'checklist',
        BoardRecord({
          'id': 'check',
          'task': 't',
          'title': 'Review',
          'order': 3,
          'done': true,
        }),
      );
      final next = applyBoardTemplate(
        BoardsState(),
        readTemplatePackage(exportTemplatePackage(s, 'b'))!,
        title: 'Copy',
        confirmed: true,
      );
      final check = next.rows('checklist').single;
      expect(check.id, isNot('check'));
      expect(check.flag('done'), false);
      expect(check.number('order'), 3);
      expect(check.str('task'), next.rows('tasks').single.id);
    },
  );
  test('mixed deadlines reject a reversed start', () {
    var s = withTask(withTask(fixture()), id: 'u');
    s = s.put(
      'tasks',
      s.get('tasks', 't').copy({
        'estimate': 30,
        'due': {'kind': 'day', 'day': '2026-11-05'},
      }),
    );
    s = s.put(
      'tasks',
      s.get('tasks', 'u').copy({
        'estimate': 30,
        'start': {'kind': 'day', 'day': '2026-11-04'},
      }),
    );
    s = addDependency(s, 't', 'u');
    final invalid = s.put(
      'tasks',
      s.get('tasks', 'u').copy({
        'due': {
          'kind': 'time',
          'at': '2026-11-02T12:00:00Z',
          'zone': 'Asia/Ho_Chi_Minh',
        },
      }),
    );
    expect(invalid.validate, throwsFormatException);
  });
  test(
    'grade threshold form notation validates labels/values and preserves decimals',
    () {
      final letters = parseGradeThresholds('A+ = 92.5\nB = 80\nF = 0');
      expect(presentGrade(92.5, 'letter', letters: letters), 'A+');
      expect(
        () => parseGradeThresholds('A = 90\nB = 90'),
        throwsFormatException,
      );
      expect(
        () => parseGradeThresholds('A = 90\nA = 80'),
        throwsFormatException,
      );
      expect(() => parseGradeThresholds('A = NaN'), throwsFormatException);
      expect(() => parseGradeThresholds('A = 101'), throwsFormatException);
    },
  );
  test(
    'summary uses each board timezone and zero-duration milestones are known',
    () {
      var s = withTask(fixture());
      s = s.put(
        'boards',
        s.get('boards', 'b').copy({'zone': 'America/New_York'}),
      );
      s = s.put(
        'tasks',
        s.get('tasks', 't').copy({
          'kind': 'milestone',
          'estimate': 0,
          'due': {'kind': 'day', 'day': '2026-11-01'},
        }),
      );
      final stats = summary(s, topTasks(s), now: DateTime.utc(2026, 11, 2, 2));
      expect(stats['overdue'], 0);
      expect(stats['unknownEstimates'], 0);
      expect(workload(s, 'b')['2026-11-01']!['unknown'], 0);
      expect(
        () => s.put('unknown', BoardRecord({'id': 'x'})),
        throwsArgumentError,
      );
    },
  );
  test(
    'weekly workload sums saved values and counts overloaded days without inventing capacity',
    () {
      final buckets = workloadBuckets({
        'days': {
          '2026-11-01': {
            'minutes': 60,
            'unknown': 1,
            'actualSeconds': 120,
            'overloaded': true,
          },
          '2026-11-02': {'minutes': 30, 'actualSeconds': 60},
          '2026-11-03': {
            'minutes': 40,
            'actualSeconds': 80,
            'overloaded': true,
          },
        },
      }, weekly: true);
      expect(buckets['2026-10-26']!['minutes'], 60);
      expect(buckets['2026-11-02']!['minutes'], 70);
      expect(buckets['2026-11-02']!['actualSeconds'], 140);
      expect(buckets['2026-11-02']!['overloadedDays'], 1);
      expect(buckets['2026-11-02']!.containsKey('capacity'), false);
    },
  );
  test(
    'history uses retained transitions in board timezone and never repeats unchanged completion',
    () {
      var s = withTask(fixture());
      s = s.put(
        'boards',
        s.get('boards', 'b').copy({'zone': 'America/New_York'}),
      );
      final done = s.rows('statuses').last.id,
          todo = s.get('tasks', 't').str('status');
      s = changeStatus(s, 't', done, now: DateTime.utc(2026, 11, 2, 4, 30));
      s = changeStatus(s, 't', done, now: DateTime.utc(2026, 11, 2, 4, 40));
      s = changeStatus(s, 't', todo, now: DateTime.utc(2026, 11, 2, 5, 30));
      s = changeStatus(s, 't', done, now: DateTime.utc(2026, 11, 2, 6, 30));
      final history = completionHistory(
        s,
        DateTime.utc(2026, 11, 2, 12),
        board: 'b',
        days: 2,
      );
      expect(history, {'2026-11-01': 1, '2026-11-02': 1});
      final removed = s.remove(
        'events',
        s.rows('events').map((e) => e.id).toSet(),
      );
      expect(
        completionHistory(
          removed,
          DateTime.utc(2026, 11, 2, 12),
          board: 'b',
          days: 2,
        ).values.every((v) => v == 0),
        true,
      );
    },
  );
  test(
    'saved OR/AND views handle archived records, repeated properties and grouped ranges',
    () {
      var s = withTask(withTask(fixture()), id: 'u');
      s = s.put(
        'tasks',
        s.get('tasks', 'u').copy({
          'archived': true,
          'priority': 3,
          'estimate': 45,
        }),
      );
      BoardRecord view(String mode, List<Json> conditions) => BoardRecord({
        'id': 'v',
        'board': 'b',
        'mode': mode,
        'conditions': conditions,
      });
      expect(
        smartViewTasks(
          s,
          view('and', [
            {'archived': true},
            {'priority': 3},
            {'estimateMin': 30, 'estimateMax': 50},
          ]),
        ).single.id,
        'u',
      );
      expect(
        smartViewTasks(
          s,
          view('or', [
            {'priority': 1},
            {'priority': 3},
          ]),
        ).map((t) => t.id).toSet(),
        {'t'},
      );
      expect(
        smartViewTasks(
          s,
          view('or', [
            {'priority': 1},
            {'archived': true},
          ]),
        ).map((t) => t.id).toSet(),
        {'t', 'u'},
      );
      expect(
        () => validateTaskFilter({'estimateMin': 50, 'estimateMax': 10}),
        throwsFormatException,
      );
      expect(
        () => validateTaskFilter({'hasReminder': 'yes'}),
        throwsFormatException,
      );
      expect(
        () => validateTaskFilter({'unknown': true}),
        throwsFormatException,
      );
    },
  );
  test('timeline shifts both dates atomically and rejects reversed resize', () {
    var s = withTask(fixture());
    s = s.put(
      'tasks',
      s.get('tasks', 't').copy({
        'start': {'kind': 'day', 'day': '2026-11-05'},
        'due': {'kind': 'day', 'day': '2026-11-07'},
      }),
    );
    final moved = shiftTaskDates(s, 't', -4);
    expect(object(moved.get('tasks', 't').data['start'])['day'], '2026-11-01');
    expect(object(moved.get('tasks', 't').data['due'])['day'], '2026-11-03');
    expect(
      () => shiftTaskDates(s, 't', -3, resizeEnd: true),
      throwsFormatException,
    );
    final resized = shiftTaskDates(s, 't', 2, resizeEnd: true);
    expect(
      object(resized.get('tasks', 't').data['start'])['day'],
      '2026-11-05',
    );
    expect(object(resized.get('tasks', 't').data['due'])['day'], '2026-11-09');
    expect(changeStatus(s, 't', s.get('tasks', 't').str('status')), same(s));
  });
  test(
    'template ZIP package round trip rejects checksum and path tampering',
    () {
      final s = withTask(fixture()).put('recurrence', recurrence('rec'));
      final bytes = exportTemplatePackage(s, 'b', includeRecurrence: true),
          template = readTemplatePackage(bytes)!;
      expect(template, exportBoardTemplate(s, 'b', includeRecurrence: true));
      final next = applyBoardTemplate(
        BoardsState(),
        template,
        title: 'From ZIP',
        confirmed: true,
        includeRecurrence: true,
      );
      expect(next.rows('tasks').length, 1);
      expect(next.rows('recurrence').length, 1);
      expect(readTemplatePackage(exportBackup(s)), isNull);
      final altered = ZipDecoder().decodeBytes(bytes);
      altered.addFile(ArchiveFile('template.json', 2, utf8.encode('{}')));
      expect(
        () => readTemplatePackage(
          Uint8List.fromList(ZipEncoder().encode(altered)),
        ),
        throwsFormatException,
      );
      final unsafe = Archive()
        ..addFile(ArchiveFile('../template.json', 2, utf8.encode('{}')));
      expect(
        () => readTemplatePackage(
          Uint8List.fromList(ZipEncoder().encode(unsafe)),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'advanced filters intersect reminder/estimate/assignee/archive and search links',
    () {
      var s = withTask(withTask(fixture()), id: 'u');
      s = s.put(
        'tasks',
        s.get('tasks', 't').copy({'estimate': 45, 'assignee': 'An'}),
      );
      s = s.put(
        'tasks',
        s.get('tasks', 'u').copy({
          'archived': true,
          'estimate': 60,
          'assignee': 'An',
        }),
      );
      s = s.put(
        'reminders',
        BoardRecord({
          'id': 'alarm',
          'task': 't',
          'board': 'b',
          'at': '2026-11-03T00:00:00Z',
          'enabled': true,
        }),
      );
      s = s.put(
        'attachments',
        BoardRecord({
          'id': 'link',
          'task': 't',
          'url': 'https://example.com/manual-vi',
          'name': 'Reference',
        }),
      );
      expect(
        queryTasks(
          s,
          filter: {
            'estimateMin': 30,
            'estimateMax': 50,
            'assignee': 'An',
            'hasReminder': true,
          },
        ).single.id,
        't',
      );
      expect(queryTasks(s, filter: {'hasReminder': false}), isEmpty);
      expect(queryTasks(s, filter: {'archived': true}).single.id, 'u');
      expect(queryTasks(s, search: 'manual-vi').single.id, 't');
      expect(queryTasks(s).single.id, 't');
    },
  );
  test(
    'template custom defaults/subtasks and recurrence require explicit opt-in',
    () {
      var s = withTask(withTask(fixture()), id: 'child', parent: 't');
      s = s.put(
        'fields',
        BoardRecord({
          'id': 'field',
          'board': 'b',
          'title': 'Channel',
          'type': 'single',
          'options': ['Web', 'Mobile'],
          'default': 'Web',
        }),
      );
      s = s.put('recurrence', recurrence('rec'));
      final safe = exportBoardTemplate(s, 'b');
      expect(safe['recurrence'], isEmpty);
      final template = exportBoardTemplate(s, 'b', includeRecurrence: true);
      expect((template['recurrence'] as List).length, 1);
      final without = applyBoardTemplate(
        BoardsState(),
        template,
        title: 'Without',
        confirmed: true,
      );
      expect(without.rows('recurrence'), isEmpty);
      final next = applyBoardTemplate(
        BoardsState(),
        template,
        title: 'Copy',
        confirmed: true,
        includeRecurrence: true,
      );
      next.validate();
      expect(next.rows('tasks').length, 2);
      expect(
        next.rows('tasks').where((r) => r.data['parent'] != null).length,
        1,
      );
      final field = next.rows('fields').single;
      expect(field.id, isNot('field'));
      expect(
        next
            .rows('tasks')
            .every((r) => object(r.data['custom'])[field.id] == 'Web'),
        true,
      );
      expect(next.rows('recurrence').single.flag('enabled'), false);
      expect(next.rows('occurrences'), isEmpty);
      expect(next.rows('events'), isEmpty);
      expect(next.rows('attachments'), isEmpty);
    },
  );
  test(
    'calendar reschedule preserves UUID/category and rejects DST gaps and folds',
    () {
      var s = withTask(fixture());
      s = s.put(
        'boards',
        s.get('boards', 'b').copy({'zone': 'America/New_York'}),
      );
      s = s.put(
        'tasks',
        s.get('tasks', 't').copy({
          'due': {
            'kind': 'time',
            'at': '2026-03-07T07:30:15.123Z',
            'zone': 'America/New_York',
          },
        }),
      );
      expect(() => rescheduleTask(s, 't', '2026-03-08'), throwsFormatException);
      final next = rescheduleTask(s, 't', '2026-03-09');
      expect(
        object(next.get('tasks', 't').data['due'])['at'],
        '2026-03-09T06:30:15.123Z',
      );
      expect(
        next.get('tasks', 't').str('category'),
        s.get('tasks', 't').str('category'),
      );
      expect(next.rows('tasks').single.id, 't');
      s = s.put(
        'tasks',
        s.get('tasks', 't').copy({
          'due': {
            'kind': 'time',
            'at': '2026-10-31T05:30:00Z',
            'zone': 'America/New_York',
          },
        }),
      );
      expect(() => rescheduleTask(s, 't', '2026-11-01'), throwsFormatException);
      expect(
        object(
          rescheduleTask(
            s,
            't',
            '2026-11-01',
            lateFold: true,
          ).get('tasks', 't').data['due'],
        )['at'],
        '2026-11-01T06:30:00.000Z',
      );
      expect(() => rescheduleTask(s, 't', '2026-02-30'), throwsFormatException);
    },
  );
  test(
    'app-open reconciliation is bounded and once per local day after restart',
    () {
      var s = withTask(withTask(fixture()), id: 'u');
      s = s.put(
        'rules',
        BoardRecord({
          'id': 'rule',
          'board': 'b',
          'enabled': true,
          'trigger': 'opened',
          'actions': [
            {'type': 'checklist', 'value': 'Review'},
          ],
        }),
      );
      final now = DateTime.utc(2026, 11, 2, 1);
      s = reconcileOpenRules(s, now, taskLimit: 1);
      expect(s.rows('checklist').length, 1);
      s = reconcileOpenRules(
        BoardsState.fromJson(s.toJson()),
        now,
        taskLimit: 1,
      );
      expect(s.rows('checklist').length, 2);
      expect(reconcileOpenRules(s, now).toJson(), s.toJson());
      s = reconcileOpenRules(s, now.add(const Duration(days: 1)));
      expect(s.rows('checklist').length, 4);
      expect(s.rows('executions').every((e) => e.flag('delayed')), true);
      expect(
        () => reconcileOpenRules(s, now, taskLimit: 501),
        throwsFormatException,
      );
    },
  );
  test(
    'recurrence recovery catches excessive historic ranges without losing tasks',
    () {
      var s = withTask(fixture()).put('recurrence', recurrence('rule'));
      final now = DateTime.utc(2026, 11, 2);
      s = reconcileRecurrences(s, now);
      expect(s.rows('occurrences').length, 9);
      expect(reconcileRecurrences(s, now).toJson(), s.toJson());
      s = s.put('recurrence', recurrence('old', start: '2000-01-01'));
      s = reconcileRecurrences(s, now);
      expect(s.get('recurrence', 'old').flag('reviewRequired'), true);
      expect(s.get('tasks', 't').str('title'), isNotEmpty);
    },
  );
  test(
    'automation preview is pure; reminders and generation survive merged backup',
    () {
      var s = withTask(fixture()).put('recurrence', recurrence('rec'));
      final status = s.rows('statuses').last.id;
      s = s.put(
        'rules',
        BoardRecord({
          'id': 'rule',
          'board': 'b',
          'enabled': true,
          'trigger': 'created',
          'actions': [
            {'type': 'remindMinutes', 'value': 30},
            {'type': 'generate', 'value': 'rec'},
            {'type': 'suggestStatus', 'value': status},
          ],
        }),
      );
      final original = s.toJson(), now = DateTime.utc(2026, 11, 2);
      final preview = runAutomations(
        s,
        't',
        'created',
        'event',
        now: now,
        preview: true,
      );
      expect(s.toJson(), original);
      expect(
        preview.rows('reminders').single.str('at'),
        now.add(const Duration(minutes: 30)).toIso8601String(),
      );
      expect(preview.get('tasks', 't').str('suggestedStatus'), status);
      expect(
        preview.get('tasks', 't').str('status'),
        s.get('tasks', 't').str('status'),
      );
      expect(
        runAutomations(preview, 't', 'created', 'event', now: now).toJson(),
        preview.toJson(),
      );
      final merged = restoreBackup(
        BoardsState(),
        readBackup(exportBackup(preview)),
        replace: false,
        confirmed: true,
      );
      merged.validate();
      final action = object(
        (merged.rows('rules').single.data['actions'] as List)[1],
      );
      expect(action['value'], merged.rows('recurrence').single.id);
      expect(merged.rows('reminders').single.flag('enabled'), false);
      expect(
        () => preview
            .put(
              'executions',
              BoardRecord({'id': 'bad', 'task': 't', 'rule': 'missing'}),
            )
            .validate(),
        throwsFormatException,
      );
    },
  );
  test('image preview preserves original bytes and caps dimensions', () {
    final original = img.encodePng(img.Image(width: 1200, height: 800));
    final copy = List<int>.of(original), preview = attachmentPreview(original);
    expect(preview, isNotNull);
    expect(img.decodeImage(preview)!.width, 640);
    expect(original, copy);
    expect(
      attachmentPreview(img.encodePng(img.Image(width: 2, height: 3))),
      isNotNull,
    );
    expect(
      () => attachmentPreview(original.sublist(0, 10)),
      throwsFormatException,
    );
  });
}
