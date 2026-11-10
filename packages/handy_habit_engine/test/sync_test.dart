import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

const today = '2026-11-10';
final now = DateTime.utc(2026, 11, 10, 8);
HabitState seed({String type = 'count', bool negative = false}) => HabitState(
  habits: [
    Habit(
      id: 'h',
      title: 'Water',
      created: today,
      type: type,
      direction: negative ? 'reduce' : 'build',
      schedules: [
        Schedule(id: 's', from: today, target: type == 'binary' ? 1000 : 10000),
      ],
      negativeGoals: negative
          ? [NegativeGoal(id: 'g', from: today, limit: 3000)]
          : [],
    ),
  ],
);
HabitState add(HabitState s, String actor, String id, {int value = 1000}) =>
    recordChange(
      s,
      record(
        s,
        HabitEvent(
          id: id,
          habit: 'h',
          day: today,
          value: value,
          updated: now.toIso8601String(),
        ),
        today: today,
        allowExtra: true,
      ),
      actor: actor,
    );

void main() {
  test('concurrent Trash entries restore as one logical item', () {
    final s = prepareHabitSync(seed());
    final a = recordChange(s, trashEntity(s, 'habit', 'h', now), actor: 'a');
    final b = recordChange(
      s,
      trashEntity(s, 'habit', 'h', now.add(const Duration(seconds: 1))),
      actor: 'b',
    );
    final m = mergeHabitStates(a, b);
    final r = recordChange(
      m,
      restoreTrash(m, m.trash.single.id, now.add(const Duration(seconds: 2))),
      actor: 'review',
    );
    expect(mergeHabitStates(r, m).trash, isEmpty);
  });
  test(
    'Undo on the receiving device retracts exactly the observed remote batch',
    () {
      final s = prepareHabitSync(seed()), a = add(s, 'a', 'a');
      final m = mergeHabitStates(a, add(s, 'b', 'b'));
      final undone = undoChange(m, a.undoBatch!, actor: 'receiver');
      expect(mergeHabitStates(undone, a).events.map((e) => e.id), ['b']);
    },
  );
  test(
    'missing download and future version receipt refuse before any upload',
    () async {
      final partial = _MissingDownload();
      await expectLater(
        syncHabitOnce(
          local: seed(),
          base: const [],
          device: 'a',
          remote: partial,
        ),
        throwsFormatException,
      );
      expect(partial.writes, 0);
      final remote = MemoryHabitSyncProvider();
      remote.files['$habitSyncRoot/versions/future.json'] = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'handy-habit-device-version',
            'version': 99,
            'schema': 99,
          }),
        ),
      );
      await expectLater(
        syncHabitOnce(
          local: seed(),
          base: const [],
          device: 'a',
          remote: remote,
        ),
        throwsA(isA<NewerHabitSync>()),
      );
      expect(remote.writes, 0);
    },
  );
  test('routine disjoint step edits and separate sessions both survive', () {
    final r = Routine(
      id: 'r',
      title: 'Morning',
      steps: [
        RoutineStep(id: 'x', title: 'Water', habit: 'h'),
        RoutineStep(id: 'y', title: 'Walk'),
      ],
    );
    final s = prepareHabitSync(
      seed().copy({
        'routines': [r.toJson()],
      }),
    );
    HabitState edit(String actor, int position, String title) {
      final steps = r.steps.toList();
      steps[position] = steps[position].copy({'title': title});
      return recordChange(
        s,
        s.copy({
          'routines': [
            r.copy({'steps': steps.map((v) => v.toJson()).toList()}).toJson(),
          ],
        }),
        actor: actor,
      );
    }

    final m = mergeHabitStates(edit('a', 0, 'Drink'), edit('b', 1, 'Outside'));
    expect(m.routines.single.steps.map((s) => s.title), ['Drink', 'Outside']);
    HabitState run(String actor) => recordChange(
      m,
      putSession(m, startSession(r, today, now)),
      actor: actor,
    );
    final a = run('a'), b = run('b');
    final merged = mergeHabitStates(a, b);
    expect(merged.sessions, hasLength(2));
    expect(merged.sessions.where((s) => s.status == 'active'), hasLength(1));
    expect(encodeHabitSync(merged), encodeHabitSync(mergeHabitStates(b, a)));
  });
  test(
    'same routine step completed offline twice records linked progress once',
    () {
      final r = Routine(
        id: 'r',
        title: 'Morning',
        steps: [RoutineStep(id: 'x', title: 'Water', habit: 'h')],
      );
      var s = seed().copy({
        'routines': [r.toJson()],
      });
      s = prepareHabitSync(putSession(s, startSession(r, today, now)));
      HabitState done(String actor, int seconds) => recordChange(
        s,
        completeStep(
          s,
          s.sessions.single.id,
          expectedStep: 'x',
          today: today,
          now: now.add(Duration(seconds: seconds)),
        ),
        actor: actor,
      );
      final m = mergeHabitStates(done('a', 1), done('b', 2));
      expect(m.events, hasLength(1));
      expect(HabitIndex.of(m).value('h', today), 1000);
      expect(undoStep(m, m.sessions.single.id, 0).events, isEmpty);
    },
  );
  test(
    'purge redacts late offline payloads and never broadens targeted pause',
    () {
      final s = prepareHabitSync(
        seed().copy({
          'pauses': [
            Pause(id: 'p', from: today, until: today, habits: ['h']).toJson(),
          ],
        }),
      );
      final trashed = recordChange(
        s,
        trashEntity(s, 'habit', 'h', now),
        actor: 'a',
      );
      final purged = recordChange(
        trashed,
        deleteTrash(trashed, trashed.trash.single.id),
        actor: 'a',
      );
      final m = mergeHabitStates(purged, add(s, 'b', 'late'));
      expect(m.pauses, isEmpty);
      expect(m.events, isEmpty);
      expect(
        m.operations.where((o) => o.kind == 'events').every((o) => o.redacted),
        isTrue,
      );
    },
  );
  test('explicit mood review can choose a removal candidate', () {
    final s = prepareHabitSync(seed());
    final a = recordChange(
      s,
      saveMood(s, today, 2, now: now, expectedRevision: 0),
      actor: 'a',
    );
    final b = recordChange(
      s,
      saveMood(s, today, 5, now: now, expectedRevision: 0),
      actor: 'b',
    );
    final m = mergeHabitStates(undoChange(a, a.undoBatch!, actor: 'a'), b);
    final choice = moodSyncConflicts(
      m,
    ).values.single.firstWhere((o) => o.after == null);
    final r = resolveMoodSyncConflict(m, 'mood:$today', choice.id);
    expect(moodSyncConflicts(r), isEmpty);
    expect(r.moods, isEmpty);
  });
  for (final negative in [false, true]) {
    test(
      'three devices ${negative ? "incidents" : "check-ins"} converge in six orders',
      () {
        final s = prepareHabitSync(seed(negative: negative));
        final states = [add(s, 'a', 'a'), add(s, 'b', 'b'), add(s, 'c', 'c')];
        final results = <String>[];
        for (final order in [
          [0, 1, 2],
          [0, 2, 1],
          [1, 0, 2],
          [1, 2, 0],
          [2, 0, 1],
          [2, 1, 0],
        ]) {
          final m = mergeHabitStates(
            mergeHabitStates(states[order[0]], states[order[1]]),
            states[order[2]],
          );
          expect(m.events, hasLength(3));
          expect(HabitIndex.of(m).value('h', today), 3000);
          results.add(utf8.decode(encodeHabitSync(m)));
        }
        expect(results.toSet(), hasLength(1));
      },
    );
  }
  test('binary keeps independent provenance but counts one completion', () {
    final s = prepareHabitSync(seed(type: 'binary'));
    final m = mergeHabitStates(add(s, 'a', 'a'), add(s, 'b', 'b'));
    expect(m.events, hasLength(2));
    expect(HabitIndex.of(m).value('h', today), 1000);
    expect(restore(backup(m)).events, hasLength(2));
  });
  test(
    'absolute correction replaces observed total, keeps offline addition',
    () {
      final s = add(prepareHabitSync(seed()), 'first', 'first');
      final a = recordChange(
        s,
        setManualTotal(s, 'h', today, 4000, today: today),
        actor: 'a',
      );
      final m = mergeHabitStates(a, add(s, 'b', 'b'));
      expect(HabitIndex.of(m).value('h', today), 5000);
      expect(dayOperationConflicts(m.operations), isEmpty);
    },
  );
  test(
    'absolute edits need review; observing both resolves without summing',
    () {
      final s = prepareHabitSync(seed());
      HabitState edit(String actor, int v) => recordChange(
        s,
        setManualTotal(s, 'h', today, v, today: today),
        actor: actor,
      );
      final m = mergeHabitStates(edit('a', 4000), edit('b', 7000));
      expect(dayOperationConflicts(m.operations), hasLength(1));
      expect(
        habitStatus(m.habits.single, today, today, HabitIndex.of(m)),
        'conflict',
      );
      final r = recordChange(
        m,
        setManualTotal(m, 'h', today, 6000, today: today),
        actor: 'review',
      );
      final reduced = mergeHabitStates(r, m);
      expect(dayOperationConflicts(reduced.operations), isEmpty);
      expect(HabitIndex.of(reduced).value('h', today), 6000);
    },
  );
  test(
    'skip versus addition is held for review, excluded from eligibility',
    () {
      final s = prepareHabitSync(seed());
      final a = recordChange(
        s,
        setManualTotal(s, 'h', today, 0, skipped: true, today: today),
        actor: 'a',
      );
      final m = mergeHabitStates(a, add(s, 'b', 'b'));
      expect(dayOperationConflicts(m.operations), hasLength(1));
      expect(
        progressCount(
          m.habits.single,
          today,
          today,
          addDays(today, 1),
          HabitIndex.of(m),
        ).eligible,
        0,
      );
    },
  );
  test(
    'Undo retracts only own check-in and cannot resurrect on stale device',
    () {
      final s = prepareHabitSync(seed()), a = add(s, 'a', 'a');
      final undone = undoChange(a, a.undoBatch!, actor: 'a');
      final m = mergeHabitStates(undone, add(s, 'b', 'b'));
      expect(m.events.map((e) => e.id), ['b']);
      expect(mergeHabitStates(m, a).events.map((e) => e.id), ['b']);
    },
  );
  test(
    'mood review observes both versions and Undo retains remote candidate',
    () {
      final s = prepareHabitSync(seed());
      final a = recordChange(
        s,
        saveMood(s, today, 2, now: now, expectedRevision: 0),
        actor: 'a',
      );
      final b = recordChange(
        s,
        saveMood(s, today, 5, now: now, expectedRevision: 0),
        actor: 'b',
      );
      final m = mergeHabitStates(a, b);
      final review = recordChange(
        m,
        saveMood(m, today, 3, now: now, expectedRevision: 0),
        actor: 'review',
      );
      final r = mergeHabitStates(review, a);
      expect(moodSyncConflicts(r), isEmpty);
      expect(moodOn(r, today)!.mood, 3);
      final undone = mergeHabitStates(
        undoChange(a, a.undoBatch!, actor: 'a'),
        b,
      );
      expect(
        moodSyncConflicts(
          undone,
        ).values.single.any((o) => o.after?['mood'] == 5),
        isTrue,
      );
    },
  );
  test(
    'same habit disjoint edits and future schedules merge deterministically',
    () {
      final s = prepareHabitSync(seed());
      final a = recordChange(
        s,
        s.copy({
          'habits': [
            s.habits.single.copy({'title': 'Drink water'}).toJson(),
          ],
        }),
        actor: 'a',
      );
      final b = recordChange(
        s,
        s.copy({
          'habits': [
            s.habits.single.copy({
              'note': 'After lunch',
              'schedules': [
                ...s.habits.single.schedules.map((v) => v.toJson()),
                Schedule(
                  id: 's2',
                  from: addDays(today, 1),
                  target: 8000,
                ).toJson(),
              ],
            }).toJson(),
          ],
        }),
        actor: 'b',
      );
      final m = mergeHabitStates(a, b);
      expect(m.habits.single.title, 'Drink water');
      expect(m.habits.single.note, 'After lunch');
      expect(m.habits.single.schedules, hasLength(2));
      expect(encodeHabitSync(m), encodeHabitSync(mergeHabitStates(b, a)));
    },
  );
  test('archive and concurrent check-in both survive', () {
    final s = prepareHabitSync(seed());
    final a = recordChange(
      s,
      s.copy({
        'habits': [archiveHabit(s.habits.single, today, true).toJson()],
      }),
      actor: 'a',
    );
    final m = mergeHabitStates(a, add(s, 'b', 'b'));
    expect(m.habits.single.archived, isTrue);
    expect(m.events.single.id, 'b');
  });
  test(
    'trash/edit, restore and purge tombstone prevent stale resurrection',
    () {
      final s = prepareHabitSync(seed());
      final a = recordChange(s, trashEntity(s, 'habit', 'h', now), actor: 'a'),
          b = add(s, 'b', 'b');
      final m = mergeHabitStates(a, b);
      expect(m.liveHabits, isEmpty);
      expect(m.events, hasLength(1));
      final restored = recordChange(
        m,
        restoreTrash(m, m.trash.single.id, now),
        actor: 'a',
      );
      expect(mergeHabitStates(restored, a).liveHabits, hasLength(1));
      final purged = recordChange(
        m,
        deleteTrash(m, m.trash.single.id),
        actor: 'a',
      );
      final r = mergeHabitStates(purged, b);
      expect(r.habits, isEmpty);
      expect(r.events, isEmpty);
      expect(r.tombstones, hasLength(1));
      expect(mergeHabitStates(b, purged).tombstones, r.tombstones);
    },
  );
  test(
    'duplicate logical IDs and actor sequences refuse; identical operations dedupe',
    () {
      final s = prepareHabitSync(seed()),
          a = add(s, 'a', 'same'),
          b = add(s, 'b', 'same', value: 2000);
      expect(() => mergeHabitStates(a, b), throwsFormatException);
      final op = a.operations.last;
      final collision = HabitOperation.fromJson({
        ...op.toJson(),
        'id': 'collision',
      });
      expect(
        () => unionOperations(a.operations, [collision]),
        throwsFormatException,
      );
      expect(
        unionOperations(a.operations, a.operations).length,
        a.operations.length,
      );
    },
  );
  test('wall-clock skew never decides same-day moods', () {
    final s = prepareHabitSync(seed());
    final a = recordChange(
      s,
      saveMood(s, today, 2, now: DateTime.utc(2020), expectedRevision: 0),
      actor: 'a',
    );
    final b = recordChange(
      s,
      saveMood(s, today, 5, now: DateTime.utc(2099), expectedRevision: 0),
      actor: 'b',
    );
    expect(
      encodeHabitSync(mergeHabitStates(a, b)),
      encodeHabitSync(mergeHabitStates(b, a)),
    );
    expect(
      moodSyncConflicts(mergeHabitStates(a, b)).values.single,
      hasLength(2),
    );
  });
  test('interrupted upload retries without doubled records', () async {
    final remote = MemoryHabitSyncProvider()..failWrites = 1;
    final s = add(prepareHabitSync(seed()), 'a', 'a');
    await expectLater(
      syncHabitOnce(local: s, base: const [], device: 'a', remote: remote),
      throwsStateError,
    );
    final a = await syncHabitOnce(
      local: s,
      base: const [],
      device: 'a',
      remote: remote,
    );
    final b = await syncHabitOnce(
      local: a.state,
      base: a.base,
      device: 'a',
      remote: remote,
    );
    expect(b.state.events, hasLength(1));
    expect(await remote.list('$habitSyncRoot/commits'), hasLength(1));
  });
  test('simultaneous independent generations converge next round', () async {
    final remote = MemoryHabitSyncProvider(), s = prepareHabitSync(seed());
    final results = await Future.wait([
      syncHabitOnce(
        local: add(s, 'a', 'a'),
        base: const [],
        device: 'a',
        remote: remote,
      ),
      syncHabitOnce(
        local: add(s, 'b', 'b'),
        base: const [],
        device: 'b',
        remote: remote,
      ),
    ]);
    expect(await remote.list('$habitSyncRoot/commits'), hasLength(2));
    final a = await syncHabitOnce(
      local: results[0].state,
      base: results[0].base,
      device: 'a',
      remote: remote,
    );
    final b = await syncHabitOnce(
      local: results[1].state,
      base: results[1].base,
      device: 'b',
      remote: remote,
    );
    expect(a.state.events, hasLength(2));
    expect(encodeHabitSync(a.state), encodeHabitSync(b.state));
  });
  test('corrupt/truncated/hash mismatch refuses without upload', () async {
    final remote = MemoryHabitSyncProvider();
    remote.files['$habitSyncRoot/commits/broken.json'] = Uint8List.fromList([
      123,
    ]);
    await expectLater(
      syncHabitOnce(local: seed(), base: const [], device: 'a', remote: remote),
      throwsFormatException,
    );
    expect(remote.writes, 0);
    final bytes = encodeHabitSync(seed()),
        j = jsonDecode(utf8.decode(bytes)) as Map;
    j['size'] = 0;
    expect(
      () => decodeHabitSync(Uint8List.fromList(utf8.encode(jsonEncode(j)))),
      throwsFormatException,
    );
    expect(
      () => decodeHabitSync(Uint8List.sublistView(bytes, 0, bytes.length - 5)),
      throwsFormatException,
    );
  });
  test('base preserves ancestors missing from incomplete local snapshot', () {
    final s = add(prepareHabitSync(seed()), 'a', 'a');
    expect(
      mergeHabitStates(
        HabitState(),
        HabitState(),
        base: s.operations,
      ).events.single.id,
      'a',
    );
  });
  test('two offline devices keep simultaneous check-ins', () {
    final s = prepareHabitSync(seed());
    final merged = mergeHabitStates(add(s, 'a', 'a'), add(s, 'b', 'b'));
    expect(merged.events.map((e) => e.id).toSet(), {'a', 'b'});
    expect(HabitIndex.of(merged).value('h', today), 2000);
  });
  test(
    'concurrent same-day moods retain both candidates until explicit review',
    () {
      final s = prepareHabitSync(seed());
      HabitState mood(String actor, int v) => recordChange(
        s,
        saveMood(s, today, v, now: now, expectedRevision: 0),
        actor: actor,
      );
      final merged = mergeHabitStates(mood('a', 2), mood('b', 5));
      expect(
        moodSyncConflicts(
          merged,
        ).values.single.map((o) => o.after!['mood']).toSet(),
        {2, 5},
      );
      expect(moodOn(merged, today), isNull);
    },
  );
  test(
    'immutable remote generations roundtrip through a device base',
    () async {
      final remote = MemoryHabitSyncProvider();
      final a = add(prepareHabitSync(seed()), 'a', 'a');
      final first = await syncHabitOnce(
        local: a,
        base: const [],
        device: 'a',
        remote: remote,
      );
      final second = await syncHabitOnce(
        local: HabitState(),
        base: const [],
        device: 'b',
        remote: remote,
      );
      expect(second.state.events.single.id, 'a');
      expect(first.base, isNotEmpty);
      expect(
        decodeHabitSync(encodeHabitSync(first.state)).operations.length,
        first.state.operations.length,
      );
    },
  );
  test('newer remote and damaged envelopes refuse before any upload', () async {
    final remote = MemoryHabitSyncProvider();
    remote.files['$habitSyncRoot/commits/newer.json'] = Uint8List.fromList(
      utf8.encode(
        jsonEncode({'format': 'handy-habit-sync', 'version': 99, 'schema': 99}),
      ),
    );
    await expectLater(
      syncHabitOnce(local: seed(), base: const [], device: 'a', remote: remote),
      throwsA(isA<NewerHabitSync>()),
    );
    expect(remote.writes, 0);
  });
}

class _MissingDownload extends MemoryHabitSyncProvider {
  @override
  Future<Set<String>> list(String folder) async =>
      folder.endsWith('/commits') ? {'missing.json'} : {};
}
