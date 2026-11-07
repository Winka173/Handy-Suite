import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

import 'engine_test.dart' show fixture;

void main() {
  test(
    'measure canonical task operations at 100/1000/10000/50000',
    () {
      final metrics = <Map<String, dynamic>>[];
      for (final count in [100, 1000, 10000, 50000]) {
        final base = fixture(title: 'Performance'),
            category = base.rows('categories').first.id,
            status = base.rows('statuses').first.id,
            watch = Stopwatch()..start();
        final s = base.copy(
          data: {
            for (final k in kinds)
              k: k == 'tasks'
                  ? List.generate(
                      count,
                      (i) => BoardRecord({
                        'id': 'task-$i',
                        'board': 'b',
                        'title': 'Task $i — Công việc',
                        'notes': 'Local notes',
                        'status': status,
                        'category': category,
                        'priority': i % 4,
                        'order': i,
                        'estimate': i % 3 == 0 ? 30 : 0,
                      }),
                    )
                  : base.rows(k),
          },
        );
        final construct = watch.elapsedMilliseconds;
        watch.reset();
        s.validate();
        final validate = watch.elapsedMilliseconds;
        watch.reset();
        final found = queryTasks(
          s,
          board: 'b',
          search: 'cong viec',
          sort: 'priority',
        );
        final search = watch.elapsedMilliseconds;
        expect(found.length, count);
        watch.reset();
        final bytes = exportBackup(s);
        final export = watch.elapsedMilliseconds;
        watch.reset();
        final restored = readBackup(bytes);
        final restore = watch.elapsedMilliseconds;
        expect(restored.rows('tasks').length, count);
        expect(restored.toJson(), s.toJson());
        metrics.add({
          'tasks': count,
          'constructMs': construct,
          'validateMs': validate,
          'unicodeSearchSortMs': search,
          'zipExportMs': export,
          'zipRestoreMs': restore,
          'zipBytes': bytes.length,
          'processRssBytes': ProcessInfo.currentRss,
        });
      }
      final dir = Directory('../../docs/qa/evidence')
        ..createSync(recursive: true);
      File('${dir.path}/boards-performance.json').writeAsStringSync(
        jsonEncode({
          'scope':
              'host pure-Dart; not mobile scroll/startup or native indexed queries',
          'measurements': metrics,
        }),
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
