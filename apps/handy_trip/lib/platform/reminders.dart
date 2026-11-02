import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_notifications/native.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:timezone/timezone.dart' as tz;

class TripReminders {
  final DeviceNotifications port = DeviceNotifications();
  bool get supported => supportsLocalReminders;
  Future<bool> request() =>
      supported ? port.allowed(true) : Future.value(false);
  Future<void> _queue = Future.value();
  Future<void> sync(TripState state) {
    final job = _queue.catchError((Object _) {}).then((_) async {
      if (!supported) return;
      await port.ready();
      final allowed =
              state.settings['notifications'] == true &&
              await port.allowed(false),
          now = DateTime.now();
      final rows = allowed
          ? (state.alarms
                    .where(
                      (a) => a.enabled && DateTime.parse(a.at).isAfter(now),
                    )
                    .toList()
                  ..sort(
                    (a, b) =>
                        DateTime.parse(a.at).compareTo(DateTime.parse(b.at)),
                  ))
                .take(50)
                .toList()
          : <TripAlarm>[];
      final desired = {
        for (final a in rows)
          ReminderRequest(
            'trip:${a.key}',
            tz.TZDateTime.from(DateTime.parse(a.at), location(a.zone)),
          ).id: a,
      };
      if (desired.length != rows.length)
        throw StateError('Reminder ID collision');
      for (final old in await port.plugin.pendingNotificationRequests())
        if (!desired.containsKey(old.id)) await port.plugin.cancel(id: old.id);
      for (final e in desired.entries)
        await port.plugin.zonedSchedule(
          id: e.key,
          title: 'Handy Trip',
          body: 'A travel reminder is due / Đến giờ nhắc chuyến đi',
          scheduledDate: tz.TZDateTime.from(
            DateTime.parse(e.value.at),
            location(e.value.zone),
          ),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'handy-trip-reminders',
              'Travel reminders',
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
    });
    _queue = job;
    return job;
  }
}
