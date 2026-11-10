import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../runner.dart';
import '../scope.dart';

/// Starts [routine] (or the one-off [plan] made from it), or goes back to
/// the routine already running: only one runs at a time.
Future<void> startRoutine(
  BuildContext context,
  HabitScope scope,
  Routine routine, {
  List<RoutineStep>? plan,
}) async {
  final running = scope.activeSession;
  if (running != null) {
    if (running.routine != routine.id || plan != null)
      showHandyMessage(
        context,
        tr(
          context,
          '${running.title} is still running; finish or stop it first.',
          '${running.title} còn đang chạy; hãy xong hoặc dừng trước.',
        ),
      );
    await openSession(context, scope, running.id);
    return;
  }
  final session = startSession(
    routine,
    scope.today,
    scope.clock(),
    plan: plan,
    state: scope.state,
  );
  final ok = await scope.write(context, (s) {
    if (!s.liveRoutines.any((r) => r.id == routine.id && !r.archived)) {
      throw StateError('Routine is no longer available');
    }
    return putSession(s, session);
  });
  if (ok && context.mounted)
    await openSession(context, scope, session.id, fresh: true);
}

/// The runner for a session, full screen.
Future<void> openSession(
  BuildContext context,
  HabitScope scope,
  String id, {
  bool fresh = false,
}) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    settings: RouteSettings(name: '/run/$id'),
    builder: (_) => RoutineRunner(
      controller: scope.controller,
      sessionId: id,
      clock: scope.clock,
      fresh: fresh,
      notices: scope.notices,
    ),
  ),
);
