import 'package:handy_files/handy_files.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';
import 'package:timezone/timezone.dart' as tz;
import 'controller.dart';
import 'reminders.dart';
import 'run_notice.dart';

/// What every Habit screen shares: the state, the adapters, the clock and
/// the area on screen.
class HabitScope {
  final HabitController controller;
  final HandyFiles files;
  final HabitReminders reminders;
  final HabitRunNotices notices;
  final DateTime Function() clock;

  /// Automatic backups to a folder; null in tests that do not need them.
  final HandyAutoBackup? autoBackup;

  /// Today, Habits, Routines or Insights.
  final area = ValueNotifier(0);
  HabitScope({
    required this.controller,
    required this.files,
    required this.reminders,
    required this.notices,
    required this.clock,
    this.autoBackup,
  });

  HabitState get state => controller.state!;
  String get today => localDay(clock(), state.zone);
  HabitIndex get index => HabitIndex.of(state);

  /// The hour of the day where the data's time zone is.
  int get hour => tz.TZDateTime.from(clock(), location(state.zone)).hour;

  Habit? habit(String? id) =>
      id == null ? null : state.liveHabits.where((h) => h.id == id).firstOrNull;
  Routine? routine(String? id) => id == null
      ? null
      : state.liveRoutines.where((r) => r.id == id).firstOrNull;
  RoutineSession? get activeSession =>
      state.sessions.where((s) => s.status == 'active').firstOrNull;

  /// Identity colours keep the order things were made in.
  int habitHue(String id) => state.habits.indexWhere((h) => h.id == id);
  int routineHue(String id) => state.routines.indexWhere((r) => r.id == id);

  bool pro(BuildContext context) => LifetimeScope.maybeOf(context)?.pro == true;

  void dispose() => area.dispose();

  /// Writes, then says so with an Undo; a failure says nothing changed.
  Future<bool> write(
    BuildContext context,
    HabitState Function(HabitState) change, {
    String Function(BuildContext)? done,
    bool remember = true,
  }) async {
    try {
      await controller.change(change, remember: remember);
    } catch (e) {
      if (context.mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'Not saved: ${errorText(context, e)}. Nothing changed.',
            'Chưa lưu được: ${errorText(context, e)}. Không có gì thay đổi.',
          ),
        );
      return false;
    }
    if (done != null && context.mounted) announce(context, done(context));
    return true;
  }

  /// Says what was just written, with an Undo for that one change.
  void announce(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final undone = tr(context, 'Undone.', 'Đã hoàn tác.');
    final failed = tr(
      context,
      'Undo is no longer available.',
      'Không còn hoàn tác được.',
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // With an action Flutter keeps it until tapped; this one goes away.
          persist: false,
          action: controller.canUndo
              ? SnackBarAction(
                  key: const Key('snack-undo'),
                  label: tr(context, 'Undo', 'Hoàn tác'),
                  onPressed: () async {
                    try {
                      await controller.undo();
                      messenger.showSnackBar(SnackBar(content: Text(undone)));
                    } catch (_) {
                      messenger.showSnackBar(SnackBar(content: Text(failed)));
                    }
                  },
                )
              : null,
        ),
      );
  }
}
