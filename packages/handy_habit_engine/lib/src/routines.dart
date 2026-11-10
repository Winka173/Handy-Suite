part of '../handy_habit_engine.dart';

RoutineSession startSession(
  Routine routine,
  String today,
  DateTime now, {
  List<RoutineStep>? plan,
  bool autoNext = false,
  HabitState? state,
  int? budgetSeconds,
}) {
  if (routine.archived) throw const FormatException('Archived routine');
  final source = plan ?? routine.steps;
  validateStepGraph(source);
  final advanced = source.any((s) => s.logic.advanced);
  final index = state == null ? null : HabitIndex.of(state);
  final weekday = date(today).weekday;
  final resolved = [
    for (final s in source)
      s.copy({
        'seconds': s.logic.durations[weekday] ?? s.seconds,
        'minimum': min(s.minimum, s.logic.durations[weekday] ?? s.seconds),
      }),
  ];
  final inputs = <String, dynamic>{
    if (advanced) ...{
      'weekday': weekday,
      'budget': integer(
        budgetSeconds ?? resolved.fold<int>(0, (n, s) => n + s.seconds),
        max: 200 * 86400,
      ),
      'doneHabits': [
        if (state != null)
          for (final h in state.liveHabits)
            if (!h.isNegative &&
                index!.value(h.id, today) >=
                    (scheduleOn(h, today)?.target ?? 1000))
              h.id,
      ],
      'habitValues': {
        if (state != null)
          for (final h in state.liveHabits.where(
            (h) => !h.isNegative && !h.archived,
          ))
            h.id: index!.value(h.id, today),
      },
      'habitTargets': {
        if (state != null)
          for (final h in state.liveHabits.where(
            (h) => !h.isNegative && !h.archived,
          ))
            h.id: scheduleOn(h, today)?.target ?? 1000,
      },
      'habitTitles': {
        if (state != null)
          for (final h in state.liveHabits) h.id: h.title,
      },
    },
  };
  return evaluateRoutine(
    RoutineSession(
      id: uid(),
      routine: routine.id,
      title: routine.title,
      started: now.toUtc().toIso8601String(),
      day: today,
      steps: resolved.map((s) => StepRun(plan: s)).toList(),
      anchor: now.toUtc().toIso8601String(),
      autoNext: autoNext,
      inputs: inputs,
      trace: advanced
          ? [
              {
                'kind': 'start',
                'inputs': inputs,
                'plan': resolved.map((s) => s.toJson()).toList(),
              },
            ]
          : [],
    ),
  );
}

RoutineSession recoverSession(RoutineSession session, DateTime now) {
  if (!session.running) return session;
  final steps = session.steps.toList(), current = steps[session.cursor];
  steps[session.cursor] = current.copy({
    // Never count an unobserved gap as elapsed execution time.
    'elapsed': current.elapsed,
  });
  return session.copy({
    'steps': steps.map((s) => s.toJson()).toList(),
    'anchor': null,
    'recoveryWarning': true,
  });
}

HabitState putSession(HabitState state, RoutineSession s) {
  final old = state.sessions.where((x) => x.id == s.id).firstOrNull;
  if (old != null &&
      (old.trace.length > s.trace.length ||
          !_same(old.trace, s.trace.take(old.trace.length).toList()) ||
          old.status != 'active' && !_same(old.toJson(), s.toJson()))) {
    throw const FormatException('Execution history is immutable');
  }
  return state.copy({
    'sessions': [
      for (final x in state.sessions)
        if (x.id != s.id) x.toJson(),
      s.toJson(),
    ],
  });
}

HabitState completeStep(
  HabitState state,
  String sessionId, {
  required String expectedStep,
  required String today,
  required DateTime now,
  int elapsed = 0,
  bool skip = false,
  bool addExtra = false,
}) {
  final session = state.sessions.firstWhere((s) => s.id == sessionId),
      step = session.steps[session.cursor];
  if (session.status != 'active')
    throw const FormatException('Session is closed');
  if (step.plan.id != expectedStep) return state;
  if (step.status != 'pending') return state;
  if (session.inputs.isNotEmpty &&
      (!step.evaluated ||
          session.steps
              .take(session.cursor)
              .any((s) => s.status == 'pending'))) {
    throw const FormatException('Resolve earlier decisions first');
  }
  if (pendingBranch(session) != null)
    throw const FormatException('Choose a branch first');
  if (skip && !step.plan.canSkip)
    throw const FormatException('Step cannot be skipped');
  final events = state.events.toList();
  String? eventId;
  String? eventHash;
  if (!skip && step.plan.habit != null) {
    final h = state.habits
        .where(
          (h) =>
              h.id == step.plan.habit &&
              !h.archived &&
              !state.isTrashed('habit', h.id),
        )
        .firstOrNull;
    if (h != null && !h.isNegative) {
      final index = HabitIndex(events),
          target = scheduleOn(h, today)?.target ?? 1000;
      if (addExtra && h.type != 'binary' || index.value(h.id, today) < target) {
        eventId = 'routine:${session.id}:${step.plan.id}';
        final entry = HabitEvent(
          id: eventId,
          habit: h.id,
          day: today,
          value: h.type == 'binary' ? 1000 : step.plan.linkedValue,
          source: 'routine',
          session: session.id,
          step: step.plan.id,
          updated: now.toUtc().toIso8601String(),
        );
        if (!events.any((e) => e.id == eventId)) events.add(entry);
        eventHash = sha256
            .convert(utf8.encode(jsonEncode(entry.toJson())))
            .toString();
      }
    }
  }
  final steps = session.steps.toList();
  steps[session.cursor] = step.copy({
    'status': skip ? 'skipped' : 'completed',
    'elapsed': min(
      maxElapsed,
      step.elapsed + integer(elapsed, max: maxElapsed),
    ),
    'event': eventId,
    'eventHash': eventHash,
  });
  final cursor = min(session.cursor + 1, steps.length - 1),
      next = session.copy({
        'steps': steps.map((s) => s.toJson()).toList(),
        'cursor': cursor,
        'anchor': null,
        if (session.inputs.isNotEmpty)
          'trace': [
            ...session.trace,
            {
              'kind': skip ? 'skip' : 'complete',
              'step': step.plan.id,
              'elapsed': steps[session.cursor].elapsed,
              'event': eventId,
              'at': now.toUtc().toIso8601String(),
            },
          ],
      });
  return putSession(
    state.copy({'events': events.map((e) => e.toJson()).toList()}),
    evaluateRoutine(next),
  );
}

HabitState undoStep(HabitState state, String sessionId, int position) {
  final session = state.sessions.firstWhere((s) => s.id == sessionId),
      steps = session.steps.toList();
  if (session.status != 'active') throw const FormatException('Closed session');
  final step = steps[position], events = state.events.toList();
  if (steps
      .skip(position + 1)
      .any(
        (s) =>
            s.status == 'completed' ||
            s.status == 'skipped' && s.reason.isEmpty,
      )) {
    throw const FormatException('Undo later steps first');
  }
  if (step.reason.isNotEmpty)
    throw const FormatException('Automatic decisions stay in the trace');
  if (step.event != null) {
    final event = events.where((e) => e.id == step.event).firstOrNull;
    if (event != null) {
      if (step.eventHash != null &&
          sha256.convert(utf8.encode(jsonEncode(event.toJson()))).toString() !=
              step.eventHash)
        throw const FormatException('Linked progress changed; preserved');
      if (event.source != 'routine' ||
          event.session != session.id ||
          event.step != step.plan.id ||
          event.value != step.plan.linkedValue && event.value != 1000)
        throw const FormatException('Linked progress was edited; preserved');
      events.remove(event);
    }
  }
  steps[position] = step.copy({
    'status': 'pending',
    'event': null,
    'eventHash': null,
  });
  for (var i = position + 1; i < steps.length; i++) {
    if (steps[i].reason.isNotEmpty)
      steps[i] = steps[i].copy({
        'status': 'pending',
        'reason': '',
        'evaluated': false,
      });
  }
  return putSession(
    state.copy({'events': events.map((e) => e.toJson()).toList()}),
    session.copy({
      'steps': steps.map((s) => s.toJson()).toList(),
      'cursor': position,
      'anchor': null,
      if (session.inputs.isNotEmpty)
        'trace': [
          ...session.trace,
          {'kind': 'undo', 'step': step.plan.id},
        ],
    }),
  );
}

HabitState closeSession(
  HabitState state,
  String id,
  DateTime now, {
  bool abort = false,
}) {
  final session = state.sessions.firstWhere((s) => s.id == id);
  if (session.status != 'active') return state;
  if (!abort &&
      session.steps.any(
        (s) =>
            s.plan.required &&
            s.status != 'completed' &&
            s.reason.isEmpty &&
            !(s.status == 'skipped' && s.plan.canSkip),
      ))
    throw const FormatException('Complete required steps before finish');
  return putSession(
    state,
    session.copy({
      'status': abort ? 'aborted' : 'finished',
      'anchor': null,
      'ended': now.toUtc().toIso8601String(),
      if (session.inputs.isNotEmpty)
        'trace': [
          ...session.trace,
          {'kind': abort ? 'abort' : 'finish'},
        ],
    }),
  );
}

List<Routine> routineTemplates({bool vietnamese = false}) => [
  for (final t in routineTemplateCatalog) t.instantiate(vietnamese: vietnamese),
];

/// Seconds left on [step] after [running] more seconds; negative when
/// over its plan, null for an untimed step.
int? secondsLeft(StepRun step, {int running = 0}) =>
    step.plan.seconds == 0 ? null : step.plan.seconds - step.elapsed - running;

/// Whether the notice for a paused run is on: its own switch, or, until
/// that is touched, the reminders switch (either one asked for the
/// permission when it was turned on).
bool runNoticeOn(HabitState s) =>
    (s.settings['runNotice'] ?? s.settings['notifications']) == true;

/// Whether a paused run may be shown in the system notifications now:
/// switched on and not in quiet hours. The OS permission is checked
/// separately and never asked for here.
bool runNoticeAllowed(HabitState s, DateTime now) =>
    runNoticeOn(s) && !inQuietHours(s, now);
