import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_notifications/native.dart';

/// What the notice for a paused run says.
class RunNotice {
  final String session, title, body;
  const RunNotice(this.session, this.title, this.body);
}

/// The system side of the notice: shown, cancelled, tapped.
abstract interface class RunNoticePort {
  bool get supported;

  /// Whether notifications are allowed now; never asks.
  Future<bool> allowed();
  Future<void> show(RunNotice notice);
  Future<void> cancel();

  /// Starts listening for taps; returns the run whose notice opened the
  /// app, if one did.
  Future<String?> listen(void Function(String session) onOpen);
}

/// The notice shown while a routine run is paused in the background. The
/// runner still pauses when the app leaves the screen, so the notice says
/// so and shows the time left; it never counts down.
class HabitRunNotices {
  final RunNoticePort port;
  HabitRunNotices({RunNoticePort? port})
    : port =
          port ??
          DeviceRunNoticePort(
            DeviceNotifications(windows: windowsIdentity('habit')),
          );
  bool _shown = false;
  Future<void> _queue = Future.value();

  /// Shown only if the settings, the permission (checked, never asked for)
  /// and the quiet hours allow it. Returns whether it was shown.
  Future<bool> show(HabitState s, RunNotice notice, DateTime now) {
    final done = Completer<bool>();
    _queue = _queue.catchError((Object _) {}).then((_) async {
      try {
        if (!port.supported ||
            !runNoticeAllowed(s, now) ||
            !await port.allowed()) {
          done.complete(false);
          return;
        }
        await port.show(
          s.settings['privateNotifications'] != false
              ? RunNotice(notice.session, 'Handy Habit', notice.body)
              : notice,
        );
        _shown = true;
        done.complete(true);
      } catch (_) {
        done.complete(false);
      }
    });
    return done.future;
  }

  /// Takes the notice away (back in the app, finished, stopped).
  Future<void> clear({bool always = false}) {
    if (!port.supported || !_shown && !always) return Future.value();
    _shown = false;
    return _queue = _queue.catchError((Object _) {}).then((_) async {
      try {
        await port.cancel();
      } catch (_) {}
    });
  }

  /// At start: listen for taps, clear a notice left from a closed app,
  /// and return the run whose notice opened the app.
  Future<String?> start(void Function(String session) onOpen) async {
    if (!port.supported) return null;
    try {
      final launched = await port.listen(onOpen);
      await clear(always: true);
      return launched;
    } catch (_) {
      return null;
    }
  }
}

const _payload = 'run:';

/// The run notice through flutter_local_notifications, on the plugin the
/// reminders already use.
class DeviceRunNoticePort implements RunNoticePort {
  final DeviceNotifications notifications;
  DeviceRunNoticePort(this.notifications);

  /// Its own fixed ID; reminder IDs are FNV hashes of `habit:<rule>:<day>`.
  static const id = 0x48616269;

  @override
  bool get supported => supportsLocalReminders;

  @override
  Future<bool> allowed() => notifications.allowed(false);

  @override
  Future<void> show(RunNotice n) async {
    await notifications.ready();
    await notifications.plugin.show(
      id: id,
      title: n.title,
      body: n.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'handy-habit-run',
          'Routine in progress',
          channelDescription: 'A routine paused when you left the app',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          silent: true,
          showWhen: false,
          category: AndroidNotificationCategory.status,
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: false,
          presentList: true,
          presentSound: false,
          presentBadge: false,
          interruptionLevel: InterruptionLevel.passive,
        ),
        windows: WindowsNotificationDetails(),
      ),
      payload: '$_payload${n.session}',
    );
  }

  @override
  Future<void> cancel() async {
    await notifications.ready();
    await notifications.plugin.cancel(id: id);
  }

  @override
  Future<String?> listen(void Function(String session) onOpen) async {
    await notifications.ready();
    String? session(String? payload) =>
        payload != null && payload.startsWith(_payload)
        ? payload.substring(_payload.length)
        : null;
    // The same settings the reminders initialise with, plus the tap.
    await notifications.plugin.initialize(
      settings: InitializationSettings(
        windows: notifications.windows,
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final id = session(r.payload);
        if (id != null) onOpen(id);
      },
    );
    final launch = await notifications.plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? session(launch!.notificationResponse?.payload)
        : null;
  }
}
