import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_spend/reminders.dart';
import 'package:handy_spend/privacy.dart';
import 'package:local_auth/local_auth.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual Spend notification deny/grant, 50 schedules, immediate delivery and cancel',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Handy Spend local notification verification'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const expected = bool.fromEnvironment('EXPECTED_NOTIFICATIONS');
      final reminders = SpendReminders();
      await reminders.port.ready();
      expect(await reminders.port.allowed(false), expected);
      await reminders.port.plugin.cancelAll();
      final tomorrow = day(DateTime.now().toUtc().add(const Duration(days: 1))),
          s = SpendState(
            accounts: [
              Account(
                id: 'qa-cash',
                name: 'Private account',
                currency: 'VND',
                opening: BigInt.from(100000),
                asOf: day(DateTime.now().toUtc()),
              ),
            ],
            settings: {'zone': 'UTC', 'notifications': true},
            bills: List.generate(
              52,
              (i) => Bill(
                id: 'bill-$i',
                name: 'Private merchant $i',
                account: 'qa-cash',
                amount: BigInt.from(-100),
                due: tomorrow,
                frequency: 'once',
                remind: true,
              ),
            ),
          );
      try {
        await reminders.sync(s);
        final pending = await reminders.port.plugin
            .pendingNotificationRequests();
        expect(pending, hasLength(expected ? 50 : 0));
        if (!expected) return;
        expect(
          pending.every(
            (n) =>
                n.title == 'Handy Spend' &&
                n.body != null &&
                !n.body!.contains('Private') &&
                !n.body!.contains('100'),
          ),
          isTrue,
        );
        await reminders.sync(
          s.copy({
            'settings': {'zone': 'UTC', 'notifications': false},
          }),
        );
        expect(
          await reminders.port.plugin.pendingNotificationRequests(),
          isEmpty,
        );
        const id = 1909876541;
        await reminders.port.plugin.show(
          id: id,
          title: 'Handy Spend QA',
          body: 'Local test only',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('handy-spend-qa', 'Spend QA'),
          ),
        );
        var visible = false;
        for (var i = 0; i < 30; i++) {
          if ((await reminders.port.plugin.getActiveNotifications()).any(
            (n) => n.id == id,
          )) {
            visible = true;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(visible, isTrue);
      } finally {
        await reminders.port.plugin.cancelAll();
      }
      expect(await LocalAuthentication().isDeviceSupported(), isFalse);
      expect(
        await reminders.port.plugin.pendingNotificationRequests(),
        isEmpty,
      );
    },
  );
  testWidgets(
    'fresh QA emulator refuses app authentication without configured device credentials',
    (tester) async {
      expect(
        await SpendPrivacy().available(),
        isFalse,
        reason:
            'This dedicated fresh QA AVD has no enrolled biometric or device PIN; real successful authentication is not claimed',
      );
    },
  );
}
