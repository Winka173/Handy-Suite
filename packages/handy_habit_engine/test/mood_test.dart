import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

final now = DateTime.utc(2026, 11, 10);
HabitState log(HabitState s, {int value = 3, int revision = 0}) => saveMood(
  s,
  '2026-11-10',
  value,
  now: now,
  expectedRevision: revision,
  note: 'Đi bộ, nghỉ\n=private',
  energy: 2,
  tags: ['home', 'work'],
);
void main() {
  test('mood validates scales, dates, notes, tags and identity', () {
    for (final n in [0, 6]) {
      expect(() => log(HabitState(), value: n), throwsFormatException);
      expect(
        () => saveMood(
          HabitState(),
          '2026-11-10',
          3,
          energy: n,
          now: now,
          expectedRevision: 0,
        ),
        throwsFormatException,
      );
    }
    final json = log(HabitState()).moods.single.toJson();
    for (final patch in <Map<String, dynamic>>[
      {'day': '2026-02-30'},
      {'note': 'a' * 4097},
      {
        'tags': ['a', 'a'],
      },
      {
        'tags': [' '],
      },
      {'tags': List.generate(9, (n) => '$n')},
      {'id': 'other'},
      {'revision': 0},
    ]) {
      expect(() => MoodEntry.fromJson({...json, ...patch}), throwsA(anything));
    }
    expect(
      () => HabitState(
        moods: [MoodEntry.fromJson(json), MoodEntry.fromJson(json)],
      ).validate(),
      throwsFormatException,
    );
  });
  test('revision guard, edit, delete and restore keep one day and payload', () {
    final s = log(HabitState());
    expect(s.moods.single.revision, 1);
    expect(() => log(s), throwsStateError);
    final edited = log(s, value: 4, revision: 1);
    final deleted = deleteMood(
      edited,
      '2026-11-10',
      now: now,
      expectedRevision: 2,
    );
    expect(moodOn(deleted, '2026-11-10'), isNull);
    expect(deleted.moods.single.note, s.moods.single.note);
    expect(deleted.moods.single.deleted, true);
    expect(
      () => restoreMood(deleted, '2026-11-10', now: now, expectedRevision: 2),
      throwsStateError,
    );
    final restored = restoreMood(
      deleted,
      '2026-11-10',
      now: now,
      expectedRevision: 3,
    );
    expect(restored.moods.single.revision, 4);
    expect(restored.moods.single.mood, 4);
    expect(restored.moods.single.deleted, false);
  });
  test('causal mood operations and Undo preserve unrelated habit data', () {
    final before = HabitState(settings: {'onboarded': true});
    final saved = recordChange(before, log(before), actor: 'a', now: now);
    expect(saved.operations.where((o) => o.kind == 'moods'), hasLength(1));
    final deleted = recordChange(
      saved,
      deleteMood(saved, '2026-11-10', now: now, expectedRevision: 1),
      actor: 'a',
      now: now,
    );
    final undone = undoChange(deleted, deleted.undoBatch!, actor: 'a');
    expect(undone.moods.single.toJson(), saved.moods.single.toJson());
    expect(undone.settings, before.settings);
    final newer = recordChange(
      deleted,
      log(deleted, value: 5, revision: 2),
      actor: 'b',
      now: now,
    );
    expect(
      () => undoChange(newer, deleted.undoBatch!, actor: 'a'),
      throwsStateError,
    );
    expect(undoChange(saved, saved.undoBatch!, actor: 'a').moods, isEmpty);
  });
  test(
    'JSON ZIP CSV roundtrip retain live and deleted moods and optional fields',
    () {
      var s = log(HabitState());
      s = saveMood(s, '2026-11-09', 1, now: now, expectedRevision: 0);
      s = deleteMood(s, '2026-11-09', now: now, expectedRevision: 1);
      for (final zip in [false, true]) {
        expect(restore(backup(s, zip: zip), zip: zip).toJson(), s.toJson());
      }
      final csv = csvLogs(s, '2026-11-01', '2026-11-30');
      final restored = importCsvLogs(
        HabitState(),
        Uint8List.fromList(utf8.encode(csv)),
      );
      expect(
        restored.moods.map((m) => m.toJson()),
        s.moods.map((m) => m.toJson()),
      );
      expect(
        () => importCsvLogs(
          HabitState(),
          Uint8List.fromList(utf8.encode(csv.replaceFirst('"3"', '"5"'))),
        ),
        throwsFormatException,
      );
      expect(
        csvLogs(s, '2026-10-01', '2026-10-31'),
        isNot(contains('mood_id')),
      );
    },
  );
  for (var schema = 1; schema <= 6; schema++) {
    test(
      'v$schema JSON and ZIP migrate unchanged old data and roundtrip as 7',
      () {
        final old = HabitState(settings: {'onboarded': true}).toJson()
          ..['schema'] = schema
          ..remove('moods');
        if (schema == 1) old.remove('pauses');
        final data = utf8.encode(jsonEncode(old));
        final manifest = utf8.encode(
          jsonEncode({
            'app': 'handy-habit',
            'schema': schema,
            'files': {'data.json': sha256.convert(data).toString()},
          }),
        );
        final zip = Uint8List.fromList(
          ZipEncoder().encode(
            Archive()
              ..addFile(ArchiveFile('data.json', data.length, data))
              ..addFile(
                ArchiveFile('manifest.json', manifest.length, manifest),
              ),
          ),
        );
        for (final migrated in [
          restore(Uint8List.fromList(data), zip: false),
          restore(zip),
        ]) {
          expect(migrated.moods, isEmpty);
          expect(migrated.settings, old['settings']);
          expect(restore(backup(migrated)).toJson(), migrated.toJson());
          expect(migrated.toJson()['schema'], 9);
        }
      },
    );
  }
  test(
    'merge deduplicates identical moods, refuses conflicting dates atomically',
    () {
      final s = log(HabitState());
      expect(merge(HabitState(), s).moods, hasLength(1));
      expect(merge(s, s).moods, hasLength(1));
      expect(
        () => merge(s, log(s, value: 5, revision: 1)),
        throwsFormatException,
      );
      expect(s.moods.single.mood, 3);
    },
  );
}
