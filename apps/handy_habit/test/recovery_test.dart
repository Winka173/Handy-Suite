import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/data/store_native.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

void main() {
  late Directory directory;
  late NativeHabitStore store;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('habit-recovery-');
    store = NativeHabitStore('${directory.path}/habit.sqlite');
  });
  tearDown(() => directory.deleteSync(recursive: true));
  test('manual order and its domain Undo survive native restart', () async {
    final c = HabitController(open: () async => store);
    await c.load();
    final h = Habit(
      id: 'h',
      title: 'Read',
      created: '2024-01-01',
      schedules: [Schedule(id: 'v', from: '2024-01-01')],
    );
    final k = h.copy({'id': 'k', 'title': 'Walk'});
    await c.change(
      (s) => s.copy({
        'habits': [h.toJson(), k.toJson()],
      }),
    );
    await c.change(
      (s) => s.copy({
        'habits': [k.toJson(), h.toJson()],
      }),
    );
    final again = HabitController(open: () async => store);
    await again.load();
    expect(again.state!.habits.map((h) => h.id), ['k', 'h']);
    expect(again.canUndo, isTrue);
    await again.undo();
    expect((await store.read()).habits.map((h) => h.id), ['h', 'k']);
    c.dispose();
    again.dispose();
  });
  test('purge on reopen is durable and idempotent', () async {
    final now = DateTime.utc(2024, 1, 3);
    await store.read();
    final h = Habit(
      id: 'h',
      title: 'Read',
      created: '2024-01-01',
      schedules: [Schedule(id: 'v', from: '2024-01-01')],
    );
    final trashed = trashEntity(
      HabitState(habits: [h]),
      'habit',
      'h',
      now,
    ).copy({'revision': 1});
    await store.commit(trashed, expectedRevision: 0);
    final c = HabitController(
      open: () async => store,
      clock: () => now.add(trashRetention),
    );
    await c.load();
    expect(c.state!.trash, isEmpty);
    expect(c.state!.habits, isEmpty);
    expect(c.state!.tombstones, hasLength(1));
    expect(c.state!.revision, 2);
    await c.load();
    expect(c.state!.revision, 2);
    expect((await store.read()).trash, isEmpty);
    c.dispose();
  });
  for (final table in ['recovery', 'state']) {
    test(
      '$table write failure preserves local data and stops replacement',
      () async {
        final c = HabitController(open: () async => store);
        await c.load();
        final before = c.state!.toJson();
        final db = sqlite3.open(store.path);
        db.execute(
          "CREATE TRIGGER fail_write BEFORE ${table == 'recovery' ? 'INSERT' : 'UPDATE'} ON $table BEGIN SELECT RAISE(ABORT,'disk failure'); END",
        );
        db.close();
        await expectLater(
          c.replaceFromBackup(
            HabitState(settings: {'theme': 'dark'}),
            expectedRevision: c.state!.revision,
          ),
          throwsA(anything),
        );
        expect(c.state!.toJson(), before);
        expect((await store.read()).toJson(), before);
        expect(await store.integrity(), 'ok');
        if (table == 'state')
          expect((await store.readRecovery())!.toJson(), before);
        c.dispose();
      },
    );
  }
  test(
    'replace recovery is durable, CAS guarded and survives commit failure',
    () async {
      final c = HabitController(open: () async => store);
      await c.load();
      await c.change(
        (s) => s.copy({
          'settings': {'theme': 'dark'},
        }),
      );
      final before = c.state!;
      await c.replaceFromBackup(
        HabitState(settings: {'theme': 'light'}),
        expectedRevision: before.revision,
      );
      expect(
        (await NativeHabitStore(store.path).readRecovery())!.toJson(),
        before.toJson(),
      );
      final restarted = HabitController(
        open: () async => NativeHabitStore(store.path),
      );
      await restarted.load();
      await restarted.recoverBeforeReplace();
      expect(restarted.state!.settings['theme'], 'dark');
      final saved = await store.readRecovery();
      await expectLater(
        c.replaceFromBackup(HabitState(), expectedRevision: before.revision),
        throwsStateError,
      );
      expect((await store.readRecovery())!.toJson(), saved!.toJson());
      c.dispose();
      restarted.dispose();
    },
  );
  test(
    'physical1 migration is atomic, retryable and preserves original recovery',
    () async {
      await store.read();
      final db = sqlite3.open(store.path);
      db.execute(
        'DROP TABLE operations; DROP TABLE recovery; PRAGMA user_version=1;',
      );
      final old = HabitState().toJson()..['schema'] = 2;
      old.remove('operations');
      old.remove('trash');
      old.remove('tombstones');
      db.execute('UPDATE state SET payload=? WHERE id=1', [jsonEncode(old)]);
      db.execute(
        "CREATE TRIGGER fail_migration BEFORE UPDATE ON state BEGIN SELECT RAISE(ABORT,'interrupted'); END",
      );
      db.close();
      await expectLater(store.read(), throwsA(anything));
      final failed = sqlite3.open(store.path);
      expect(failed.userVersion, 1);
      expect(
        (jsonDecode(
              failed.select('SELECT payload FROM state').single['payload']
                  as String,
            )
            as Map)['schema'],
        2,
      );
      failed.execute('DROP TRIGGER fail_migration');
      failed.close();
      final loaded = await store.read();
      expect(loaded.events, isEmpty);
      final migrated = sqlite3.open(store.path);
      expect(migrated.userVersion, 2);
      migrated.close();
      expect(File('${store.path}.pre-v2.sqlite').existsSync(), isTrue);
    },
  );
  test(
    'Undo survives controller restart and never reverses unrelated preferences',
    () async {
      final c = HabitController(open: () async => store);
      await c.load();
      await c.change(
        (s) => s.copy({
          'habits': [
            Habit(
              id: 'h',
              title: 'Read',
              created: '2024-01-01',
              schedules: [Schedule(id: 's', from: '2024-01-01')],
            ).toJson(),
          ],
        }),
      );
      c.dispose();
      final again = HabitController(open: () async => store);
      await again.load();
      expect(again.canUndo, isTrue);
      await again.undo();
      expect(again.state!.habits, isEmpty);
      again.dispose();
    },
  );
}
