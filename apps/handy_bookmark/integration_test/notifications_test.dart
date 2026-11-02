import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:handy_bookmark/services/reminders.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real Save permission, 50 reminder cap, native delivery and cancel',
    (tester) async {
      const expected = bool.fromEnvironment('EXPECTED_NOTIFICATIONS');
      final reminders = SaveReminders();
      await reminders.initialize((_) {});
      expect(await reminders.permissions.allowed(false), expected);
      await reminders.cancelAll();
      final now = DateTime.now().toUtc();
      final bookmarks = List.generate(
        52,
        (i) => Bookmark(
          id: 'notification-qa-$i',
          originalUrl: 'https://example.org/reminder-$i',
          normalizedUrl: 'https://example.org/reminder-$i',
          platform: 'web',
          contentType: 'link',
          title: 'Private title must not be in notification',
          sourceDomain: 'example.org',
          savedAt: now.toIso8601String(),
          updatedAt: now.toIso8601String(),
          reminderAt: now.add(Duration(minutes: i + 10)).toIso8601String(),
        ),
      );
      try {
        await reminders.sync(bookmarks, enabled: true, vietnamese: false);
        final pending = await reminders.permissions.plugin
            .pendingNotificationRequests();
        expect(pending, hasLength(expected ? 50 : 0));
        if (!expected) return;
        expect(
          pending.every(
            (n) =>
                n.title == 'Handy Bookmark' &&
                n.body == 'A saved link is due for review' &&
                n.payload!.startsWith('notification-qa-'),
          ),
          isTrue,
        );
        await reminders.sync([], enabled: false, vietnamese: false);
        expect(
          await reminders.permissions.plugin.pendingNotificationRequests(),
          isEmpty,
        );
        const immediate = 1909876542;
        await reminders.permissions.plugin.show(
          id: immediate,
          title: 'Handy Bookmark QA',
          body: 'Local test only',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('handy-save-qa', 'Save QA'),
          ),
        );
        var visible = false;
        for (var i = 0; i < 30; i++) {
          if ((await reminders.permissions.plugin.getActiveNotifications()).any(
            (n) => n.id == immediate,
          )) {
            visible = true;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(
          visible,
          isTrue,
          reason: 'OS must report actual notification delivery',
        );
      } finally {
        await reminders.cancelAll();
      }
      expect(
        await reminders.permissions.plugin.pendingNotificationRequests(),
        isEmpty,
      );
    },
  );
}
