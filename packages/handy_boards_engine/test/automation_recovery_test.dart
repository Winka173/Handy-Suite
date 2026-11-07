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
Json legacyTemplate() => {
  'app': 'handy-boards-template',
  'schema': 1,
  'categories': <Json>[],
  'statuses': [
    {'id': 's0', 'title': 'To Do'},
    {'id': 's1', 'title': 'Done', 'done': true},
  ],
  'tasks': [
    {'id': 't0', 'title': 'Work'},
  ],
};

Uint8List legacyTemplatePackage(Json template) {
  final payload = utf8.encode(jsonEncode(template));
  final manifest = utf8.encode(
    jsonEncode({
      'app': 'handy-boards-template-package',
      'schema': 1,
      'file': 'template.json',
      'bytes': payload.length,
      'sha256': sha256.convert(payload).toString(),
    }),
  );
  final archive = Archive()
    ..addFile(ArchiveFile('template.json', payload.length, payload))
    ..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

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
      expect(
        () => s.put('unknown', BoardRecord({'id': 'x'})),
        throwsArgumentError,
      );
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
    'legacy templates clone checklist structure with new IDs and reset completion',
    () {
      final template = legacyTemplate();
      template['checklist'] = [
        {
          'id': 'check',
          'task': 't0',
          'title': 'Review',
          'order': 3,
          'done': true,
        },
      ];
      final next = applyBoardTemplate(
        BoardsState(),
        template,
        title: 'Copy',
        confirmed: true,
      );
      final check = next.rows('checklist').single;
      expect(check.id, isNot('check'));
      expect(check.flag('done'), false);
      expect(check.number('order'), 3);
      expect(check.str('task'), next.rows('tasks').single.id);
      expect(next.rows('tasks').single.id, isNot('t0'));
      expect(next.rows('events'), isEmpty);
      expect(next.rows('attachments'), isEmpty);
      next.validate();
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
    s = s.put(
      'dependencies',
      BoardRecord({'id': 'dep', 'before': 't', 'after': 'u'}),
    );
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

  test('legacy saved-view filter conditions still validate', () {
    expect(
      () => validateTaskFilter({'estimateMin': 50, 'estimateMax': 10}),
      throwsFormatException,
    );
    expect(
      () => validateTaskFilter({'hasReminder': 'yes'}),
      throwsFormatException,
    );
    expect(() => validateTaskFilter({'unknown': true}), throwsFormatException);
  });

  test('legacy template ZIP reader rejects checksum and path tampering', () {
    final template = legacyTemplate(), bytes = legacyTemplatePackage(template);
    expect(readTemplatePackage(bytes), template);
    final next = applyBoardTemplate(
      BoardsState(),
      readTemplatePackage(bytes)!,
      title: 'From ZIP',
      confirmed: true,
    );
    expect(next.rows('tasks').length, 1);
    expect(readTemplatePackage(exportBackup(withTask(fixture()))), isNull);
    final altered = ZipDecoder().decodeBytes(bytes);
    altered.addFile(ArchiveFile('template.json', 2, utf8.encode('{}')));
    expect(
      () =>
          readTemplatePackage(Uint8List.fromList(ZipEncoder().encode(altered))),
      throwsFormatException,
    );
    final unsafe = Archive()
      ..addFile(ArchiveFile('../template.json', 2, utf8.encode('{}')));
    expect(
      () =>
          readTemplatePackage(Uint8List.fromList(ZipEncoder().encode(unsafe))),
      throwsFormatException,
    );
  });
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
    'legacy template custom defaults/subtasks and recurrence require explicit opt-in',
    () {
      final template = legacyTemplate();
      template['tasks'] = [
        {'id': 't0', 'title': 'Work'},
        {'id': 'child', 'title': 'Child', 'parent': 't0'},
      ];
      template['fields'] = [
        {
          'id': 'field',
          'title': 'Channel',
          'type': 'single',
          'options': ['Web', 'Mobile'],
          'default': 'Web',
        },
      ];
      template['recurrence'] = [
        {
          'id': 'rec',
          'task': 't0',
          'frequency': 'daily',
          'start': '2026-11-01',
          'zone': 'Asia/Ho_Chi_Minh',
        },
      ];
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

  test('legacy rules and recurrence survive a merged backup', () {
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
    final preview = s;
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
    expect(
      () => preview
          .put(
            'executions',
            BoardRecord({'id': 'bad', 'task': 't', 'rule': 'missing'}),
          )
          .validate(),
      throwsFormatException,
    );
  });
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
