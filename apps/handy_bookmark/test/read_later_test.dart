import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/services/problem_notices.dart';
import 'package:handy_bookmark/services/read_later.dart';
import 'package:handy_bookmark/services/reminders.dart';
import 'package:handy_ui/kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/services/share_inbox.dart';
import 'controller_test.dart' show TestInbox, TestStore;
import 'new_flows_test.dart' show boot, idOf;
import 'widget_test.dart' show tapKey;

void main() {
  group('choices', () {
    test('tonight only before 19:30; tomorrow 09:00; the coming Saturday', () {
      // Monday 10 Nov 2026, 08:00.
      final morning = readLaterChoices(DateTime(2026, 11, 9, 8));
      expect(morning.map((c) => (c.id, c.at)), [
        ('tonight', DateTime(2026, 11, 9, 20)),
        ('tomorrow', DateTime(2026, 11, 10, 9)),
        ('weekend', DateTime(2026, 11, 14, 9)),
      ]);
      final late = readLaterChoices(DateTime(2026, 11, 9, 19, 45));
      expect(late.map((c) => c.id), ['tomorrow', 'weekend']);
      // Saturday before 09:00 is today; after it, the next Saturday.
      expect(
        readLaterChoices(DateTime(2026, 11, 14, 7)).last.at,
        DateTime(2026, 11, 14, 9),
      );
      expect(
        readLaterChoices(DateTime(2026, 11, 14, 10)).last.at,
        DateTime(2026, 11, 21, 9),
      );
      // Sunday: next Saturday.
      expect(
        readLaterChoices(DateTime(2026, 11, 15, 10)).last.at,
        DateTime(2026, 11, 21, 9),
      );
    });

    test('a stored time maps back to its choice, else custom; none is off', () {
      final now = DateTime(2026, 11, 9, 8);
      expect(readLaterChoiceOf(null, now), isNull);
      expect(readLaterChoiceOf(DateTime(2026, 11, 10, 9), now), 'tomorrow');
      expect(readLaterChoiceOf(DateTime(2026, 11, 10, 11), now), 'custom');
    });
  });

  group('notification buttons', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('"Mark as read" is written down for the app, once', () async {
      await recordNotifyAction(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 7,
          actionId: readAction,
          payload: reminderPayload('b1', 'Flutter Performance Guide'),
        ),
      );
      final taken = await takeNotifyActions();
      expect(taken.single.id, 'b1');
      expect(taken.single.action, readAction);
      expect(await takeNotifyActions(), isEmpty);
    });

    test('payloads carry the id and title; old bare ids still read', () {
      final p = readPayload(reminderPayload('b1', 'Title'));
      expect((p.id, p.title), ('b1', 'Title'));
      expect(readPayload('b2').id, 'b2');
      expect(jsonDecode(reminderPayload('x', 'a' * 300))['t'], hasLength(120));
    });
  });

  group('needs attention', () {
    test('backup, sync and failed shares; offline is not a problem', () {
      final all = currentProblems(
        vietnamese: true,
        backupError: 'Folder gone',
        syncState: 'authNeeded',
        failedShares: 2,
      );
      expect(all.map((p) => p.kind), ['backup', 'sync', 'shares']);
      expect(all.last.title, '2 link chia sẻ chưa lưu được');
      expect(currentProblems(vietnamese: false, syncState: 'offline'), isEmpty);
      expect(currentProblems(vietnamese: false, syncState: 'idle'), isEmpty);
    });
  });

  test('a reminder picked in the share sheet lands on the bookmark (also a '
      'link saved before), turns reminders on, and its sheet notification '
      'is withdrawn', () async {
    final at = DateTime.now().add(const Duration(days: 1)).toUtc();
    final store = TestStore();
    final inbox = TestInbox()
      ..pending = [
        SharedLink.full(
          's1',
          'https://example.com/read',
          'Read me',
          remindAt: at,
        ),
      ];
    final c = SaveController(open: () async => store, shares: inbox);
    final moved = <String>[];
    c.onShareReminderMoved = (id) async => moved.add(id);
    await c.initialize();
    final b = c.library!.bookmarks.single;
    expect(DateTime.parse(b.reminderAt!), at);
    expect(c.preferences['notifications'], isTrue);
    expect(c.sharedInto['s1'], b.id);
    expect(moved, ['s1']);
    // The sheet re-queued it after the app took the first copy: the same
    // bookmark, filed under the sheet's own id.
    final later = at.add(const Duration(hours: 2));
    inbox.pending = [
      SharedLink.full(
        'requeued',
        'https://example.com/read',
        null,
        remindAt: later,
        origin: 's1',
      ),
    ];
    await c.drain();
    expect(c.library!.bookmarks, hasLength(1));
    expect(DateTime.parse(c.library!.bookmarks.single.reminderAt!), later);
    expect(moved.last, 's1');
    c.dispose();
  });

  testWidgets('Notifications settings: background jobs are off by '
      'default and turn on', (t) async {
    final (c, _) = await boot(t, size: const Size(400, 3200));
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/settings');
    await t.pumpAndSettle();
    final finder = find.byKey(const Key('set-task-notices'));
    if (finder.evaluate().isEmpty) return; // no notifications on this host
    expect(c.preferences['taskNotices'], isNot(true));
    await tapKey(t, 'set-task-notices');
    expect(c.preferences['taskNotices'], isTrue);
  });

  testWidgets('Remind me: off by default; one tap sets tomorrow; Off clears', (
    t,
  ) async {
    final (c, _) = await boot(t);
    final id = idOf(c, 'https://a.com/one');
    Navigator.of(
      t.element(find.byType(Scaffold).first),
    ).pushNamed('/bookmark/$id');
    await t.pumpAndSettle();
    expect(find.text('Remind me · Off'), findsOneWidget);
    await tapKey(t, 'detail-remind');
    expect(find.byKey(const Key('remind-sheet')), findsOneWidget);
    expect(
      find.text('Only this bookmark is reminded. Others are not affected.'),
      findsOneWidget,
    );
    await tapKey(t, 'remind-tomorrow');
    final at = DateTime.parse(
      c.library!.bookmarks.firstWhere((b) => b.id == id).reminderAt!,
    ).toLocal();
    final now = DateTime.now();
    expect(at, DateTime(now.year, now.month, now.day + 1, 9));
    // Other items are untouched.
    expect(
      c.library!.bookmarks.where((b) => b.id != id && b.reminderAt != null),
      isEmpty,
    );
    expect(find.textContaining('Reminder: Tomorrow, 09:00'), findsOneWidget);
    await tapKey(t, 'detail-remind');
    await tapKey(t, 'remind-off');
    expect(
      c.library!.bookmarks.firstWhere((b) => b.id == id).reminderAt,
      isNull,
    );
  });
}
