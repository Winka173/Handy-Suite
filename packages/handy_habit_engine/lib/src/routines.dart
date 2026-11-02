part of '../handy_habit_engine.dart';

RoutineSession startSession(
  Routine routine,
  String today,
  DateTime now, {
  List<RoutineStep>? plan,
  bool autoNext = false,
}) {
  if (routine.archived) throw const FormatException('Archived routine');
  return RoutineSession(
    id: uid(),
    routine: routine.id,
    title: routine.title,
    started: now.toUtc().toIso8601String(),
    day: today,
    steps: (plan ?? routine.steps).map((s) => StepRun(plan: s)).toList(),
    anchor: now.toUtc().toIso8601String(),
    autoNext: autoNext,
  );
}

RoutineSession recoverSession(RoutineSession session, DateTime now) {
  if (!session.running) return session;
  final gap = now.toUtc().difference(DateTime.parse(session.anchor!)).inSeconds;
  final steps = session.steps.toList(), current = steps[session.cursor];
  steps[session.cursor] = current.copy({
    'elapsed': min(
      maxElapsed,
      current.elapsed + (gap >= 0 && gap <= 86400 ? gap : 0),
    ),
  });
  return session.copy({
    'steps': steps.map((s) => s.toJson()).toList(),
    'anchor': null,
    'recoveryWarning': true,
  });
}

HabitState putSession(HabitState state, RoutineSession s) => state.copy({
  'sessions': [
    for (final x in state.sessions)
      if (x.id != s.id) x.toJson(),
    s.toJson(),
  ],
});
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
  if (skip && !step.plan.canSkip)
    throw const FormatException('Step cannot be skipped');
  final events = state.events.toList();
  String? eventId;
  String? eventHash;
  if (!skip && step.plan.habit != null) {
    final h = state.habits
        .where((h) => h.id == step.plan.habit && !h.archived)
        .firstOrNull;
    if (h != null) {
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
      });
  return putSession(
    state.copy({'events': events.map((e) => e.toJson()).toList()}),
    next,
  );
}

HabitState undoStep(HabitState state, String sessionId, int position) {
  final session = state.sessions.firstWhere((s) => s.id == sessionId),
      steps = session.steps.toList();
  if (session.status != 'active') throw const FormatException('Closed session');
  final step = steps[position], events = state.events.toList();
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
  return putSession(
    state.copy({'events': events.map((e) => e.toJson()).toList()}),
    session.copy({
      'steps': steps.map((s) => s.toJson()).toList(),
      'cursor': position,
      'anchor': null,
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
            !(s.status == 'skipped' && s.plan.canSkip),
      ))
    throw const FormatException('Complete required steps before finish');
  return putSession(
    state,
    session.copy({
      'status': abort ? 'aborted' : 'finished',
      'anchor': null,
      'ended': now.toUtc().toIso8601String(),
    }),
  );
}

List<Routine> routineTemplates({bool vietnamese = false}) {
  final titles = vietnamese
      ? [
          'Buổi sáng',
          'Trước khi ngủ',
          'Học tập',
          'Khởi động',
          'Dọn nhà',
          'Đọc sách',
        ]
      : ['Morning', 'Bedtime', 'Study', 'Warmup', 'House reset', 'Reading'];
  final steps = vietnamese
      ? [
          ['Chuẩn bị', 'Vận động nhẹ', 'Lên ý định hôm nay'],
          ['Cất đồ', 'Chuẩn bị ngày mai', 'Thư giãn'],
          ['Chuẩn bị bàn', 'Tập trung', 'Ghi điều đã học'],
          ['Chuẩn bị', 'Vận động tùy khả năng', 'Kiểm tra lại'],
          ['Chọn khu vực', 'Sắp xếp', 'Cất dụng cụ'],
          ['Chọn sách', 'Đọc', 'Ghi chú'],
        ]
      : [
          ['Get ready', 'Gentle movement', 'Set an intention'],
          ['Put things away', 'Prepare tomorrow', 'Wind down'],
          ['Prepare your desk', 'Focus', 'Write what you learned'],
          ['Get ready', 'Move at your own pace', 'Check in'],
          ['Choose an area', 'Tidy up', 'Put tools away'],
          ['Choose a book', 'Read', 'Make a note'],
        ];
  return List.generate(
    titles.length,
    (i) => Routine(
      id: uid(),
      title: titles[i],
      steps: List.generate(
        3,
        (j) => RoutineStep(
          id: uid(),
          title: steps[i][j],
          seconds: j == 1 ? 300 : 60,
          minimum: j == 1 ? 120 : 60,
          required: j != 2,
          priority: 2 - j,
        ),
      ),
    ),
  );
}

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
