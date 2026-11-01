import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_notifications/native.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:timezone/timezone.dart' as tz;

class SpendReminders {
  final port = DeviceNotifications();
  Future<void> pending = Future.value();
  bool get supported => supportsLocalReminders;
  Future<bool> request() =>
      supported ? port.allowed(true) : Future.value(false);
  Future<void> sync(SpendState state) {
    pending = pending.catchError((Object _) {}).then((_) async {
      if (!supported) return;
      await port.ready();
      final now = DateTime.now(),
          today = reportDay(now.toUtc().toIso8601String(), state.zone),
          dates = upcoming(
            state,
            today,
            day(calendar(today).add(const Duration(days: 365))),
          ).where((o) => o.bill.remind).toList();
      final loc = location(state.zone),
          plan = <int, ({String key, tz.TZDateTime at})>{};
      if (state.settings['notifications'] == true &&
          await port.allowed(false)) {
        for (final o in dates) {
          final date = calendar(o.date),
              when = tz.TZDateTime(loc, date.year, date.month, date.day, 9);
          if (!when.isAfter(now)) continue;
          final id = ReminderRequest('spend:${o.id}', when).id;
          if (plan.containsKey(id))
            throw StateError('Notification ID collision');
          plan[id] = (key: o.id, at: when);
          if (plan.length == 50) break;
        }
      }
      for (final old in await port.plugin.pendingNotificationRequests()) {
        if (!plan.containsKey(old.id)) await port.plugin.cancel(id: old.id);
      }
      for (final e in plan.entries) {
        await port.plugin.zonedSchedule(
          id: e.key,
          title: 'Handy Spend',
          body: 'A planned item is due / Có khoản đến hạn',
          scheduledDate: e.value.at,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'handy-spend-reminders',
              'Local reminders',
              importance: Importance.defaultImportance,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: false,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: e.value.key,
        );
      }
    });
    return pending;
  }
}
