import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_notifications/native.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'read_later.dart';

/// The two buttons on a read-later notification. Both work without
/// opening the app: they are written down here and the app applies them
/// to the library the next time it runs (before planning again).
const readAction = 'read', laterAction = 'later';

/// Where the buttons' choices wait for the app (device preferences).
const notifyActionsKey = 'bookmark.notify.actions';

/// A reminder set in the share sheet before the app took the link in: its
/// notification carries `share:<share id>` and the app moves it onto the
/// bookmark when it takes the share.
const sharePrefix = 'share:';

/// What a notification carries: the item's id and its title, so "Remind in
/// 1 hour" can show the same words without reading the library.
String reminderPayload(String id, String title) => jsonEncode({
  'id': id,
  't': title.length > 120 ? title.substring(0, 120) : title,
});

/// The item id in a payload (older ones are the bare id).
({String id, String title}) readPayload(String payload) {
  if (payload.startsWith('{')) {
    try {
      final j = jsonDecode(payload) as Map;
      return (id: '${j['id']}', title: '${j['t'] ?? ''}');
    } catch (_) {}
  }
  return (id: payload, title: '');
}

NotificationDetails reminderDetails(bool vietnamese) => NotificationDetails(
  android: AndroidNotificationDetails(
    'handy-save-reminders',
    vietnamese ? 'Nhắc đọc sau' : 'Read later',
    channelDescription: vietnamese
        ? 'Lời nhắc bạn đặt cho từng mục'
        : 'Reminders you set on single items',
    importance: Importance.defaultImportance,
    visibility: NotificationVisibility.private,
    actions: [
      AndroidNotificationAction(
        readAction,
        vietnamese ? 'Đã đọc' : 'Mark as read',
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        laterAction,
        vietnamese ? 'Nhắc lại sau 1 giờ' : 'Remind in 1 hour',
        cancelNotification: true,
      ),
    ],
  ),
  iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: false),
  windows: const WindowsNotificationDetails(),
);

/// Records a button press and, for "Remind in 1 hour", schedules it again
/// at once (the app may not run before then). Runs in the app or in the
/// background isolate the plugin starts for a button.
Future<void> recordNotifyAction(
  NotificationResponse response, {
  FlutterLocalNotificationsPlugin? plugin,
}) async {
  final action = response.actionId;
  final payload = response.payload;
  if (payload == null || (action != readAction && action != laterAction)) {
    return;
  }
  final item = readPayload(payload);
  final at = DateTime.now().add(snoozeFor);
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final list = prefs.getStringList(notifyActionsKey) ?? <String>[];
  list.add(
    jsonEncode({
      'id': item.id,
      'action': action,
      if (action == laterAction) 'at': at.toUtc().toIso8601String(),
    }),
  );
  await prefs.setStringList(notifyActionsKey, list);
  if (action != laterAction || response.id == null) return;
  tzdata.initializeTimeZones();
  final vi = prefs.getString('bookmark.notify.lang') == 'vi';
  final p = plugin ?? FlutterLocalNotificationsPlugin();
  if (plugin == null) {
    await p.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }
  await p.zonedSchedule(
    id: response.id!,
    title: item.title.isEmpty ? 'Handy Bookmark' : item.title,
    body: vi ? 'Đến giờ đọc mục đã lưu' : 'Time to read what you saved',
    scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
    notificationDetails: reminderDetails(vi),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: payload,
  );
}

/// The background entry for the notification buttons.
@pragma('vm:entry-point')
void onNotificationButtonInBackground(NotificationResponse response) {
  recordNotifyAction(response);
}

/// The button presses waiting to be applied, taken out of the list.
Future<List<({String id, String action, DateTime? at})>>
takeNotifyActions() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final list = prefs.getStringList(notifyActionsKey) ?? const <String>[];
  if (list.isEmpty) return const [];
  await prefs.remove(notifyActionsKey);
  return [
    for (final raw in list)
      if (jsonDecode(raw) case {
        'id': final String id,
        'action': final String a,
      })
        (
          id: id,
          action: a,
          at: DateTime.tryParse('${(jsonDecode(raw) as Map)['at'] ?? ''}'),
        ),
  ];
}

class SaveReminders {
  final DeviceNotifications permissions = DeviceNotifications(
    windows: windowsIdentity('bookmark'),
  );
  Future<void>? _ready;
  bool get supported => supportsLocalReminders;

  /// [onOpen] gets a tapped notification's payload; [onButton] a button
  /// press while the app runs (already recorded).
  Future<String?> initialize(
    ValueChanged<String> onOpen, {
    VoidCallback? onButton,
  }) async {
    if (!supported) return null;
    _ready ??= () async {
      await permissions.ready();
      await permissions.plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: const DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          windows: windowsIdentity('bookmark'),
        ),
        onDidReceiveNotificationResponse: (response) async {
          if (response.actionId == readAction ||
              response.actionId == laterAction) {
            await recordNotifyAction(response, plugin: permissions.plugin);
            onButton?.call();
          } else if (response.payload != null) {
            onOpen(response.payload!);
          }
        },
        onDidReceiveBackgroundNotificationResponse:
            onNotificationButtonInBackground,
      );
    }();
    await _ready;
    final launch = await permissions.plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true &&
            launch?.notificationResponse?.actionId == null
        ? launch?.notificationResponse?.payload
        : null;
  }

  Future<bool> request() =>
      supported ? permissions.allowed(true) : Future.value(false);

  /// Whether notifications may show now, without asking.
  Future<bool> allowedNow() async {
    if (!supported) return false;
    try {
      return await permissions.allowed(false);
    } catch (_) {
      return false;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      defaultTargetPlatform == TargetPlatform.android
      ? permissions.plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
      : null;

  /// Whether Android rings reminders at their exact time (to 12 by
  /// default; from 13 after the person allows Alarms & reminders).
  Future<bool> exactAllowed() async {
    if (!supported || _android == null) return true;
    try {
      return await _android!.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> askExact() async => _android?.requestExactAlarmsPermission();

  /// Schedules the person's read-later reminders (when [enabled]) and
  /// cancels the others of ours. Reminders set in the share sheet for a
  /// link the app has not taken in yet are left alone.
  Future<void> sync(
    List<Bookmark> bookmarks, {
    required bool enabled,
    required bool vietnamese,
  }) async {
    if (!supported) return;
    if (_ready != null) await _ready;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bookmark.notify.lang', vietnamese ? 'vi' : 'en');
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
    // Windows lists pending toasts by id only: there, every id of ours that
    // is not wanted goes, except the "needs attention" ones.
    final windows = defaultTargetPlatform == TargetPlatform.windows;
    final kept = {
      for (final k in const ['backup', 'sync', 'shares', 'task'])
        ReminderRequest('problem:$k', tz.TZDateTime.utc(2000)).id,
    };
    for (final notification in pending) {
      final payload = notification.payload;
      if (kept.contains(notification.id)) continue;
      if (payload == null && !windows) continue;
      if (payload != null &&
          (payload.startsWith(sharePrefix) ||
              problemPayloads.contains(payload)))
        continue;
      if (!wanted.containsKey(notification.id))
        await permissions.plugin.cancel(id: notification.id);
    }
    if (!enabled || !await permissions.allowed(false)) return;
    final location = await deviceLocation();
    final mode = await exactAllowed()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final entry in wanted.entries) {
      final b = entry.value;
      final title = b.title.isNotEmpty
          ? b.title
          : (b.hasUrl ? b.sourceDomain : 'Handy Bookmark');
      await permissions.plugin.zonedSchedule(
        id: entry.key,
        title: title,
        body: vietnamese
            ? 'Đến giờ đọc mục đã lưu'
            : 'Time to read what you saved',
        scheduledDate: tz.TZDateTime.from(
          DateTime.parse(b.reminderAt!),
          location,
        ),
        notificationDetails: reminderDetails(vietnamese),
        androidScheduleMode: mode,
        payload: reminderPayload(b.id, title),
      );
    }
  }

  /// Withdraws the share sheet's reminder once the app has moved it onto
  /// the bookmark.
  Future<void> cancelShare(String shareId) async {
    if (!supported) return;
    if (_ready != null) await _ready;
    await permissions.plugin.cancel(
      id: ReminderRequest('$sharePrefix$shareId', tz.TZDateTime.utc(2000)).id,
    );
  }

  Future<void> cancelAll() async {
    if (supported) await permissions.plugin.cancelAll();
  }
}

/// The payloads of the "needs attention" notifications (see
/// `problem_notices.dart`); reminder planning never cancels them.
const problemPayloads = {'problem:backup', 'problem:sync', 'problem:shares'};

/// From the share sheet (its own engine): asks for the permission if
/// needed and schedules the reminder under `share:<id>`, with no buttons
/// (the item does not exist yet). The app moves it onto the bookmark when
/// it takes the share in. False when notifications are not allowed.
Future<bool> scheduleShareReminder(
  String shareId,
  String title,
  DateTime at, {
  required bool vietnamese,
}) async {
  if (!supportsLocalReminders) return false;
  final n = DeviceNotifications();
  await n.ready();
  await n.plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );
  if (!await n.allowed(true)) return false;
  final android = defaultTargetPlatform == TargetPlatform.android
      ? n.plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
      : null;
  final exact = await android?.canScheduleExactNotifications() ?? true;
  await n.plugin.zonedSchedule(
    id: ReminderRequest('$sharePrefix$shareId', tz.TZDateTime.utc(2000)).id,
    title: title.isEmpty ? 'Handy Bookmark' : title,
    body: vietnamese ? 'Đến giờ đọc mục đã lưu' : 'Time to read what you saved',
    scheduledDate: tz.TZDateTime.from(at, await deviceLocation()),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'handy-save-reminders',
        vietnamese ? 'Nhắc đọc sau' : 'Read later',
        importance: Importance.defaultImportance,
        visibility: NotificationVisibility.private,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: false,
      ),
    ),
    androidScheduleMode: exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
    payload: '$sharePrefix$shareId',
  );
  return true;
}
