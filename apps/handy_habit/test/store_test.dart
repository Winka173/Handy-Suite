import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:handy_habit/data/store_native.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

void main() {
  late Directory directory;
  late String path;
  late NativeHabitStore store;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('handy-habit-test-');
    path = '${directory.path}/habit.sqlite';
    store = NativeHabitStore(path);
  });
  tearDown(() => directory.deleteSync(recursive: true));
  Habit h() => Habit(
    id: 'h',
    title: 'Read',
    created: '2024-01-01',
    schedules: [Schedule(id: 'v', from: '2024-01-01')],
  );
  test(
    'schema5 negative observations and causal Undo survive SQLite reopening',
    () async {
      final c = HabitController(open: () async => store);
      await c.load();
      await c.change(
        (s) => s.copy({
          'habits': [
            Habit(
              id: 'n',
              title: 'Less sugar',
              type: 'count',
              direction: 'reduce',
              created: '2024-01-01',
              schedules: [Schedule(id: 's', from: '2024-01-01')],
              negativeGoals: [
                NegativeGoal(
                  id: 'g',
                  from: '2024-01-01',
                  window: 'week',
                  limit: 3000,
                ),
              ],
            ).toJson(),
          ],
        }),
      );
      await c.change(
        (s) => setManualTotal(
          s,
          'n',
          '2024-01-07',
          0,
          today: '2024-01-08',
          note: 'None at dinner',
        ),
      );
      final read = await NativeHabitStore(path).read();
      expect(read.habits.single.negativeGoals.single.window, 'week');
      expect(read.events.single.note, 'None at dinner');
      expect(HabitIndex.of(read).known('n', '2024-01-07'), isTrue);
      expect(HabitIndex.of(read).known('n', '2024-01-06'), isFalse);
      c.dispose();
      final reopened = HabitController(
        open: () async => NativeHabitStore(path),
      );
      await reopened.load();
      expect(reopened.canUndo, isTrue);
      await reopened.undo();
      expect(
        HabitIndex.of(
          (await NativeHabitStore(path).read()),
        ).known('n', '2024-01-07'),
        isFalse,
      );
      expect(await store.integrity(), 'ok');
      reopened.dispose();
    },
  );
  test(
    'schema0 migration, FK/WAL, persisted reopening and stale revision guard',
    () async {
      final first = await store.read();
      expect(first.revision, 0);
      final db = sqlite3.open(path);
      expect(db.userVersion, 2);
      expect(db.select('PRAGMA journal_mode').single.values.first, 'wal');
      expect(
        db.select("SELECT name FROM sqlite_master WHERE type='index'").length,
        greaterThan(4),
      );
      db.close();
      final next = HabitState(
        revision: 1,
        habits: [h()],
        settings: {'onboarded': true},
      );
      await store.commit(next, expectedRevision: 0);
      expect((await NativeHabitStore(path).read()).toJson(), next.toJson());
      expect(await store.integrity(), 'ok');
      await expectLater(
        store.commit(next, expectedRevision: 0),
        throwsStateError,
      );
      expect((await store.read()).revision, 1);
    },
  );
  test(
    'actual SQL failure rolls back linked session and event atomically',
    () async {
      await store.read();
      final initial = HabitState(revision: 1, habits: [h()]);
      await store.commit(initial, expectedRevision: 0);
      final db = sqlite3.open(path);
      db.execute(
        "CREATE TRIGGER abort_event BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'test storage failure'); END",
      );
      db.close();
      final session = startSession(
        Routine(
          id: 'r',
          title: 'Read',
          steps: [RoutineStep(id: 'step', title: 'Read', habit: 'h')],
        ),
        '2024-01-01',
        DateTime.utc(2024),
      );
      final staged = completeStep(
        putSession(initial, session),
        session.id,
        expectedStep: 'step',
        today: '2024-01-01',
        now: DateTime.utc(2024),
      ).copy({'revision': 2});
      await expectLater(
        store.commit(staged, expectedRevision: 1),
        throwsA(anything),
      );
      expect((await store.read()).toJson(), initial.toJson());
    },
  );
  test(
    'schema 1 data on disk reads, takes a pause and is written as schema 5',
    () async {
      await store.read();
      // A database written before pauses: its state row says schema 1.
      final db = sqlite3.open(path);
      db.execute('UPDATE state SET revision=1,payload=? WHERE id=1', [
        jsonEncode({
          'app': 'handy-habit',
          'schema': 1,
          'revision': 1,
          'settings': {'onboarded': true},
        }),
      ]);
      db.execute('INSERT INTO habits VALUES(?,?)', [
        'h',
        jsonEncode(h().toJson()),
      ]);
      db.close();
      final old = await store.read();
      expect(old.pauses, isEmpty);
      expect(old.habits.single.id, 'h');
      final next = putPause(
        old,
        Pause(id: 'p', from: '2024-01-02', until: '2024-01-05', reason: 'Huế'),
        today: '2024-01-02',
      ).copy({'revision': 2});
      await store.commit(next, expectedRevision: 1);
      final again = await NativeHabitStore(path).read();
      expect(jsonEncode(again.toJson()), jsonEncode(next.toJson()));
      final raw = sqlite3.open(path);
      final payload =
          jsonDecode(
                raw
                        .select('SELECT payload FROM state WHERE id=1')
                        .single['payload']
                    as String,
              )
              as Map;
      raw.close();
      expect(payload['schema'], habitSchema);
      expect((payload['pauses'] as List).single['reason'], 'Huế');
    },
  );
  test('corruption and unknown future schema preserve original bytes', () async {
    final corrupt = File(path)..writeAsStringSync('not a SQLite database');
    final before = corrupt.readAsBytesSync();
    await expectLater(store.read(), throwsA(anything));
    expect(corrupt.readAsBytesSync(), before);
    final future = '${directory.path}/future.sqlite', db = sqlite3.open(future);
    db.execute(
      'CREATE TABLE preserve(value TEXT); INSERT INTO preserve VALUES(\'important\'); PRAGMA user_version=99;',
    );
    db.close();
    final bytes = File(future).readAsBytesSync();
    await expectLater(NativeHabitStore(future).read(), throwsFormatException);
    expect(File(future).readAsBytesSync(), bytes);
  });
  test(
    '100 habits,100 routines,10k events,1k sessions persist and aggregate',
    () async {
      await store.read();
      final habits = List.generate(
            100,
            (i) => Habit(
              id: 'h$i',
              title: 'Practice $i',
              created: '2024-01-01',
              type: 'count',
              schedules: [Schedule(id: 'v$i', from: '2024-01-01')],
            ),
          ),
          routines = List.generate(
            100,
            (i) => Routine(
              id: 'r$i',
              title: 'Sequence $i',
              steps: [
                RoutineStep(id: 'step$i', title: 'Practice', habit: 'h$i'),
              ],
            ),
          );
      final next = HabitState(
        revision: 1,
        habits: habits,
        routines: routines,
        events: List.generate(
          10000,
          (i) => HabitEvent(
            id: 'e$i',
            habit: 'h${i % 100}',
            day: addDays('2024-01-01', i ~/ 100),
            value: 1000,
          ),
        ),
        sessions: List.generate(
          1000,
          (i) =>
              startSession(
                routines[i % 100],
                '2024-01-01',
                DateTime.utc(2024),
              ).copy({
                'status': 'finished',
                'anchor': null,
                'ended': '2024-01-01T00:01:00Z',
                'steps': [
                  StepRun(
                    plan: routines[i % 100].steps.first,
                    status: 'completed',
                    elapsed: 60,
                  ).toJson(),
                ],
              }),
        ),
      );
      final watch = Stopwatch()..start();
      await store.commit(next, expectedRevision: 0);
      final write = watch.elapsedMilliseconds;
      watch.reset();
      final loaded = await store.read();
      debugPrint(
        'Habit SQLite 10k events/1k sessions writeMs=$write readMs=${watch.elapsedMilliseconds}',
      );
      expect(loaded.events.length, 10000);
      expect(loaded.sessions.length, 1000);
      expect(HabitIndex(loaded.events).value('h0', '2024-01-01'), 1000);
      expect(jsonEncode(loaded.toJson()), jsonEncode(next.toJson()));
      expect(await store.integrity(), 'ok');
    },
  );
  test(
    'controller publishes only after commit and Undo survives an unrelated error',
    () async {
      final controller = HabitController(open: () async => store);
      await controller.load();
      await controller.change(
        (s) => s.copy({
          'habits': [h().toJson()],
        }),
      );
      expect(controller.state!.habits.length, 1);
      await expectLater(
        controller.change(
          (s) => s.copy({
            'habits': [h().toJson(), h().toJson()],
          }),
        ),
        throwsFormatException,
      );
      expect(controller.state!.habits.length, 1);
      await controller.undo();
      expect(controller.state!.habits, isEmpty);
      controller.dispose();
    },
  );
}
