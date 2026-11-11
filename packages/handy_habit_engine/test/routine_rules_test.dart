import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

final now = DateTime.utc(2026, 11, 10);
RoutineStep step(
  String id, {
  StepLogic? logic,
  String? habit,
  bool canSkip = true,
}) => RoutineStep(
  id: id,
  title: id,
  seconds: 120,
  minimum: 0,
  habit: habit,
  canSkip: canSkip,
  logic: logic,
);
Routine routine(List<RoutineStep> steps) =>
    Routine(id: 'r', title: 'Morning', steps: steps);
HabitState seed(Routine r) => HabitState(
  routines: [r],
  habits: [
    Habit(
      id: 'h',
      title: 'Water',
      created: '2026-01-01',
      schedules: [Schedule(id: 'v', from: '2026-01-01')],
    ),
  ],
);
HabitState run(
  Routine r, {
  String day = '2026-11-10',
  HabitState? state,
  int? budget,
}) {
  final s = state ?? seed(r);
  return putSession(
    s,
    startSession(r, day, now, state: s, budgetSeconds: budget),
  );
}

HabitState done(HabitState s, {bool skip = false}) => completeStep(
  s,
  s.sessions.single.id,
  expectedStep: s.sessions.single.steps[s.sessions.single.cursor].plan.id,
  today: s.sessions.single.day,
  now: now,
  skip: skip,
);

void main() {
  test(
    'sync merges all nested advanced fields, blocks and presets in either order',
    () {
      final r = routine([step('water', habit: 'h'), step('a'), step('b')]);
      final base = prepareHabitSync(seed(r));
      final left = r.copy({
        'steps': [
          r.steps[0].copy({
            'logic': StepLogic(durations: {2: 600}).toJson(),
          }).toJson(),
          r.steps[1].copy({
            'logic': StepLogic(
              weekdays: [2],
              habitNotDone: 'h',
              minimumRemaining: 60,
              dependencies: ['water'],
              stackAfter: 'water',
            ).toJson(),
          }).toJson(),
          r.steps[2].toJson(),
        ],
      });
      final block = StepBlock(
        id: 'block',
        title: 'Water then read',
        steps: r.steps,
      );
      final right = r.copy({
        'steps': [
          r.steps[0].toJson(),
          r.steps[1].copy({
            'logic': StepLogic(branch: 'choice', option: 'A').toJson(),
          }).toJson(),
          r.steps[2].copy({
            'logic': StepLogic(branch: 'choice', option: 'B').toJson(),
          }).toJson(),
        ],
        'blocks': [block.toJson()],
        'presets': [block.toJson()],
      });
      final a = recordChange(
        base,
        base.copy({
          'routines': [left.toJson()],
        }),
        actor: 'a',
      );
      final b = recordChange(
        base,
        base.copy({
          'routines': [right.toJson()],
        }),
        actor: 'b',
      );
      final merged = mergeHabitStates(a, b).routines.single;
      expect(merged.steps.first.logic.durations, {2: 600});
      final logic = merged.steps[1].logic;
      expect(logic.weekdays, [2]);
      expect(logic.habitNotDone, 'h');
      expect(logic.minimumRemaining, 60);
      expect(logic.dependencies, ['water']);
      expect(logic.stackAfter, 'water');
      expect(logic.option, 'A');
      expect(merged.blocks.single.toJson(), block.toJson());
      expect(merged.presets.single.toJson(), block.toJson());
      expect(mergeHabitStates(b, a).routines.single.toJson(), merged.toJson());
    },
  );
  test(
    'closed traces survive sync of later routine edits without reevaluation',
    () {
      final r = routine([
        step('a', logic: StepLogic(weekdays: [2])),
      ]);
      var s = run(r);
      s = closeSession(done(s), s.sessions.single.id, now);
      final before = s.sessions.single.toJson();
      final base = prepareHabitSync(s);
      final changed = recordChange(
        base,
        base.copy({
          'routines': [
            r.copy({
              'steps': [
                step('a', logic: StepLogic(weekdays: [6])).toJson(),
              ],
            }).toJson(),
          ],
        }),
        actor: 'edit',
      );
      expect(mergeHabitStates(base, changed).sessions.single.toJson(), before);
    },
  );
  test(
    'partial linked quantities do not make an unfinished-habit condition false',
    () {
      final r = routine([
        step('water', habit: 'h'),
        step('read', logic: StepLogic(habitNotDone: 'h')),
      ]);
      final h = Habit(
        id: 'h',
        title: 'Water',
        type: 'count',
        created: '2026-01-01',
        schedules: [Schedule(id: 'v', from: '2026-01-01', target: 3000)],
      );
      final s = done(
        run(
          r,
          state: HabitState(habits: [h], routines: [r]),
        ),
      );
      expect(s.sessions.single.steps.last.reason, '');
    },
  );
  test(
    'time-left rule uses completed foreground elapsed; closed-app gaps consume none',
    () {
      final r = routine([
        step('a'),
        step('b', logic: StepLogic(minimumRemaining: 300)),
      ]);
      var s = run(r, budget: 400);
      s = completeStep(
        s,
        s.sessions.single.id,
        expectedStep: 'a',
        today: '2026-11-10',
        now: now,
        elapsed: 101,
      );
      expect(s.sessions.single.steps.last.reason, 'timeLeft');
      final active = run(r, budget: 400).sessions.single;
      expect(
        recoverSession(active, now.add(const Duration(hours: 4))).elapsed,
        0,
      );
    },
  );
  test(
    'branch Undo requires dependent work undone; trace keeps the original choice',
    () {
      final r = routine([
        step(
          'a',
          logic: StepLogic(branch: 'x', option: 'A'),
        ),
        step(
          'b',
          logic: StepLogic(branch: 'x', option: 'B'),
        ),
      ]);
      var s = run(r);
      s = chooseRoutineBranch(s, s.sessions.single.id, 'A');
      s = done(s);
      expect(
        () => undoRoutineChoice(s, s.sessions.single.id, 'x'),
        throwsFormatException,
      );
      s = undoStep(s, s.sessions.single.id, 0);
      s = undoRoutineChoice(s, s.sessions.single.id, 'x');
      expect(pendingBranch(s.sessions.single), 'x');
      s = chooseRoutineBranch(s, s.sessions.single.id, 'B');
      expect(
        s.sessions.single.trace
            .where((e) => e['kind'] == 'choice')
            .map((e) => e['option']),
        ['A', 'B'],
      );
    },
  );
  test(
    'copy-merge remaps rules, blocks, presets and execution input identities',
    () {
      final r = routine([
        step('water', habit: 'h'),
        step(
          'read',
          logic: StepLogic(
            habitNotDone: 'h',
            stackAfter: 'water',
            dependencies: ['water'],
          ),
        ),
      ]);
      final block = StepBlock(id: 'block', title: 'Wake up', steps: r.steps);
      final saved = r.copy({
        'blocks': [block.toJson()],
        'presets': [block.toJson()],
      });
      final imported = run(saved);
      final copied = merge(HabitState(), imported);
      final result = copied.routines.single;
      expect(result.steps.last.logic.habitNotDone, copied.habits.single.id);
      expect(result.steps.last.logic.stackAfter, result.steps.first.id);
      expect(result.blocks.single.steps.last.logic.dependencies, [
        result.blocks.single.steps.first.id,
      ]);
      expect(
        copied.sessions.single.inputs['habitTargets'],
        contains(copied.habits.single.id),
      );
      expect(restore(backup(copied)).routines.single.toJson(), result.toJson());
    },
  );
  test(
    'purging a linked habit preserves runnable stacking and saved block snapshots',
    () {
      final r = routine([
        step('water', habit: 'h'),
        step('read', logic: StepLogic(stackAfter: 'water')),
      ]);
      final s = trashEntity(seed(r), 'habit', 'h', now);
      final purged = purgeTrash(s, now.add(const Duration(days: 31)));
      expect(purged.habits, isEmpty);
      expect(
        run(purged.routines.single, state: purged).sessions.single.steps,
        hasLength(2),
      );
    },
  );
  test('weekday rule skips Saturday even a manually unskippable step', () {
    final r = routine([
      step('a', logic: StepLogic(weekdays: [1, 2, 3, 4, 5]), canSkip: false),
    ]);
    final s = run(r, day: '2026-11-14');
    expect(s.sessions.single.steps.single.reason, 'weekday:6');
    expect(
      closeSession(s, s.sessions.single.id, now).sessions.single.status,
      'finished',
    );
    expect(run(r).sessions.single.steps.single.status, 'pending');
  });
  test(
    'not-done rule snapshots progress; later history edits do not rewrite it',
    () {
      final r = routine([step('a', logic: StepLogic(habitNotDone: 'h'))]);
      final s = seed(r).copy({
        'events': [
          HabitEvent(
            id: 'e',
            habit: 'h',
            day: '2026-11-10',
            value: 1000,
            updated: now.toIso8601String(),
          ).toJson(),
        ],
      });
      final active = run(r, state: s);
      expect(active.sessions.single.steps.single.reason, 'habitDone');
      expect(
        evaluateRoutine(active.sessions.single).toJson(),
        active.sessions.single.toJson(),
      );
    },
  );
  test('remaining-time rule includes elapsed and passes exact threshold', () {
    final r = routine([step('a', logic: StepLogic(minimumRemaining: 300))]);
    expect(run(r, budget: 299).sessions.single.steps.single.reason, 'timeLeft');
    expect(run(r, budget: 300).sessions.single.steps.single.reason, '');
  });
  test('branch waits, chooses once, snapshots choice and skips other path', () {
    final r = routine([
      step(
        'a',
        logic: StepLogic(branch: 'move', option: 'A'),
      ),
      step(
        'b',
        logic: StepLogic(branch: 'move', option: 'B'),
      ),
    ]);
    var s = run(r);
    expect(pendingBranch(s.sessions.single), 'move');
    expect(() => done(s), throwsFormatException);
    s = chooseRoutineBranch(s, s.sessions.single.id, 'B');
    expect(s.sessions.single.steps.first.reason, 'branch:B');
    expect(s.sessions.single.cursor, 1);
    expect(
      () => chooseRoutineBranch(s, s.sessions.single.id, 'A'),
      throwsFormatException,
    );
    expect(done(s).sessions.single.steps.last.status, 'completed');
  });
  test('dependencies and habit stacking require completed prior nodes', () {
    final r = routine([
      step('water', habit: 'h'),
      step(
        'read',
        logic: StepLogic(dependencies: ['water'], stackAfter: 'water'),
      ),
    ]);
    var s = run(r);
    s = done(s, skip: true);
    expect(s.sessions.single.steps.last.reason, 'dependency');
    s = done(run(r));
    expect(s.sessions.single.steps.last.status, 'pending');
    expect(s.events.single.habit, 'h');
    s = done(s);
    expect(() => undoStep(s, s.sessions.single.id, 0), throwsFormatException);
    s = undoStep(s, s.sessions.single.id, 1);
    s = undoStep(s, s.sessions.single.id, 0);
    expect(s.events, isEmpty);
    expect(
      s.sessions.single.trace.where((x) => x['kind'] == 'undo'),
      hasLength(2),
    );
  });
  test(
    'DAG rejects forward refs, cycles, incomplete branches and path overflow',
    () {
      expect(
        () => routine([
          step('a', logic: StepLogic(dependencies: ['b'])),
          step('b'),
        ]),
        throwsFormatException,
      );
      expect(
        () => routine([
          step('a', logic: StepLogic(dependencies: ['a'])),
        ]),
        throwsFormatException,
      );
      expect(
        () => routine([step('a', logic: StepLogic(stackAfter: 'missing'))]),
        throwsFormatException,
      );
      expect(
        () => routine([
          step(
            'a',
            logic: StepLogic(branch: 'x', option: 'A'),
          ),
        ]),
        throwsFormatException,
      );
      expect(
        () => routine(List.generate(201, (i) => step('$i'))),
        throwsFormatException,
      );
    },
  );
  test(
    'blocks insert independent IDs and remap dependencies; presets roundtrip',
    () {
      final block = StepBlock(
        id: 'block',
        title: 'Wake up',
        steps: [
          step('a', habit: 'h'),
          step('b', logic: StepLogic(stackAfter: 'a')),
        ],
      );
      final a = block.insert(instance: 'one'),
          b = block.insert(instance: 'two');
      expect(a.last.logic.stackAfter, a.first.id);
      expect(a.first.id, isNot(b.first.id));
      final r = routine([...a, ...b]).copy({
        'blocks': [block.toJson()],
        'presets': [block.toJson()],
      });
      expect(Routine.fromJson(r.toJson()).toJson(), r.toJson());
    },
  );
  test('weekday durations resolve once and closed traces are immutable', () {
    final r = routine([
      step('a', logic: StepLogic(durations: {2: 600, 6: 60})),
    ]);
    var s = run(r);
    expect(s.sessions.single.steps.single.plan.seconds, 600);
    expect(
      run(r, day: '2026-11-14').sessions.single.steps.single.plan.seconds,
      60,
    );
    s = closeSession(done(s), s.sessions.single.id, now);
    final old = s.sessions.single;
    expect(() => old.trace.first['kind'] = 'edited', throwsUnsupportedError);
    expect(() => putSession(s, old.copy({'trace': []})), throwsFormatException);
    expect(
      s
          .copy({
            'routines': [
              r.copy({'title': 'Changed'}).toJson(),
            ],
          })
          .sessions
          .single
          .toJson(),
      old.toJson(),
    );
  });
  test('schemas 1–8 migrate linear sessions; schema 9 JSON/ZIP roundtrip', () {
    final r = routine([step('a')]);
    final raw = run(r).toJson();
    for (var v = 1; v <= 8; v++) {
      final j = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      j['schema'] = v;
      if (v == 1) j.remove('pauses');
      for (final routine in j['routines'] as List) {
        (routine as Map)
          ..remove('blocks')
          ..remove('presets');
        for (final step in routine['steps'] as List)
          (step as Map).remove('logic');
      }
      for (final session in j['sessions'] as List) {
        (session as Map)
          ..remove('inputs')
          ..remove('choices')
          ..remove('trace');
        for (final step in session['steps'] as List) {
          (step as Map)
            ..remove('reason')
            ..remove('evaluated');
          (step['plan'] as Map).remove('logic');
        }
      }
      final s = HabitState.fromJson(j);
      expect(s.sessions.single.steps.single.plan.title, 'a');
      expect(s.toJson()['schema'], 9);
      final data = utf8.encode(jsonEncode(j));
      final manifest = utf8.encode(
        jsonEncode({
          'app': 'handy-habit',
          'schema': v,
          'files': {'data.json': sha256.convert(data).toString()},
        }),
      );
      final zip = Uint8List.fromList(
        ZipEncoder().encode(
          Archive()
            ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
            ..addFile(ArchiveFile('data.json', data.length, data)),
        ),
      );
      expect(restore(zip).toJson(), s.toJson());
    }
    final s = run(
      routine([
        step('a', logic: StepLogic(weekdays: [2])),
      ]),
    );
    for (final zip in [false, true])
      expect(
        restore(backup(s, zip: zip), zip: zip).sessions.single.trace,
        s.sessions.single.trace,
      );
  });
  test(
    'sync merges advanced routine edits and preserves closed execution traces',
    () {
      final r = routine([step('a')]);
      final base = prepareHabitSync(seed(r));
      final a = recordChange(
        base,
        base.copy({
          'routines': [
            r.copy({
              'steps': [
                step('a', logic: StepLogic(weekdays: [2])).toJson(),
              ],
            }).toJson(),
          ],
        }),
        actor: 'a',
      );
      final b = recordChange(
        base,
        base.copy({
          'routines': [
            r.copy({'title': 'New name'}).toJson(),
          ],
        }),
        actor: 'b',
      );
      final merged = mergeHabitStates(a, b);
      expect(merged.routines.single.steps.single.logic.weekdays, [2]);
      expect(merged.routines.single.title, 'New name');
      expect(
        mergeHabitStates(b, a).routines.single.toJson(),
        merged.routines.single.toJson(),
      );
    },
  );
}
