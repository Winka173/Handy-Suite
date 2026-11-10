import 'dart:ui' show PlatformDispatcher;
import 'package:handy_notifications/native.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'run_notice.dart';

class HabitReminders {
  final DeviceNotifications port;
  HabitReminders({DeviceNotifications? port})
    : port = port ?? DeviceNotifications();
  bool get supported => supportsLocalReminders;
  Future<bool> request() =>
      supported ? port.allowed(true) : Future.value(false);
  Future<bool> permission() =>
      supported ? port.allowed(false) : Future.value(false);
  Future<void> test(HabitState state) async {
    if (!supported || !await permission())
      throw const FormatException(
        'Enable notifications first / Hãy cho phép thông báo trước',
      );
    await port.plugin.show(
      id: 0x48616268,
      title: 'Handy Habit',
      body: _reminderVi(state)
          ? 'Thông báo thử của bạn.'
          : 'Your test notification.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'handy-habit-reminders',
          'Local reminders',
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: false),
      ),
    );
  }

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
        // The paused-run notice is not a reminder; leave it alone.
        if (old.id == DeviceRunNoticePort.id) continue;
        if (!desired.containsKey(old.id)) await port.plugin.cancel(id: old.id);
      }
      for (final entry in desired.entries) {
        await port.plugin.zonedSchedule(
          id: entry.key,
          title: 'Handy Habit',
          body: reminderBody(state, entry.value),
          scheduledDate: entry.value.when,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'handy-habit-reminders',
              'Local reminders',
              importance: Importance.defaultImportance,
              visibility: NotificationVisibility.private,
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

String reminderBody(HabitState state, DueReminder due) {
  final vi = _reminderVi(state);
  if (state.settings['privateNotifications'] != false)
    return vi ? 'Đến giờ thói quen của bạn' : 'Your practice is due';
  final rule = objects(state.settings['reminders'] ?? [])
      .map(Reminder.fromJson)
      .where((r) => due.key.startsWith('${r.id}:'))
      .firstOrNull;
  final name = rule?.type == 'habit'
      ? state.liveHabits.where((h) => h.id == rule?.target).firstOrNull?.title
      : state.liveRoutines
            .where((r) => r.id == rule?.target)
            .firstOrNull
            ?.title;
  return name ?? (vi ? 'Đến giờ thói quen của bạn' : 'Your practice is due');
}

bool _reminderVi(HabitState state) =>
    state.settings['locale'] == 'vi' ||
    (state.settings['locale'] == null ||
            state.settings['locale'] == 'system') &&
        PlatformDispatcher.instance.locale.languageCode == 'vi';
