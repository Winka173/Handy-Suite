import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_notifications/native.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:handy_ui/handy_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native notification permission, pending schedule, delivery and cancel',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Local notification integration')),
        ),
      );
      await tester.pumpAndSettle();
      const expected = bool.fromEnvironment('EXPECTED_NOTIFICATIONS');
      final port = DeviceNotifications();
      expect(await port.allowed(false), expected);
      if (!expected) return;
      final location = await deviceLocation(), now = DateTime.now();
      final request = ReminderRequest(
        'keep:integration-native-permission',
        tz.TZDateTime.from(now.add(const Duration(minutes: 5)), location),
      );
      final old = await port.pending('keep');
      expect(old.containsKey(request.id), isFalse);
      const immediateId = 1909876543;
      try {
        await port.schedule('keep', request);
        final pending = await port.pending('keep');
        expect(pending[request.id], request.signature);
        for (final entry in old.entries) {
          expect(pending[entry.key], entry.value);
        }
        await port.plugin.show(
          id: immediateId,
          title: 'Handy Suite integration',
          body: 'Local permission fixture',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'handy-local-test',
              'Local test reminders',
            ),
          ),
        );
        var visible = false;
        for (var i = 0; i < 20; i++) {
          final active = await port.plugin.getActiveNotifications();
          if (active.any((n) => n.id == immediateId)) {
            visible = true;
            break;
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          visible,
          isTrue,
          reason: 'OS must report the posted native notification as active',
        );
      } finally {
        await port.cancel(request.id);
        await port.cancel(immediateId);
      }
      expect((await port.pending('keep')).containsKey(request.id), isFalse);
    },
  );
}
