import 'package:handy_notifications/native.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

class HabitReminders {
  final DeviceNotifications port;
  HabitReminders({DeviceNotifications? port})
    : port = port ?? DeviceNotifications();
  bool get supported => supportsLocalReminders;
  Future<bool> request() =>
      supported ? port.allowed(true) : Future.value(false);
  Future<void> _queue = Future.value();
  Future<void> sync(HabitState state) {
    final next = _queue.catchError((Object _) {}).then((_) async {
      if (!supported) return;
      await port.ready();
      final planned =
          state.settings['notifications'] == true && await port.allowed(false)
          ? dueReminders(state, DateTime.now())
          : <DueReminder>[];
      final desired = {
        for (final r in planned)
          ReminderRequest('habit:${r.key}', r.when).id: r,
      };
      if (desired.length != planned.length)
        throw StateError('Reminder ID collision');
      for (final old in await port.plugin.pendingNotificationRequests()) {
        if (!desired.containsKey(old.id)) await port.plugin.cancel(id: old.id);
      }
      for (final entry in desired.entries) {
        await port.plugin.zonedSchedule(
          id: entry.key,
          title: 'Handy Habit',
          body: 'Your practice is due / Đến giờ thói quen của bạn',
          scheduledDate: entry.value.when,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'handy-habit-reminders',
              'Local reminders',
              importance: Importance.defaultImportance,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: false,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: entry.value.key,
        );
      }
    });
    _queue = next;
    return next;
  }
}
