import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

HabitState sample() => HabitState(
  habits: [
    Habit(
      id: 'h',
      title: 'Read',
      created: '2024-01-01',
      schedules: [Schedule(id: 'v', from: '2024-01-01')],
    ),
  ],
  events: [
    HabitEvent(
      id: 'e',
      habit: 'h',
      day: '2024-01-02',
      value: 1000,
      note: 'Huế',
    ),
  ],
  routines: [
    Routine(
      id: 'r',
      title: 'Evening',
      steps: [RoutineStep(id: 'step', title: 'Read', habit: 'h')],
    ),
  ],
);

void main() {
  test('domain Undo and roundtrip preserve manual habit order', () {
    final first = sample().habits.single;
    final second = first.copy({'id': 'second', 'title': 'Walk'});
    final before = HabitState(habits: [first, second]);
    final changed = recordChange(
      before,
      before.copy({
        'habits': [second.toJson(), first.toJson()],
      }),
      actor: 'writer',
    );
    expect(changed.undoBatch, isNotNull);
    expect(restore(backup(changed)).habits.map((h) => h.id), ['second', 'h']);
    final undone = undoChange(changed, changed.undoBatch!, actor: 'writer');
    expect(undone.habits.map((h) => h.id), ['h', 'second']);
  });
  test(
    'causal union converges, keeps both deltas, rejects collisions and flags absolute conflicts',
    () {
      final before = sample();
      final a = record(
        before,
        HabitEvent(id: 'a', habit: 'h', day: '2024-01-03', value: 1000),
        today: '2024-01-03',
      );
      final b = record(
        before,
        HabitEvent(id: 'b', habit: 'h', day: '2024-01-03', value: 1000),
        today: '2024-01-03',
      );
      final both = unionOperations(a.operations, b.operations);
      expect(both.where((o) => o.intent == 'addDelta'), hasLength(2));
      expect(dayOperationConflicts(both), isEmpty);
      expect(
        unionOperations(b.operations, a.operations).map((o) => o.toJson()),
        both.map((o) => o.toJson()),
      );
      expect(unionOperations(both, both), hasLength(both.length));
      final x = setManualTotal(
        before,
        'h',
        '2024-01-02',
        0,
        today: '2024-01-03',
      );
      final y = setManualTotal(
        before,
        'h',
        '2024-01-02',
        1000,
        today: '2024-01-03',
      );
      expect(
        dayOperationConflicts(unionOperations(x.operations, y.operations)).keys,
        ['h:2024-01-02'],
      );
      final op = both.first;
      final collision = HabitOperation.fromJson({
        ...op.toJson(),
        'batch': 'changed',
      });
      expect(() => unionOperations(both, [collision]), throwsFormatException);
    },
  );
  test(
    'ledger distinguishes additions from absolute manual totals for later merge',
    () {
      final before = sample();
      final added = record(
        before,
        HabitEvent(id: 'delta', habit: 'h', day: '2024-01-03', value: 1000),
        today: '2024-01-03',
      );
      final set = setManualTotal(
        before,
        'h',
        '2024-01-02',
        0,
        today: '2024-01-03',
      );
      expect(added.operations.last.intent, 'addDelta');
      expect(set.operations.last.intent, 'setManualTotal');
      expect(set.operations.last.before!['observed'], ['e']);
      expect(
        restore(backup(set)).operations.last.toJson(),
        set.operations.last.toJson(),
      );
    },
  );
  test('clock policy revisions preserve saved days and roundtrip', () {
    final before = sample();
    final next = recordChange(
      before,
      before.copy({
        'settings': {'zone': 'UTC'},
      }),
      actor: 'device',
    );
    expect(next.clockPolicies, hasLength(2));
    expect(next.clockPolicies.first['zone'], 'Asia/Ho_Chi_Minh');
    expect(next.clockPolicies.last['zone'], 'UTC');
    expect(next.events.single.day, before.events.single.day);
    expect(restore(backup(next)).toJson(), next.toJson());
  });
  test(
    'trash merge remaps references and retains expiry; active links block deletion',
    () {
      final now = DateTime.utc(2024, 1, 3);
      final trashed = trashEntity(sample(), 'habit', 'h', now);
      final merged = merge(HabitState(), trashed);
      expect(merged.liveHabits, isEmpty);
      expect(merged.trash.single.entity, merged.habits.single.id);
      expect(
        merged.routines.single.steps.single.habit,
        merged.habits.single.id,
      );
      expect(merged.trash.single.expiresAt, trashed.trash.single.expiresAt);
      final active = putSession(
        sample(),
        startSession(sample().routines.single, '2024-01-03', now),
      );
      expect(() => trashEntity(active, 'habit', 'h', now), throwsStateError);
      expect(() => trashEntity(active, 'routine', 'r', now), throwsStateError);
    },
  );
  test(
    'trash suppresses reminders and eligibility; restore leaves the retained gap neutral',
    () {
      final now = DateTime.utc(2024, 1, 3);
      final before = sample().copy({
        'settings': {
          'reminders': [Reminder(id: 'n', target: 'h', type: 'habit').toJson()],
        },
      });
      final deleted = trashEntity(before, 'habit', 'h', now);
      expect(dueReminders(deleted, now), isEmpty);
      expect(HabitIndex.of(deleted).paused('h', '2024-01-04'), isTrue);
      final restored = restoreTrash(
        deleted,
        deleted.trash.single.id,
        DateTime.utc(2024, 1, 6),
      );
      expect(isScheduledOn(restored.habits.single, '2024-01-04'), isFalse);
      expect(isScheduledOn(restored.habits.single, '2024-01-06'), isTrue);
      expect(restored.events.single.toJson(), before.events.single.toJson());
      expect(restored.settings, before.settings);
      expect(restored.habits.single.archived, isFalse);
    },
  );
  test('duplicate actor sequence and changed payload hashes are rejected', () {
    final next = record(
      sample(),
      HabitEvent(id: 'd', habit: 'h', day: '2024-01-03', value: 1000),
      today: '2024-01-03',
    );
    final op = next.operations.single.toJson();
    expect(
      () => next.copy({
        'operations': [
          op,
          {...op, 'id': 'other'},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => next.copy({
        'operations': [
          {
            ...op,
            'after': {...op['after'] as Map, 'value': 0},
          },
        ],
      }),
      throwsFormatException,
    );
  });
  test('Undo rejects newer edits of the same row without changing them', () {
    final before = sample();
    final changed = recordChange(
      before,
      before.copy({
        'habits': [
          before.habits.single.copy({'title': 'Pages'}).toJson(),
        ],
      }),
      actor: 'a',
    );
    final newer = changed.copy({
      'habits': [
        before.habits.single.copy({'title': 'Books'}).toJson(),
      ],
    });
    expect(
      () => undoChange(newer, changed.operations.last.batch, actor: 'b'),
      throwsStateError,
    );
    expect(newer.habits.single.title, 'Books');
  });
  for (final version in [1, 2]) {
    test(
      'v$version migrates deterministically preserving history and roundtrips',
      () {
        final old = sample().toJson()..['schema'] = version;
        old.remove('operations');
        old.remove('trash');
        old.remove('tombstones');
        if (version == 1) old.remove('pauses');
        final a = HabitState.fromJson(old), b = HabitState.fromJson(old);
        expect(habitSchema, 4);
        expect(a.events.single.toJson(), (old['events'] as List).single);
        expect(a.operations, isNotEmpty);
        expect(a.toJson(), b.toJson());
        for (final zip in [false, true]) {
          expect(restore(backup(a, zip: zip), zip: zip).toJson(), a.toJson());
        }
        final data = utf8.encode(jsonEncode(old));
        final manifest = utf8.encode(
          jsonEncode({
            'app': 'handy-habit',
            'schema': version,
            'files': {'data.json': sha256.convert(data).toString()},
          }),
        );
        final oldZip = Uint8List.fromList(
          ZipEncoder().encode(
            Archive()
              ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
              ..addFile(ArchiveFile('data.json', data.length, data)),
          ),
        );
        expect(restore(oldZip).toJson(), a.toJson());
      },
    );
  }
  test(
    'domain Undo survives serialization and preserves unrelated changes',
    () {
      final before = sample();
      final after = recordChange(
        before,
        setManualTotal(before, 'h', '2024-01-03', 1000, today: '2024-01-03'),
        actor: 'device',
      );
      final changed = after.copy({
        'settings': {'theme': 'dark'},
      });
      final undone = undoChange(
        HabitState.fromJson(changed.toJson()),
        after.operations.last.batch,
        actor: 'device',
      );
      expect(
        undone.events.map((e) => e.toJson()),
        before.events.map((e) => e.toJson()),
      );
      expect(undone.settings['theme'], 'dark');
      expect(undone.operations.length, greaterThan(after.operations.length));
      final command = after.operations.firstWhere((o) => o.kind == 'days');
      expect(undone.operations.any((o) => o.undoOf == command.id), isTrue);
      expect(
        () => undoChange(undone, after.operations.last.batch, actor: 'device'),
        throwsStateError,
      );
    },
  );
  test(
    'trash roundtrips, keeps links, restores IDs and expires exactly at 30 days',
    () {
      final now = DateTime.utc(2024, 1, 3);
      final trashed = trashEntity(sample(), 'habit', 'h', now);
      expect(trashed.liveHabits, isEmpty);
      expect(trashed.events.single.id, 'e');
      expect(trashed.routines.single.steps.single.habit, 'h');
      expect(trashed.trash.single.daysLeft(now), 30);
      final loaded = restore(backup(trashed));
      expect(
        restoreTrash(loaded, loaded.trash.single.id, now).liveHabits.single.id,
        'h',
      );
      expect(
        purgeTrash(loaded, now.add(const Duration(days: 29))).trash,
        hasLength(1),
      );
      final purged = purgeTrash(loaded, now.add(const Duration(days: 30)));
      expect(purged.habits, isEmpty);
      expect(purged.events, isEmpty);
      expect(purged.routines.single.steps.single.habit, isNull);
      expect(purged.tombstones, isNotEmpty);
      expect(
        () => purged.copy({
          'habits': [sample().habits.single.toJson()],
        }),
        throwsFormatException,
      );
      expect(restore(backup(purged)).toJson(), purged.toJson());
    },
  );
  test('future schema rejects without mutating input', () {
    final raw = sample().toJson()..['schema'] = 99, saved = jsonEncode(raw);
    expect(
      () => restore(Uint8List.fromList(utf8.encode(saved)), zip: false),
      throwsFormatException,
    );
    expect(jsonEncode(raw), saved);
  });
}
