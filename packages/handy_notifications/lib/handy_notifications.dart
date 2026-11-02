import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;

class ReminderDate {
  final String key;
  final String date;
  const ReminderDate(this.key, this.date);
}

class ReminderRequest {
  final String key;
  final tz.TZDateTime when;
  final bool daily;
  const ReminderRequest(this.key, this.when, {this.daily = false});
  int get id {
    var hash = 2166136261;
    for (final b in utf8.encode(key)) {
      hash = ((hash ^ b) * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  String get signature =>
      '$key:${when.toIso8601String()}:${when.location.name}:$daily';
}

List<ReminderRequest> planReminders(
  String namespace,
  List<ReminderDate> dates, {
  required tz.Location location,
  required DateTime now,
  required int hour,
  required int minute,
  bool dailyReview = false,

  /// Above 1, the daily review becomes that many dated one-off reminders
  /// (for platforms whose notifications cannot repeat).
  int dailyCopies = 1,
}) {
  if (!['keep', 'recall'].contains(namespace) ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59)
    throw const FormatException('Invalid reminder time');
  final local = tz.TZDateTime.from(now, location), result = <ReminderRequest>[];
  if (dailyReview) {
    var next = tz.TZDateTime(
      location,
      local.year,
      local.month,
      local.day,
      hour,
      minute,
    );
    if (!next.isAfter(local))
      next = tz.TZDateTime(
        location,
        local.year,
        local.month,
        local.day + 1,
        hour,
        minute,
      );
    if (dailyCopies <= 1) {
      result.add(ReminderRequest('$namespace:daily-review', next, daily: true));
    } else {
      for (var i = 0; i < dailyCopies; i++) {
        final when = tz.TZDateTime(
          location,
          next.year,
          next.month,
          next.day + i,
          hour,
          minute,
        );
        result.add(
          ReminderRequest(
            '$namespace:daily-review:${when.toIso8601String().substring(0, 10)}',
            when,
          ),
        );
      }
    }
  }
  for (final d in dates) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d.date))
      throw const FormatException('Invalid reminder date');
    final parts = d.date.split('-').map(int.parse).toList();
    final check = DateTime.utc(parts[0], parts[1], parts[2]);
    if (check.toIso8601String().substring(0, 10) != d.date)
      throw const FormatException('Invalid reminder date');
    final when = tz.TZDateTime(
      location,
      parts[0],
      parts[1],
      parts[2],
      hour,
      minute,
    );
    if (when.isAfter(local))
      result.add(ReminderRequest('$namespace:${d.key}', when));
  }
  result.sort((a, b) => a.when.compareTo(b.when));
  final limited = result.take(50).toList();
  if (limited.map((r) => r.id).toSet().length != limited.length)
    throw const FormatException('Conflicting reminder IDs');
  return limited;
}

abstract interface class NotificationsPort {
  Future<bool> allowed(bool request);
  Future<Map<int, String>> pending(String namespace);
  Future<void> schedule(String namespace, ReminderRequest request);
  Future<void> cancel(int id);
}

Future<int> reconcileNotifications(
  NotificationsPort port,
  String namespace,
  List<ReminderRequest> plan, {
  required bool enabled,
  bool askPermission = false,
}) async {
  if (!['keep', 'recall'].contains(namespace) ||
      plan.length > 50 ||
      plan.map((r) => r.id).toSet().length != plan.length ||
      plan.any((r) => !r.key.startsWith('$namespace:')))
    throw const FormatException('Invalid reminder namespace/plan');
  final old = await port.pending(namespace);
  if (!enabled) {
    for (final id in old.keys) {
      await port.cancel(id);
    }
    return 0;
  }
  final desired = {for (final r in plan) r.id: r.signature};
  for (final id in old.keys) {
    if (old[id] != desired[id]) await port.cancel(id);
  }
  if (!await port.allowed(askPermission))
    throw StateError(
      'Notification permission denied / Chưa có quyền thông báo',
    );
  for (final r in plan) {
    if (old[r.id] != r.signature) await port.schedule(namespace, r);
  }
  return plan.length;
}
