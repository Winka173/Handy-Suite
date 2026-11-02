import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'handy_notifications.dart';
import 'native.dart';

/// Where the on/off switch and the reminder time are kept.
abstract interface class ReminderSettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class _DeviceSettings implements ReminderSettingsStore {
  final _prefs = SharedPreferencesAsync();
  @override
  Future<String?> read(String key) => _prefs.getString(key);
  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
}

/// Keeps the OS schedule in step with an app's due dates. Views only read
/// [enabled], [hour], [minute], [busy] and [message] and call [setEnabled] or
/// [setTime]; the app calls [update] whenever its dates change.
class ReminderController extends ChangeNotifier {
  final String namespace;
  final bool dailyReview;
  final NotificationsPort port;
  final ReminderSettingsStore store;
  final Future<tz.Location> Function() location;
  ReminderController(
    this.namespace, {
    this.dailyReview = false,
    NotificationsPort? port,
    ReminderSettingsStore? store,
    Future<tz.Location> Function()? location,
  }) : port = port ?? DeviceNotifications(windows: windowsIdentity(namespace)),
       store = store ?? _DeviceSettings(),
       location = location ?? deviceLocation;

  bool? enabled;
  bool busy = false;
  int hour = 9, minute = 0, registered = 0;

  /// The last failure, as text; empty when the last sync succeeded.
  String message = '';
  List<ReminderDate> _dates = const [];
  Future<void> _pending = Future.value();
  bool _disposed = false;
  String get _key => 'handy-$namespace-notifications-v1';
  String _signature(List<ReminderDate> d) =>
      d.map((r) => '${r.key}:${r.date}').join('|');

  Future<void> load() async {
    try {
      final raw = await store.read(_key);
      final parsed = raw == null ? null : jsonDecode(raw);
      if (parsed != null &&
          (parsed is! Map ||
              parsed['enabled'] is! bool ||
              parsed['hour'] is! int ||
              parsed['minute'] is! int ||
              parsed['hour'] < 0 ||
              parsed['hour'] > 23 ||
              parsed['minute'] < 0 ||
              parsed['minute'] > 59)) {
        throw const FormatException('Invalid reminder settings');
      }
      enabled = parsed?['enabled'] ?? false;
      hour = parsed?['hour'] ?? 9;
      minute = parsed?['minute'] ?? 0;
      _notify();
      if (enabled == true) await _sync(true);
    } catch (e) {
      message = '$e';
      _notify();
    }
  }

  /// New due dates from the app; reschedules only when they changed.
  Future<void> update(List<ReminderDate> dates) {
    final changed = _signature(dates) != _signature(_dates);
    _dates = List.unmodifiable(dates);
    return changed && enabled == true ? _sync(true) : Future.value();
  }

  Future<void> setEnabled(bool value) => _sync(value, request: value);

  Future<void> setTime(int h, int m) {
    hour = h;
    minute = m;
    _notify();
    return enabled == true ? _sync(true) : _save(false);
  }

  /// Called when the app returns to the foreground.
  Future<void> resume() => enabled == true ? _sync(true) : Future.value();

  Future<void> _save(bool active) => store.write(
    _key,
    jsonEncode({'enabled': active, 'hour': hour, 'minute': minute}),
  );

  Future<void> _sync(bool active, {bool request = false}) {
    final dates = _dates, h = hour, m = minute;
    return _pending = _pending.catchError((_) {}).then((_) async {
      if (_disposed) return;
      busy = true;
      _notify();
      try {
        final plan = planReminders(
          namespace,
          dates,
          location: await location(),
          now: DateTime.now(),
          hour: h,
          minute: m,
          dailyReview: dailyReview,
          dailyCopies: dailyCopies,
        );
        registered = await reconcileNotifications(
          port,
          namespace,
          plan,
          enabled: active,
          askPermission: request,
        );
        await _save(active);
        enabled = active;
        message = '';
      } catch (e) {
        message = '$e';
      } finally {
        busy = false;
        _notify();
      }
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
