import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_notifications/native.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:timezone/timezone.dart' as tz;

class BoardsReminders {
  final void Function(String)? onTask;
  final plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  BoardsReminders({this.onTask});
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<void> ready() => _ready ??= () async {
    if (!supported) return;
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) onTask?.call(r.payload!);
      },
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse?.payload != null)
      onTask?.call(launch!.notificationResponse!.payload!);
  }();
  Future<bool> request() async {
    if (!supported) return false;
    await ready();
    if (defaultTargetPlatform == TargetPlatform.android)
      return await plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()!
              .requestNotificationsPermission() ??
          false;
    return await plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()!
            .requestPermissions(alert: true, badge: false, sound: false) ??
        false;
  }

  Future<void> sync(BoardsState s) async {
    if (!supported) return;
    await ready();
    final allowed =
            s.preferences['notifications'] == true &&
            await DeviceNotifications().allowed(false),
        now = DateTime.now();
    final desired = allowed
        ? (s.rows('reminders').where((r) {
                final t = s.maybe('tasks', r.str('task'));
                return r.flag('enabled') &&
                    t != null &&
                    activeTask(t) &&
                    !completed(s, t) &&
                    DateTime.parse(r.str('at')).isAfter(now);
              }).toList()..sort(
                (a, b) => DateTime.parse(
                  a.str('at'),
                ).compareTo(DateTime.parse(b.str('at'))),
              ))
              .take(50)
              .toList()
        : <BoardRecord>[];
    final ids = {
      for (final r in desired)
        ReminderRequest(
          'boards:${r.id}',
          tz.TZDateTime.from(DateTime.parse(r.str('at')), zone(r.str('zone'))),
        ).id: r,
    };
    if (ids.length != desired.length)
      throw StateError('Notification ID collision');
    for (final old in await plugin.pendingNotificationRequests())
      if (!ids.containsKey(old.id)) await plugin.cancel(id: old.id);
    for (final e in ids.entries)
      await plugin.zonedSchedule(
        id: e.key,
        title: 'Handy Boards',
        body: 'A task reminder is due / Đến giờ nhắc công việc',
        scheduledDate: tz.TZDateTime.from(
          DateTime.parse(e.value.str('at')),
          zone(e.value.str('zone')),
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'handy-boards-reminders',
            'Task reminders',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: e.value.str('task'),
      );
  }
}
