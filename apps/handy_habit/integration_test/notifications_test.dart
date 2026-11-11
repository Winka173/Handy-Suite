import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_habit/reminders.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/data/store_native.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('OS notification denied/granted, cap, generic body and cancel', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Handy Habit reminder QA'))),
    );
    await tester.pumpAndSettle();
    const granted = bool.fromEnvironment('EXPECTED_NOTIFICATIONS');
    final reminders = HabitReminders();
    await reminders.port.ready();
    expect(await reminders.port.allowed(false), granted);
    await reminders.port.plugin.cancelAll();
    final today = localDay(DateTime.now(), 'Asia/Ho_Chi_Minh');
    final state = HabitState(
      habits: [
        Habit(
          id: 'h',
          title: 'Private habit',
          created: today,
          schedules: [Schedule(id: 'v', from: today)],
        ),
      ],
      settings: {
        'zone': 'Asia/Ho_Chi_Minh',
        'notifications': true,
        'reminders': List.generate(
          3,
          (i) => Reminder(
            id: 'r$i',
            target: 'h',
            type: 'habit',
            time: '09:00',
          ).toJson(),
        ),
      },
    );
    try {
      await reminders.sync(state);
      final requests = await reminders.port.plugin
          .pendingNotificationRequests();
      expect(requests, hasLength(granted ? 50 : 0));
      expect(
        requests.every(
          (r) =>
              r.title == 'Handy Habit' && !(r.body ?? '').contains('Private'),
        ),
        isTrue,
      );
      await reminders.sync(
        state.copy({
          'settings': {...state.settings, 'notifications': false},
        }),
      );
      expect(
        await reminders.port.plugin.pendingNotificationRequests(),
        isEmpty,
      );
      if (!granted) {
        final dir = (await tester.runAsync(getApplicationSupportDirectory))!;
        final c = HabitController(
          open: () async =>
              NativeHabitStore('${dir.path}/habit-permission-qa.sqlite'),
        );
        await tester.runAsync(c.load);
        await tester.runAsync(
          () => c.change(
            (_) => state.copy({
              'settings': {
                ...state.settings,
                'notifications': false,
                'onboarded': true,
                'locale': 'en',
              },
            }),
          ),
        );
        await tester.pumpWidget(HabitApp(controller: c));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('open-settings')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('settings-notifications')));
        await tester.pumpAndSettle();
        final revision = c.state!.revision;
        await tester.tap(find.byKey(const Key('set-notifications')));
        for (var i = 0; i < 100 && c.state!.revision == revision; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(c.state!.settings['notifications'], isFalse);
        expect(
          find.textContaining('Notifications are off for Handy Habit'),
          findsOneWidget,
        );
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('habit-native-notifications-denied');
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      }
      if (granted) {
        const id = 1909876542;
        await reminders.port.plugin.show(
          id: id,
          title: 'Handy Habit QA',
          body: 'Local test only',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('handy-habit-qa', 'Habit QA'),
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
      }
    } finally {
      await reminders.port.plugin.cancelAll();
    }
  });
}
