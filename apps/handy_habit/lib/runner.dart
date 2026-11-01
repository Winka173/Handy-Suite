import 'dart:async';
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'controller.dart';
import 'runner_view.dart';

class RoutineRunner extends StatefulWidget {
  final HabitController controller;
  final String sessionId;
  final DateTime Function() clock;
  final bool fresh;
  const RoutineRunner({
    super.key,
    required this.controller,
    required this.sessionId,
    required this.clock,
    this.fresh = false,
  });
  @override
  State<RoutineRunner> createState() => _RunnerState();
}

class _RunnerState extends State<RoutineRunner> with WidgetsBindingObserver {
  final watch = Stopwatch();
  Timer? timer;
  bool acting = false, ready = false, leaving = false, extra = false;
  bool foreground = true;
  HabitIndex? cachedIndex;
  int? indexedRevision;
  bool recoveryFailed = false;
  HabitController get c => widget.controller;
  RoutineSession get session =>
      c.state!.sessions.firstWhere((s) => s.id == widget.sessionId);
  String t(String en, String vi) => tr(context, en, vi);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(initialize());
    });
    timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || !ready || !foreground) return;
      setState(() {});
      final step = session.steps[session.cursor];
      if (!acting &&
          watch.isRunning &&
          session.autoNext &&
          step.status == 'pending' &&
          step.plan.seconds > 0 &&
          step.elapsed + watch.elapsed.inSeconds >= step.plan.seconds)
        unawaited(complete());
    });
  }

  Future<void> initialize() async {
    try {
      if (widget.fresh && foreground) {
        watch.start();
      } else if (session.running) {
        await c.change(
          (s) => putSession(s, recoverSession(session, widget.clock())),
          remember: false,
        );
      }
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted)
        setState(() {
          ready = true;
          recoveryFailed = true;
        });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    watch.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) watch.stop();
    if (!foreground && ready && !acting) unawaited(perform(pause));
  }

  Future<void> perform(Future<void> Function() operation) async {
    if (acting) return;
    setState(() => acting = true);
    try {
      await operation();
      // A save may cross the background transition. Persist the stopped timer
      // after it finishes, before accepting another foreground action.
      if (!foreground && session.status == 'active') await pause();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'Could not save. Existing progress is preserved; retry.',
                'Chưa lưu được. Giữ nguyên tiến độ; hãy thử lại.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> pause() async {
    if (!watch.isRunning && !session.running) return;
    watch.stop();
    final delta = watch.elapsed.inSeconds,
        steps = session.steps.toList(),
        current = steps[session.cursor];
    steps[session.cursor] = current.copy({
      'elapsed': (current.elapsed + delta).clamp(0, maxElapsed),
    });
    try {
      await c.change(
        (s) => putSession(
          s,
          session.copy({
            'steps': steps.map((s) => s.toJson()).toList(),
            'anchor': null,
          }),
        ),
        remember: false,
      );
      watch.reset();
    } catch (_) {
      if (foreground) watch.start();
      rethrow;
    }
  }

  Future<void> resume() async {
    if (!foreground ||
        watch.isRunning ||
        session.steps[session.cursor].status != 'pending')
      return;
    await c.change(
      (s) => putSession(
        s,
        session.copy({'anchor': widget.clock().toUtc().toIso8601String()}),
      ),
      remember: false,
    );
    watch.reset();
    if (foreground) watch.start();
  }

  Future<void> complete({bool skip = false}) => perform(() async {
    final step = session.steps[session.cursor], expected = step.plan.id;
    watch.stop();
    final delta = watch.elapsed.inSeconds;
    try {
      await c.change(
        (s) => completeStep(
          s,
          session.id,
          expectedStep: expected,
          today: localDay(widget.clock(), s.zone),
          now: widget.clock(),
          elapsed: delta,
          skip: skip,
          addExtra: extra,
        ),
      );
      watch.reset();
      extra = false;
      // The next step starts timing at once; pausing stays a choice.
      if (foreground && session.steps[session.cursor].status == 'pending')
        await resume();
    } catch (_) {
      if (foreground && session.running) watch.start();
      rethrow;
    }
  });
  Future<void> move(int direction) => perform(() async {
    await pause();
    final next = (session.cursor + direction).clamp(
      0,
      session.steps.length - 1,
    );
    await c.change(
      (s) => putSession(s, session.copy({'cursor': next, 'anchor': null})),
      remember: false,
    );
    watch.reset();
  });
  Future<void> leave() async {
    if (leaving || acting) return;
    await perform(pause);
    if (!mounted) return;
    setState(() => leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> toggle() => perform(watch.isRunning ? pause : resume);

  Future<void> extend() => perform(() async {
    await pause();
    final steps = session.steps.toList(), current = steps[session.cursor];
    steps[session.cursor] = current.copy({
      'plan': current.plan.copy({
        'seconds': current.plan.seconds + 60,
      }).toJson(),
    });
    await c.change(
      (s) => putSession(
        s,
        session.copy({'steps': steps.map((s) => s.toJson()).toList()}),
      ),
    );
  });

  Future<void> note() => perform(() async {
    await pause();
    if (!mounted) return;
    final text = await askStepNote(context, session.steps[session.cursor].note);
    if (text == null) return;
    await c.change((s) {
      final steps = session.steps.toList();
      steps[session.cursor] = steps[session.cursor].copy({'note': text});
      return putSession(
        s,
        session.copy({'steps': steps.map((s) => s.toJson()).toList()}),
      );
    });
  });

  Future<void> autoNext(bool on) => perform(
    () => c.change((s) => putSession(s, session.copy({'autoNext': on}))),
  );

  Future<void> undo() => perform(() async {
    await pause();
    await c.change((s) => undoStep(s, session.id, session.cursor));
    watch.reset();
  });

  Future<void> finish({bool abort = false}) => perform(() async {
    await pause();
    if (abort) {
      if (!mounted || !await confirmAbort(context)) return;
    }
    final id = session.id;
    await c.change((s) => closeSession(s, id, widget.clock(), abort: abort));
    if (mounted) {
      final navigator = Navigator.of(context);
      setState(() => leaving = true);
      navigator.pop();
      // A finished run shows how it went.
      if (!abort) unawaited(navigator.pushNamed('/session/$id'));
    }
  });

  @override
  Widget build(BuildContext context) {
    final current = session.steps[session.cursor],
        elapsed = current.elapsed + watch.elapsed.inSeconds;
    final habit = c.state!.habits
        .where((h) => h.id == current.plan.habit)
        .firstOrNull;
    if (indexedRevision != c.state!.revision) {
      cachedIndex = HabitIndex(c.state!.events);
      indexedRevision = c.state!.revision;
    }
    final linkedDay = localDay(widget.clock(), c.state!.zone);
    return PopScope(
      canPop: leaving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(leave());
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): () {
            if (current.status == 'pending') unawaited(toggle());
          },
          const SingleActivator(LogicalKeyboardKey.enter): () {
            if (!acting && current.status == 'pending') unawaited(complete());
          },
        },
        child: Focus(
          autofocus: true,
          child: RunnerView(
            session: session,
            ready: ready,
            acting: acting,
            running: watch.isRunning,
            elapsed: elapsed,
            sessionElapsed: session.elapsed + watch.elapsed.inSeconds,
            recoveryFailed: recoveryFailed,
            habit: habit,
            linkedValue: habit == null
                ? 0
                : cachedIndex!.value(habit.id, linkedDay),
            linkedTarget: habit == null
                ? 0
                : scheduleOn(habit, linkedDay)?.target ?? 1000,
            extra: extra,
            onExtra: (v) => setState(() => extra = v),
            onBack: () => unawaited(leave()),
            onComplete: () => unawaited(complete()),
            onSkip: () => unawaited(complete(skip: true)),
            onToggle: () => unawaited(toggle()),
            onExtend: () => unawaited(extend()),
            onNote: () => unawaited(note()),
            onAutoNext: (v) => unawaited(autoNext(v)),
            onMove: (d) => unawaited(move(d)),
            onUndo: () => unawaited(undo()),
            onFinish: () => unawaited(finish()),
            onAbort: () => unawaited(finish(abort: true)),
          ),
        ),
      ),
    );
  }
}
