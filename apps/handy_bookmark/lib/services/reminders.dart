import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_notifications/native.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:timezone/timezone.dart' as tz;

class SaveReminders {
  final DeviceNotifications permissions = DeviceNotifications();
  Future<void>? _ready;
  bool get supported => supportsLocalReminders;
  Future<String?> initialize(ValueChanged<String> onOpen) async {
    if (!supported) return null;
    _ready ??= () async {
      await permissions.ready();
      await permissions.plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) onOpen(response.payload!);
        },
      );
    }();
    await _ready;
    final launch = await permissions.plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? launch?.notificationResponse?.payload
        : null;
  }

  Future<bool> request() =>
      supported ? permissions.allowed(true) : Future.value(false);
  Future<void> sync(
    List<Bookmark> bookmarks, {
    required bool enabled,
    required bool vietnamese,
  }) async {
    if (!supported) return;
    if (_ready != null) await _ready;
    final pending = await permissions.plugin.pendingNotificationRequests();
    final now = DateTime.now();
    final plan = enabled
        ? bookmarks
              .where(
                (b) =>
                    b.reminderAt != null &&
                    DateTime.parse(b.reminderAt!).isAfter(now),
              )
              .toList()
        : <Bookmark>[];
    plan.sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
    final limited = plan.take(50).toList();
    final wanted = {
      for (final b in limited)
        ReminderRequest('save:${b.id}', tz.TZDateTime.utc(2000)).id: b,
    };
    if (wanted.length != limited.length)
      throw StateError('Reminder identifier collision');
    for (final notification in pending) {
      if (notification.payload != null && !wanted.containsKey(notification.id))
        await permissions.plugin.cancel(id: notification.id);
    }
    if (!enabled || !await permissions.allowed(false)) return;
    final location = await deviceLocation();
    for (final entry in wanted.entries) {
      final b = entry.value;
      await permissions.plugin.zonedSchedule(
        id: entry.key,
        title: 'Handy Bookmark',
        body: vietnamese
            ? 'Đến giờ xem một liên kết đã lưu'
            : 'A saved link is due for review',
        scheduledDate: tz.TZDateTime.from(
          DateTime.parse(b.reminderAt!),
          location,
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'handy-save-reminders',
            'Bookmark reminders',
            channelDescription: 'User scheduled bookmark reminders',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: b.id,
      );
    }
  }

  Future<void> cancelAll() async {
    if (supported) await permissions.plugin.cancelAll();
  }
}
