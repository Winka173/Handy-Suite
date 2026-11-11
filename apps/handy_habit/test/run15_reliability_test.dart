import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/data/store_native.dart';
import 'package:handy_habit/sync/folder_provider.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

String dartExecutable() {
  final flutter = Platform.environment['FLUTTER_ROOT'];
  if (flutter != null)
    return '$flutter/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
  var parent = File(Platform.resolvedExecutable).parent;
  while (parent.path != parent.parent.path) {
    final file = File(
      '${parent.path}/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}',
    );
    if (file.existsSync()) return file.path;
    parent = parent.parent;
  }
  throw StateError('Dart SDK not found for interruption test');
}

void main() {
  test(
    'typed snapshots cannot commit more rows than reopen can read',
    () async {
      final dir = Directory.systemTemp.createTempSync('habit-capacity-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = NativeHabitStore('${dir.path}/habit.sqlite');
      final original = await store.read();
      final large = HabitState(
        revision: 1,
        habits: [
          Habit(
            id: 'h',
            title: 'Read',
            created: '2024-01-01',
            schedules: [Schedule(id: 'g', from: '2024-01-01')],
          ),
        ],
        events: [
          for (var i = 0; i <= 200000; i++)
            HabitEvent(
              id: 'e$i',
              habit: 'h',
              day: '2024-01-01',
              value: 0,
              updated: '2024-01-01T00:00:00Z',
            ),
        ],
      );
      await expectLater(
        store.commit(large, expectedRevision: 0),
        throwsFormatException,
      );
      expect((await store.read()).toJson(), original.toJson());
      expect(await store.integrity(), 'ok');
    },
  );
  test(
    'failed automatic effect rolls back its source; retry and reopen cannot double it',
    () async {
      final dir = Directory.systemTemp.createTempSync('habit-rule-atomic-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = NativeHabitStore('${dir.path}/habit.sqlite');
      final c = HabitController(
        open: () async => store,
        clock: () => DateTime.utc(2024, 1, 8),
      );
      await c.load();
      final h = Habit(
        id: 'water',
        title: 'Water',
        type: 'count',
        created: '2024-01-01',
        schedules: [Schedule(id: 'g', from: '2024-01-01', target: 8000)],
      );
      final r = Routine(
        id: 'morning',
        title: 'Morning',
        steps: [RoutineStep(id: 'step', title: 'Breathe')],
      );
      final session = startSession(r, '2024-01-08', DateTime.utc(2024, 1, 8));
      await c.change(
        (s) => s.copy({
          'habits': [h.toJson()],
          'routines': [r.toJson()],
          'sessions': [session.toJson()],
          'settings': {
            'convenienceRules': [
              ConvenienceRule(
                id: 'rule',
                name: 'Morning water',
                kind: 'routine',
                source: r.id,
                target: h.id,
              ).toJson(),
            ],
          },
        }),
      );
      c.automationAllowed = true;
      final db = database(store.path);
      db.execute(
        "CREATE TRIGGER deny_event BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'disk failure'); END",
      );
      db.close();
      HabitState finish(HabitState s) => s.copy({
        'sessions': [
          session.copy({'status': 'finished', 'anchor': null}).toJson(),
        ],
      });
      await expectLater(c.change(finish), throwsA(isA<Object>()));
      expect(c.state!.sessions.single.status, 'active');
      expect((await store.read()).events, isEmpty);
      final retry = database(store.path);
      retry.execute('DROP TRIGGER deny_event');
      retry.close();
      await c.change(finish);
      expect(c.state!.events.single.note, 'Morning water');
      c.dispose();
      final reopened = HabitController(
        open: () async => store,
        clock: () => DateTime.utc(2024, 1, 8),
      );
      await reopened.load();
      reopened.automationAllowed = true;
      await reopened.change((s) => s);
      expect(reopened.state!.events.length, 1);
      expect(reopened.canUndo, isTrue);
      reopened.dispose();
    },
  );
  for (final mode in ['save', 'restore', 'migration', 'sync']) {
    test(
      'process death during $mode preserves the last committed generation',
      () async {
        final dir = Directory.systemTemp.createTempSync('habit-kill-');
        addTearDown(() => dir.deleteSync(recursive: true));
        final store = NativeHabitStore('${dir.path}/habit.sqlite');
        final c = HabitController(
          open: () async => store,
          clock: () => DateTime.utc(2024, 1, 8),
        );
        await c.load();
        await c.change(
          (s) => s.copy({
            'habits': [
              Habit(
                id: 'h',
                title: 'Read',
                created: '2024-01-01',
                schedules: [Schedule(id: 'g', from: '2024-01-01')],
              ).toJson(),
            ],
          }),
        );
        await c.change(
          (s) => record(
            s,
            HabitEvent(id: 'e', habit: 'h', day: '2024-01-08', value: 1000),
            today: '2024-01-08',
          ),
        );
        final before = jsonEncode((await store.read()).toJson());
        final child = await Process.start(dartExecutable(), [
          'run',
          'tool/interrupted_write.dart',
          mode == 'sync' ? dir.path : store.path,
          mode,
        ]);
        addTearDown(() => child.kill());
        final err = child.stderr.transform(utf8.decoder).join();
        final ready = await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 30));
        expect(ready, 'READY');
        expect(child.kill(), isTrue);
        await child.exitCode;
        await err;
        expect(jsonEncode((await store.read()).toJson()), before);
        expect(await store.integrity(), 'ok');
        if (mode == 'sync')
          expect(
            await FolderSyncProvider(dir.path).list('handy-habit/commits'),
            isEmpty,
          );
        c.dispose();
      },
    );
  }
  test(
    'incremental commit touches one event; stale writer preserves data',
    () async {
      final dir = Directory.systemTemp.createTempSync('habit-delta-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = NativeHabitStore('${dir.path}/habit.sqlite');
      final c = HabitController(open: () async => store);
      await c.load();
      final h = Habit(
        id: 'h',
        title: 'Read',
        created: '2024-01-01',
        schedules: [Schedule(id: 'g', from: '2024-01-01')],
      );
      await c.change(
        (s) => s.copy({
          'habits': [h.toJson()],
        }),
      );
      final before = c.state!;
      final db = database(store.path);
      // A full rewrite would touch this unchanged entity and fail this trigger.
      db.execute(
        "CREATE TRIGGER no_habit_rewrite BEFORE UPDATE ON habits BEGIN SELECT RAISE(ABORT,'unchanged habit rewritten'); END",
      );
      db.close();
      await c.change(
        (s) => record(
          s,
          HabitEvent(id: 'new', habit: 'h', day: '2024-01-08', value: 1000),
          today: '2024-01-08',
        ),
      );
      expect((await store.read()).events.single.id, 'new');
      await expectLater(
        store.commitDelta(before, c.state!, expectedRevision: before.revision),
        throwsStateError,
      );
      c.dispose();
    },
  );
}
