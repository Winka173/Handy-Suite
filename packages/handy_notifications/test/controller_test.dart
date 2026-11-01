import 'package:flutter_test/flutter_test.dart';
import 'package:handy_notifications/controller.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import 'reminders_test.dart' show Port;

class Settings implements ReminderSettingsStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

String inDays(int days) =>
    DateTime.now().add(Duration(days: days)).toIso8601String().substring(0, 10);

void main() {
  setUpAll(data.initializeTimeZones);
  ReminderController make(Port port, Settings settings) => ReminderController(
    'keep',
    port: port,
    store: settings,
    location: () async => tz.getLocation('Asia/Ho_Chi_Minh'),
  );

  test('denied permission leaves reminders off and says why', () async {
    final port = Port()..grant = false;
    final c = make(port, Settings());
    await c.load();
    await c.update([ReminderDate('a-warranty', inDays(3))]);
    await c.setEnabled(true);
    expect(c.enabled, isFalse);
    expect(c.message, contains('permission'));
    expect(port.scheduled, isEmpty);
  });

  test('changed dates reschedule; the chosen time survives a reload', () async {
    final port = Port(), settings = Settings();
    final c = make(port, settings);
    await c.load();
    await c.update([ReminderDate('a-warranty', inDays(3))]);
    await c.setEnabled(true);
    expect((c.enabled, c.registered), (true, 1));
    await c.update([
      ReminderDate('a-warranty', inDays(3)),
      ReminderDate('b-loan', inDays(5)),
    ]);
    expect(port.scheduled.length, 2);
    await c.setTime(20, 30);
    expect(port.scheduled.last.when.hour, 20);
    final again = make(port, settings);
    await again.load();
    expect((again.enabled, again.hour, again.minute), (true, 20, 30));
  });

  test('turning off cancels everything already registered', () async {
    final port = Port();
    final c = make(port, Settings());
    await c.load();
    await c.update([ReminderDate('a-warranty', inDays(3))]);
    await c.setEnabled(true);
    await c.setEnabled(false);
    expect(port.old, isEmpty);
    expect(c.enabled, isFalse);
  });
}
