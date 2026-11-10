part of '../handy_habit_engine.dart';

/// Finite rules, never executable expressions. References are prior node IDs.
class StepLogic {
  final List<int> weekdays;
  final String? habitNotDone, stackAfter;
  final int minimumRemaining;
  final List<String> dependencies;
  final String branch, option, block;
  final Map<int, int> durations;
  StepLogic({
    List<int> weekdays = const [],
    this.habitNotDone,
    this.minimumRemaining = 0,
    List<String> dependencies = const [],
    this.stackAfter,
    this.branch = '',
    this.option = '',
    this.block = '',
    Map<int, int> durations = const {},
  }) : weekdays = List.unmodifiable(weekdays),
       dependencies = List.unmodifiable(dependencies),
       durations = Map.unmodifiable(durations) {
    if (weekdays.any((d) => d < 1 || d > 7) ||
        weekdays.toSet().length != weekdays.length ||
        minimumRemaining < 0 ||
        minimumRemaining > 86400 ||
        dependencies.length > 200 ||
        dependencies.toSet().length != dependencies.length ||
        (branch.isEmpty ? option.isNotEmpty : !['A', 'B'].contains(option)) ||
        durations.entries.any(
          (e) => e.key < 1 || e.key > 7 || e.value < 0 || e.value > 86400,
        )) {
      throw const FormatException('Invalid advanced step rule');
    }
    text(branch, max: 100);
    text(block, max: 200);
    if (habitNotDone != null) text(habitNotDone, max: 200);
  }
  bool get advanced =>
      weekdays.isNotEmpty ||
      habitNotDone != null ||
      minimumRemaining > 0 ||
      dependencies.isNotEmpty ||
      stackAfter != null ||
      branch.isNotEmpty ||
      durations.isNotEmpty ||
      block.isNotEmpty;
  Json toJson() => {
    'weekdays': weekdays,
    'habitNotDone': habitNotDone,
    'minimumRemaining': minimumRemaining,
    'dependencies': dependencies,
    'stackAfter': stackAfter,
    'branch': branch,
    'option': option,
    'block': block,
    'durations': {for (final e in durations.entries) '${e.key}': e.value},
  };
  factory StepLogic.fromJson(Json j) => StepLogic(
    weekdays: List<int>.from(j['weekdays'] as List? ?? []),
    habitNotDone: j['habitNotDone'] as String?,
    minimumRemaining: integer(j['minimumRemaining'] ?? 0, max: 86400),
    dependencies: List<String>.from(j['dependencies'] as List? ?? []),
    stackAfter: j['stackAfter'] as String?,
    branch: text(j['branch'] ?? ''),
    option: text(j['option'] ?? ''),
    block: text(j['block'] ?? ''),
    durations: {
      for (final e in (j['durations'] as Map? ?? {}).entries)
        int.parse(e.key as String): integer(e.value, max: 86400),
    },
  );
}

/// Reusable, nonrecursive snapshot. Insertions have their own node identities.
class StepBlock {
  final String id, title;
  final List<RoutineStep> steps;
  StepBlock({
    required this.id,
    required this.title,
    required List<RoutineStep> steps,
  }) : steps = List.unmodifiable(steps) {
    if (title.trim().isEmpty || steps.isEmpty)
      throw const FormatException('Name and steps required');
    text(id, max: 200);
    text(title, max: 200);
    validateStepGraph(steps);
  }
  Json toJson() => {
    'id': id,
    'title': title,
    'steps': steps.map((s) => s.toJson()).toList(),
  };
  factory StepBlock.fromJson(Json j) => StepBlock(
    id: text(j['id']),
    title: text(j['title']),
    steps: objects(j['steps']).map(RoutineStep.fromJson).toList(),
  );
  List<RoutineStep> insert({required String instance, bool markBlock = true}) {
    text(instance, max: 64);
    final ids = {for (final (i, s) in steps.indexed) s.id: '$instance:$i'};
    final branches = {
      for (final s in steps)
        if (s.logic.branch.isNotEmpty)
          s.logic.branch: '$instance:${steps.indexOf(s)}',
    };
    return [
      for (final s in steps)
        s.copy({
          'id': ids[s.id],
          'logic': {
            ...s.logic.toJson(),
            'block': markBlock ? id : s.logic.block,
            'dependencies': s.logic.dependencies.map((d) => ids[d]).toList(),
            'stackAfter': ids[s.logic.stackAfter],
            'branch': s.logic.branch.isEmpty ? '' : branches[s.logic.branch],
          },
        }),
    ];
  }
}

void validateStepGraph(List<RoutineStep> steps) {
  if (steps.length > 200)
    throw const FormatException('At most 200 expanded steps');
  final prior = <String, RoutineStep>{};
  final branches = <String, Set<String>>{};
  for (final s in steps) {
    final rule = s.logic;
    if (prior.containsKey(s.id) ||
        rule.dependencies.any((d) => !prior.containsKey(d)) ||
        rule.stackAfter != null && !prior.containsKey(rule.stackAfter)) {
      throw const FormatException(
        'Dependencies/stacking must reference an earlier step',
      );
    }
    if (rule.branch.isNotEmpty)
      branches.putIfAbsent(rule.branch, () => {}).add(rule.option);
    prior[s.id] = s;
  }
  if (branches.values.any((v) => v.length != 2)) {
    throw const FormatException('Each branch needs both A and B steps');
  }
}

/// A branch is requested only when its first reachable step is current.
String? pendingBranch(RoutineSession s) {
  final step = s.steps[s.cursor];
  final key = step.plan.logic.branch;
  return step.status == 'pending' &&
          key.isNotEmpty &&
          !s.choices.containsKey(key)
      ? key
      : null;
}

RoutineSession evaluateRoutine(RoutineSession session) {
  if (session.status != 'active' || session.inputs.isEmpty) return session;
  final steps = session.steps.toList(), trace = session.trace.toList();
  var cursor = session.cursor;
  final weekday = date(session.day).weekday;
  final done = Set<String>.from(session.inputs['doneHabits'] as List? ?? []);
  final values = Map<String, int>.from(
    session.inputs['habitValues'] as Map? ?? {},
  );
  final targets = Map<String, int>.from(
    session.inputs['habitTargets'] as Map? ?? {},
  );
  for (final s in steps.where(
    (s) => s.status == 'completed' && s.event != null && s.plan.habit != null,
  )) {
    final h = s.plan.habit!;
    values[h] = (values[h] ?? 0) + s.plan.linkedValue;
    if (targets[h] != null && values[h]! >= targets[h]!) done.add(h);
  }
  while (cursor < steps.length) {
    final step = steps[cursor], rule = step.plan.logic;
    if (step.status != 'pending') {
      cursor++;
      continue;
    }
    if (step.evaluated) break;
    final remaining = max(
      0,
      (session.inputs['budget'] as int) -
          steps.fold(0, (n, s) => n + s.elapsed),
    );
    var reason = '';
    if (rule.weekdays.isNotEmpty && !rule.weekdays.contains(weekday)) {
      reason = 'weekday:$weekday';
    } else if (rule.habitNotDone != null &&
        !targets.containsKey(rule.habitNotDone)) {
      reason = 'habitUnavailable';
    } else if (rule.habitNotDone != null && done.contains(rule.habitNotDone)) {
      reason = 'habitDone';
    } else if (rule.minimumRemaining > remaining) {
      reason = 'timeLeft';
    } else if ([...rule.dependencies, ?rule.stackAfter].any(
      (id) => !steps.any((s) => s.plan.id == id && s.status == 'completed'),
    )) {
      reason = 'dependency';
    } else if (rule.branch.isNotEmpty) {
      final choice = session.choices[rule.branch];
      if (choice == null) break;
      if (choice != rule.option) reason = 'branch:$choice';
    }
    trace.add({
      'kind': 'evaluate',
      'step': step.plan.id,
      'reason': reason,
      'weekday': weekday,
      'doneHabits': done.toList()..sort(),
      'remaining': remaining,
    });
    steps[cursor] = step.copy({
      'evaluated': true,
      'reason': reason,
      'status': reason.isEmpty ? 'pending' : 'skipped',
    });
    if (reason.isEmpty) break;
    cursor++;
  }
  return session.copy({
    'steps': steps.map((s) => s.toJson()).toList(),
    'cursor': min(cursor, steps.length - 1),
    'trace': trace,
    'anchor': null,
  });
}

HabitState chooseRoutineBranch(
  HabitState state,
  String sessionId,
  String option,
) {
  final session = state.sessions.firstWhere((s) => s.id == sessionId);
  final branch = pendingBranch(session);
  if (branch == null || !['A', 'B'].contains(option))
    throw const FormatException('No pending branch');
  return putSession(
    state,
    evaluateRoutine(
      session.copy({
        'choices': {...session.choices, branch: option},
        'trace': [
          ...session.trace,
          {'kind': 'choice', 'branch': branch, 'option': option},
        ],
        'anchor': null,
      }),
    ),
  );
}

HabitState undoRoutineChoice(
  HabitState state,
  String sessionId,
  String branch,
) {
  final session = state.sessions.firstWhere((s) => s.id == sessionId);
  final first = session.steps.indexWhere((s) => s.plan.logic.branch == branch);
  if (session.status != 'active' ||
      first < 0 ||
      !session.choices.containsKey(branch) ||
      session.steps
          .skip(first)
          .any(
            (s) =>
                s.status == 'completed' ||
                s.status == 'skipped' && s.reason.isEmpty,
          ) ||
      session.steps
          .skip(first)
          .any(
            (s) =>
                s.plan.logic.branch != branch &&
                session.choices.containsKey(s.plan.logic.branch),
          )) {
    throw const FormatException('Undo later steps and choices first');
  }
  final choices = {...session.choices}..remove(branch);
  return putSession(
    state,
    evaluateRoutine(
      session.copy({
        'choices': choices,
        'steps': [
          for (final (i, s) in session.steps.indexed)
            i < first
                ? s.toJson()
                : s.copy({
                    'status': 'pending',
                    'reason': '',
                    'evaluated': false,
                  }).toJson(),
        ],
        'cursor': first,
        'anchor': null,
        'trace': [
          ...session.trace,
          {'kind': 'undoChoice', 'branch': branch},
        ],
      }),
    ),
  );
}
