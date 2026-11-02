import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import 'handy_notifications.dart';

bool get supportsLocalReminders =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.windows);

/// Windows toasts cannot repeat by themselves, so a daily reminder is laid
/// out as this many single ones and topped up each time the app opens.
int get dailyCopies =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows ? 14 : 1;

/// How each app is known to Windows: its name on toasts, an
/// AppUserModelID and a GUID that must never change once shipped.
const _windowsIds = {
  'keep': ('Handy Keep', '61ec6c3d-577e-476f-8f74-5b237acb3a52'),
  'recall': ('Handy Recall', '185092f7-d4a1-424e-9072-689a276a6c36'),
  'bookmark': ('Handy Bookmark', 'e251877b-f2ba-45df-b7be-9bb83712762d'),
  'spend': ('Handy Spend', 'd6b89aff-1305-4577-82a4-921914b30ac6'),
  'habit': ('Handy Habit', '86a06fbe-6153-41c1-b230-c73b7a0640ef'),
};

WindowsInitializationSettings? windowsIdentity(String app) {
  final id = _windowsIds[app];
  if (id == null) return null;
  return WindowsInitializationSettings(
    appName: id.$1,
    appUserModelId: 'HandySuite.${id.$1.split(' ').last}',
    guid: id.$2,
  );
}

Future<tz.Location> deviceLocation() async {
  data.initializeTimeZones();
  final zone = await FlutterTimezone.getLocalTimezone();
  return resolveZone(zone.identifier, DateTime.now().timeZoneOffset);
}

/// Old names some systems still report (Windows says `Asia/Saigon`).
const _renamed = {
  'Asia/Saigon': 'Asia/Ho_Chi_Minh',
  'Asia/Calcutta': 'Asia/Kolkata',
  'Asia/Katmandu': 'Asia/Kathmandu',
  'Asia/Rangoon': 'Asia/Yangon',
  'Asia/Ulan_Bator': 'Asia/Ulaanbaatar',
  'Asia/Dacca': 'Asia/Dhaka',
  'Asia/Thimbu': 'Asia/Thimphu',
  'Europe/Kiev': 'Europe/Kyiv',
  'America/Buenos_Aires': 'America/Argentina/Buenos_Aires',
  'Pacific/Enderbury': 'Pacific/Kanton',
};

/// The zone named [name]; its current name if renamed; otherwise a zone
/// that keeps the device's present offset, so reminders still land at the
/// right local time.
tz.Location resolveZone(String name, Duration offset) {
  for (final candidate in [name, ?_renamed[name]]) {
    try {
      return tz.getLocation(candidate);
    } on tz.LocationNotFoundException {
      continue;
    }
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  for (final l in tz.timeZoneDatabase.locations.values) {
    if (l.timeZone(now).offset == offset) return l;
  }
  return tz.UTC;
}

class DeviceNotifications implements NotificationsPort {
  /// Identifies the app to Windows (its name on toasts, an AppUserModelID
  /// and a GUID of its own); without it Windows keeps the in-app list.
  final WindowsInitializationSettings? windows;
  DeviceNotifications({this.windows});
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? initialized;
  Future<void> ready() => initialized ??= () async {
    if (!supportsLocalReminders ||
        defaultTargetPlatform == TargetPlatform.windows && windows == null)
      throw UnsupportedError(
        'Notifications not verified on this platform. Use the in-app due list.',
      );
    await plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        windows: windows,
      ),
    );
  }();
  @override
  Future<bool> allowed(bool request) async {
    await ready();
    // Windows has no runtime permission; the user turns toasts off in
    // Settings, which the app cannot read.
    if (defaultTargetPlatform == TargetPlatform.windows) return true;
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

  bool get _windows => defaultTargetPlatform == TargetPlatform.windows;

  /// Windows lists pending toasts by id only, so what each one is for is
  /// kept beside it on the device.
  String _mirrorKey(String namespace) => 'handy-$namespace-windows-toasts-v1';
  Future<Map<String, String>> _mirror(String namespace) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _mirrorKey(namespace),
      );
      final value = raw == null ? null : jsonDecode(raw);
      return value is Map ? value.cast<String, String>() : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _remember(String namespace, Map<String, String> m) async =>
      (await SharedPreferences.getInstance()).setString(
        _mirrorKey(namespace),
        jsonEncode(m),
      );

  @override
  Future<Map<int, String>> pending(String namespace) async {
    await ready();
    final result = <int, String>{};
    if (_windows) {
      final live = {
        for (final r in await plugin.pendingNotificationRequests()) r.id,
      };
      final mirror = await _mirror(namespace)
        ..removeWhere((id, _) => !live.contains(int.tryParse(id)));
      await _remember(namespace, mirror);
      return {for (final e in mirror.entries) int.parse(e.key): e.value};
    }
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
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: r.daily ? DateTimeComponents.time : null,
      payload: jsonEncode({'namespace': namespace, 'signature': r.signature}),
    );
    if (_windows)
      await _remember(
        namespace,
        await _mirror(namespace)
          ..['${r.id}'] = r.signature,
      );
  }

  @override
  Future<void> cancel(int id) async {
    await ready();
    await plugin.cancel(id: id);
    if (_windows)
      for (final namespace in _windowsIds.keys) {
        final mirror = await _mirror(namespace);
        if (mirror.remove('$id') != null) await _remember(namespace, mirror);
      }
  }
}
