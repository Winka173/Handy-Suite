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

  /// Android and iOS, and Windows toasts (Windows lists what is pending by
  /// id only, which is all the plan needs: it cancels and schedules by id).
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows);
  Future<void> ready() => _ready ??= () async {
    if (!supported) return;
    await plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        windows: windowsIdentity('boards'),
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
  bool get _windows => defaultTargetPlatform == TargetPlatform.windows;

  Future<bool> request() async {
    if (!supported) return false;
    await ready();
    // Windows has no runtime permission; toasts are turned off in Settings.
    if (_windows) return true;
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

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      defaultTargetPlatform == TargetPlatform.android
      ? plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
      : null;

  /// Whether Android lets notifications ring at their exact time. Up to
  /// Android 12 it does; from 13 the person may have to allow "Alarms &
  /// reminders". Without it Android may deliver them late, sometimes hours.
  Future<bool> exactAllowed() async {
    if (!supported || _android == null) return true;
    await ready();
    try {
      return await _android!.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the phone's "Alarms & reminders" page for Handy Boards.
  Future<void> askExact() async {
    if (_android == null) return;
    await ready();
    await _android!.requestExactAlarmsPermission();
  }

  /// Schedules what the cards and preferences plan (see the engine's
  /// `planNotifications`) and cancels anything else this app scheduled. The
  /// keys are stable, so running it on every change, start and resume never
  /// duplicates a notification.
  Future<void> sync(BoardsState s, {bool vi = false, bool pro = false}) async {
    if (!supported) return;
    await ready();
    final allowed =
        s.preferences['notifications'] == true &&
        (_windows || await DeviceNotifications().allowed(false));
    final notes = allowed
        ? planNotifications(s, DateTime.now(), vi: vi, pro: pro)
        : const <PlannedNote>[];
    final ids = <int, PlannedNote>{
      for (final n in notes)
        ReminderRequest(n.key, tz.TZDateTime.from(n.at, tz.local)).id: n,
    };
    if (ids.length != notes.length)
      throw StateError('Notification ID collision');
    final mode = ids.isNotEmpty && await exactAllowed()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final old in await plugin.pendingNotificationRequests())
      if (!ids.containsKey(old.id)) await plugin.cancel(id: old.id);
    for (final MapEntry(key: id, value: n) in ids.entries)
      await plugin.zonedSchedule(
        id: id,
        title: n.title,
        body: n.body,
        scheduledDate: tz.TZDateTime.from(n.at, tz.local),
        notificationDetails: NotificationDetails(
          android: n.channel == 'reminders'
              ? const AndroidNotificationDetails(
                  'handy-boards-reminders',
                  'Task reminders',
                  importance: Importance.defaultImportance,
                )
              : const AndroidNotificationDetails(
                  'handy-boards-summary',
                  'Summaries',
                  importance: Importance.low,
                ),
          windows: const WindowsNotificationDetails(),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: false,
          ),
        ),
        androidScheduleMode: mode,
        payload: n.link,
      );
  }
}
