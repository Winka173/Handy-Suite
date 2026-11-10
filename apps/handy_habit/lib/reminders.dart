import 'package:flutter/foundation.dart';
import 'package:handy_notifications/native.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings/system_settings.dart';
import 'run_notice.dart';

enum HabitPermission { allowed, denied, unreadable, unsupported, error }

class ReminderDiagnostics {
  final HabitPermission permission;
  final bool? exactAllowed, batteryExempt;
  final DateTime? lastScheduled, nextScheduled;
  final int scheduled;
  final bool failed;
  const ReminderDiagnostics({
    required this.permission,
    this.exactAllowed,
    this.batteryExempt,
    this.lastScheduled,
    this.nextScheduled,
    this.scheduled = 0,
    this.failed = false,
  });
}

class HabitReminders {
  final DeviceNotifications port;
  HabitReminders({DeviceNotifications? port})
    : port = port ?? DeviceNotifications(windows: windowsIdentity('habit'));
  bool get supported => supportsLocalReminders;
  Future<bool> request() =>
      supported ? port.allowed(true) : Future.value(false);
  Future<bool> permission() =>
      supported ? port.allowed(false) : Future.value(false);
  static const testId = 0x48616268;
  static const _last = 'habit-reminders-last-scheduled-v1',
      _next = 'habit-reminders-next-v1',
      _count = 'habit-reminders-count-v1',
      _failed = 'habit-reminders-failed-v1';
  Future<ReminderDiagnostics> diagnostics() async {
    if (!supported)
      return const ReminderDiagnostics(permission: HabitPermission.unsupported);
    var p = HabitPermission.error;
    try {
      p = await permission() ? HabitPermission.allowed : HabitPermission.denied;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
        p = HabitPermission.unreadable;
    } catch (_) {}
    final os = await habitSystemStatus();
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    return ReminderDiagnostics(
      permission: p,
      exactAllowed: os.exactAllowed,
      batteryExempt: os.batteryExempt,
      lastScheduled: DateTime.tryParse(prefs?.getString(_last) ?? ''),
      nextScheduled: DateTime.tryParse(prefs?.getString(_next) ?? ''),
      scheduled: prefs?.getInt(_count) ?? 0,
      failed: prefs?.getBool(_failed) ?? false,
    );
  }

  Future<void> test(HabitState state) async {
    if (!supported || !await permission())
      throw const FormatException(
        'Enable notifications first / Hãy cho phép thông báo trước',
      );
    await port.plugin.show(
      id: testId,
      title: 'Handy Habit',
      body: _reminderVi(state)
          ? 'Thông báo thử của bạn.'
          : 'Your test notification.',
      notificationDetails: _details,
    );
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'handy-habit-reminders',
      'Local reminders',
      importance: Importance.defaultImportance,
      visibility: NotificationVisibility.private,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: false),
    windows: WindowsNotificationDetails(),
  );
  Future<void> _queue = Future.value();
  Future<void> sync(HabitState state) {
    final next = _queue.catchError((Object _) {}).then((_) async {
      if (!supported) return;
      try {
        await port.ready();
        final planned =
            state.settings['notifications'] == true && await port.allowed(false)
            ? dueReminders(state, DateTime.now())
            : <DueReminder>[];
        final desired = {
          for (final r in planned)
            ReminderRequest('habit:${r.key}', r.when).id: r,
        };
        if (desired.length != planned.length ||
            desired.containsKey(DeviceRunNoticePort.id) ||
            desired.containsKey(testId))
          throw StateError('Reminder ID collision');
        for (final old in await port.plugin.pendingNotificationRequests()) {
          if (old.id == DeviceRunNoticePort.id || old.id == testId) continue;
          if (!desired.containsKey(old.id))
            await port.plugin.cancel(id: old.id);
        }
        for (final entry in desired.entries) {
          await port.plugin.zonedSchedule(
            id: entry.key,
            title: 'Handy Habit',
            body: reminderBody(state, entry.value),
            scheduledDate: entry.value.when,
            notificationDetails: _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: entry.value.key,
          );
        }
        final prefs = await SharedPreferences.getInstance();
        if (planned.isNotEmpty)
          await prefs.setString(
            _last,
            DateTime.now().toUtc().toIso8601String(),
          );
        await prefs.setInt(_count, planned.length);
        if (planned.isEmpty) {
          await prefs.remove(_next);
        } else {
          await prefs.setString(
            _next,
            planned.first.when.toUtc().toIso8601String(),
          );
        }
        await prefs.setBool(_failed, false);
      } catch (_) {
        try {
          await (await SharedPreferences.getInstance()).setBool(_failed, true);
        } catch (_) {}
        rethrow;
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
