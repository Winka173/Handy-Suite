import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import 'handy_notifications.dart';

bool get supportsLocalReminders =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
Future<tz.Location> deviceLocation() async {
  data.initializeTimeZones();
  final zone = await FlutterTimezone.getLocalTimezone();
  return tz.getLocation(zone.identifier);
}

class DeviceNotifications implements NotificationsPort {
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? initialized;
  Future<void> ready() => initialized ??= () async {
    if (!supportsLocalReminders)
      throw UnsupportedError(
        'Notifications not verified on this platform. Use the in-app due list.',
      );
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }();
  @override
  Future<bool> allowed(bool request) async {
    await ready();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      return (request
              ? await android.requestNotificationsPermission()
              : await android.areNotificationsEnabled()) ??
          false;
    }
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()!;
    if (request)
      return await ios.requestPermissions(
            alert: true,
            badge: false,
            sound: false,
          ) ??
          false;
    return (await ios.checkPermissions())?.isEnabled ?? false;
  }

  @override
  Future<Map<int, String>> pending(String namespace) async {
    await ready();
    final result = <int, String>{};
    for (final r in await plugin.pendingNotificationRequests()) {
      try {
        final payload = jsonDecode(r.payload ?? 'null');
        if (payload is Map &&
            payload['namespace'] == namespace &&
            payload['signature'] is String)
          result[r.id] = payload['signature'];
      } catch (_) {}
    }
    return result;
  }

  @override
  Future<void> schedule(String namespace, ReminderRequest r) async {
    await ready();
    await plugin.zonedSchedule(
      id: r.id,
      title: namespace == 'keep' ? 'Handy Keep' : 'Handy Recall',
      body: namespace == 'keep'
          ? 'An item has a due date / Có đồ dùng đến hạn'
          : 'Review your due cards / Ôn các thẻ đến hạn',
      scheduledDate: r.when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'handy-local',
          'Local reminders',
          channelDescription: 'User enabled local reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
          presentBadge: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: r.daily ? DateTimeComponents.time : null,
      payload: jsonEncode({'namespace': namespace, 'signature': r.signature}),
    );
  }

  @override
  Future<void> cancel(int id) async {
    await ready();
    await plugin.cancel(id: id);
  }
}
