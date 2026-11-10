import 'dart:async';
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'controller.dart';
import 'run_notice.dart';
import 'runner_view.dart';
import 'ui/words.dart';

class RoutineRunner extends StatefulWidget {
  final HabitController controller;
  final String sessionId;
  final DateTime Function() clock;
  final bool fresh;

  /// Says in the system notifications that the run is paused while the
  /// app is away; null shows nothing (tests, previews).
  final HabitRunNotices? notices;
  const RoutineRunner({
    super.key,
    required this.controller,
    required this.sessionId,
    required this.clock,
    this.fresh = false,
    this.notices,
  });
  @override
  State<RoutineRunner> createState() => _RunnerState();
}

class _RunnerState extends State<RoutineRunner> with WidgetsBindingObserver {
  final watch = Stopwatch();
  Timer? timer;
  bool acting = false, ready = false, leaving = false, extra = false;
  bool foreground = true, noticed = false;
  HabitIndex? cachedIndex;
  int? indexedRevision;
  bool recoveryFailed = false, askingExit = false;
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
      if (widget.fresh &&
          foreground &&
          session.steps[session.cursor].status == 'pending' &&
          pendingBranch(session) == null &&
          c.state!.settings['routineAutoTimer'] != false) {
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
    unawaited(widget.notices?.clear());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) watch.stop();
    if (!foreground && ready && !acting) unawaited(perform(pause));
    // Gone from the screen (not just a system sheet over it): say where
    // the run stopped. Back on screen: take that away.
    if ((state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused) &&
        !noticed)
      _notice();
    if (foreground && noticed) {
      noticed = false;
      unawaited(widget.notices?.clear());
    }
  }

  /// "Morning · Step 3 of 5" / "Paused · 2:00 left. Tap to continue."
  void _notice() {
    final notices = widget.notices;
    final s = c.state;
    if (notices == null || s == null || !mounted) return;
    final run = session;
    if (run.status != 'active') return;
    noticed = true;
    final step = run.steps[run.cursor];
    final left = secondsLeft(step, running: watch.elapsed.inSeconds);
    final allDone = run.steps.every((x) => x.status != 'pending');
    final title = t(
      '${run.title} · Step ${run.cursor + 1} of ${run.steps.length}',
      '${run.title} · Bước ${run.cursor + 1}/${run.steps.length}',
    );
    final body = allDone
        ? t(
            'All steps done. Tap to finish.',
            'Đã xong các bước. Chạm để kết thúc.',
          )
        : left == null
        ? t('Paused. Tap to continue.', 'Đã tạm dừng. Chạm để tiếp tục.')
        : left >= 0
        ? t(
            'Paused · ${clockText(left)} left. Tap to continue.',
            'Đã tạm dừng · còn ${clockText(left)}. Chạm để tiếp tục.',
          )
        : t(
            'Paused · ${clockText(-left)} over. Tap to continue.',
            'Đã tạm dừng · quá ${clockText(-left)}. Chạm để tiếp tục.',
          );
    unawaited(notices.show(s, RunNotice(run.id, title, body), widget.clock()));
  }

  Future<bool> perform(Future<void> Function() operation) async {
    if (acting || !ready) return false;
    setState(() => acting = true);
    try {
      await operation();
      // A save may cross the background transition. Persist the stopped timer
      // after it finishes, before accepting another foreground action.
      if (!foreground && session.status == 'active') await pause();
      return true;
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
      return false;
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
        pendingBranch(session) != null ||
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
    if (pendingBranch(session) != null) return;
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
      if (c.state!.settings['routineHaptics'] == true &&
          mounted &&
          !MediaQuery.disableAnimationsOf(context))
        await HapticFeedback.lightImpact();
      // The next step starts timing at once; pausing stays a choice.
      if (foreground &&
          c.state!.settings['routineAutoTimer'] != false &&
          session.steps[session.cursor].status == 'pending')
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
    if (session.inputs.isNotEmpty &&
        session.steps[next].status == 'pending' &&
        session.steps.take(next).any((s) => s.status == 'pending'))
      return;
    await c.change(
      (s) => putSession(s, session.copy({'cursor': next, 'anchor': null})),
      remember: false,
    );
    watch.reset();
  });
  Future<void> leave() async {
    if (leaving || acting || askingExit || !ready) return;
    askingExit = true;
    final ok =
        c.state!.settings['confirmRoutineExit'] == false ||
        await confirmHandy(
          context,
          title: t('Pause and exit?', 'Tạm dừng và thoát?'),
          message: t(
            'Your progress is saved. Resume this run from Routines or Today.',
            'Tiến độ được lưu. Tiếp tục phiên từ Quy trình hoặc Hôm nay.',
          ),
          confirmLabel: t('Pause and exit', 'Tạm dừng và thoát'),
        );
    askingExit = false;
    if (!ok || !mounted) return;
    if (!await perform(pause) || !mounted) return;
    setState(() => leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  bool get shortcutsAllowed =>
      ready &&
      !acting &&
      !askingExit &&
      ModalRoute.of(context)?.isCurrent == true &&
      FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<EditableText>() ==
          null;

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
        session.copy({
          'steps': steps.map((s) => s.toJson()).toList(),
          if (session.inputs.isNotEmpty)
            'trace': [
              ...session.trace,
              {'kind': 'extend', 'step': current.plan.id, 'seconds': 60},
            ],
        }),
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

  Future<void> choose(String option) => perform(() async {
    await pause();
    await c.change((s) => chooseRoutineBranch(s, session.id, option));
    watch.reset();
    if (c.state!.settings['routineAutoTimer'] != false) await resume();
  });

  Future<void> changeChoice(String branch) => perform(() async {
    await pause();
    await c.change((s) => undoRoutineChoice(s, session.id, branch));
    watch.reset();
  });

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
    unawaited(widget.notices?.clear(always: true));
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
    final habit = c.state!.liveHabits
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
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (shortcutsAllowed) unawaited(leave());
          },
          const SingleActivator(LogicalKeyboardKey.space): () {
            if (shortcutsAllowed && current.status == 'pending')
              unawaited(toggle());
          },
          const SingleActivator(LogicalKeyboardKey.enter): () {
            if (!shortcutsAllowed) return;
            if (session.steps.every((s) => s.status != 'pending')) {
              unawaited(finish());
            } else if (current.status == 'pending') {
              unawaited(complete());
            }
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
            onChoose: (option) => unawaited(choose(option)),
            onChangeChoice: (branch) => unawaited(changeChoice(branch)),
          ),
        ),
      ),
    );
  }
}
