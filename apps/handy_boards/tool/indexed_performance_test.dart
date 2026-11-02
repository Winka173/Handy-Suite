import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/data/store_native.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

void main() {
  test(
    'measure real SQLite 50000 canonical tasks and indexed page latency',
    () async {
      final dir = await Directory.systemTemp.createTemp('boards-indexed-perf-');
      final store = NativeBoardsStore(
        '${dir.path}/boards.sqlite',
        diagnostics: (phase) => stdout.writeln(phase),
      );
      final timing = <String, int>{};
      final count = int.parse(
        Platform.environment['BOARDS_PERF_COUNT'] ?? '50000',
      );
      try {
        await store.read();
        final timer = Stopwatch()..start();
        var s = createBoard(BoardsState(), 'Performance', boardId: 'b');
        final edit = BoardsEdit(s);
        for (var i = 0; i < count; i++)
          edit.put(
            'tasks',
            newTask(s, 'b', 'Bài tập $i').copy({
              'id': 'task-$i',
              'order': i,
              'notes': i % 17 == 0 ? 'Ôn vật lý' : 'Java',
              'priority': i % 4,
            }),
          );
        s = edit.finish().copy(revision: 1);
        timing['fixtureMs'] = timer.elapsedMilliseconds;
        stdout.writeln('Fixture ready: ${timing['fixtureMs']} ms');
        timer.reset();
        await store.commit(s, expectedRevision: 0);
        timing['commitMs'] = timer.elapsedMilliseconds;
        stdout.writeln('Commit ready: ${timing['commitMs']} ms');
        timer.reset();
        await store.read();
        timing['reopenValidateMs'] = timer.elapsedMilliseconds;
        timer.reset();
        final page = await store.taskPage(
          board: 'b',
          search: 'on vat',
          sort: 'priority',
          limit: 100,
        );
        timing['indexedQueryMs'] = timer.elapsedMilliseconds;
        expect(page.total, (count + 16) ~/ 17);
        expect(page.tasks.length, 100);
        final result = {
          'fixture': '$count tasks, 1 board; Windows host process',
          'timings': timing,
          'currentRssBytes': ProcessInfo.currentRss,
          'maxRssBytes': ProcessInfo.maxRss,
          'matchingTasks': page.total,
          'pageSize': page.tasks.length,
          'generatedAt': DateTime.now().toUtc().toIso8601String(),
        };
        final output = File(
          '../../docs/qa/evidence/boards-indexed-performance.json',
        );
        await output.writeAsString(
          const JsonEncoder.withIndent('  ').convert(result),
        );
        stdout.writeln(jsonEncode(result));
      } finally {
        store.close();
        await dir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
