import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import 'package:handy_notifications/handy_notifications.dart';
import 'package:handy_notifications/native.dart';

class Port implements NotificationsPort {
  bool grant = true, fail = false;
  final old = <int, String>{}, scheduled = <ReminderRequest>[];
  final canceled = <int>[];
  bool asked = false;
  @override
  Future<bool> allowed(bool request) async {
    asked = request;
    return grant;
  }

  @override
  Future<Map<int, String>> pending(String ns) async => Map.of(old);
  @override
  Future<void> schedule(String ns, ReminderRequest r) async {
    if (fail) throw StateError('OS refused schedule');
    scheduled.add(r);
    old[r.id] = r.signature;
  }

  @override
  Future<void> cancel(int id) async {
    canceled.add(id);
    old.remove(id);
  }
}

void main() {
  setUpAll(data.initializeTimeZones);
  test(
    'Keep dates are scheduled at chosen local time and ignore past dates',
    () {
      final zone = tz.getLocation('Asia/Ho_Chi_Minh');
      final plan = planReminders(
        'keep',
        [
          const ReminderDate('item-warranty', '2026-11-01'),
          const ReminderDate('old', '2026-01-01'),
        ],
        location: zone,
        now: DateTime.utc(2026, 10, 31),
        hour: 9,
        minute: 15,
      );
      expect(plan.length, 1);
      expect(plan.single.when.hour, 9);
      expect(plan.single.when.minute, 15);
      expect(plan.single.when.toUtc().hour, 2);
    },
  );
  test(
    'daily review tomorrow respects DST transition instead of adding 24 UTC hours',
    () {
      final zone = tz.getLocation('America/New_York');
      final now = tz.TZDateTime(zone, 2026, 3, 7, 12);
      final plan = planReminders(
        'recall',
        [],
        location: zone,
        now: now,
        hour: 9,
        minute: 0,
        dailyReview: true,
      );
      expect(plan.single.when.day, 8);
      expect(plan.single.when.hour, 9);
      expect(plan.single.when.timeZoneOffset, const Duration(hours: -4));
    },
  );
  test('invalid calendar date and reminder time rejected', () {
    final zone = tz.UTC;
    expect(
      () => planReminders(
        'keep',
        [const ReminderDate('x', '2026-02-30')],
        location: zone,
        now: DateTime.utc(2026),
        hour: 9,
        minute: 0,
      ),
      throwsFormatException,
    );
    expect(
      () => planReminders(
        'recall',
        [],
        location: zone,
        now: DateTime.utc(2026),
        hour: 24,
        minute: 0,
      ),
      throwsFormatException,
    );
  });
  test('plans bounded to 50 OS requests and duplicate identities rejected', () {
    final dates = List.generate(
      70,
      (i) => ReminderDate('item-$i', '2026-12-01'),
    );
    expect(
      planReminders(
        'keep',
        dates,
        location: tz.UTC,
        now: DateTime.utc(2026),
        hour: 9,
        minute: 0,
      ).length,
      50,
    );
    expect(
      () => planReminders(
        'keep',
        [
          const ReminderDate('x', '2026-12-01'),
          const ReminderDate('x', '2026-12-01'),
        ],
        location: tz.UTC,
        now: DateTime.utc(2026),
        hour: 9,
        minute: 0,
      ),
      throwsFormatException,
    );
  });
  test(
    'denied permission reports failure without claiming registration',
    () async {
      final port = Port()..grant = false;
      final plan = planReminders(
        'recall',
        [],
        location: tz.UTC,
        now: DateTime.utc(2026),
        hour: 9,
        minute: 0,
        dailyReview: true,
      );
      await expectLater(
        reconcileNotifications(
          port,
          'recall',
          plan,
          enabled: true,
          askPermission: true,
        ),
        throwsStateError,
      );
      expect(port.asked, true);
      expect(port.scheduled, isEmpty);
    },
  );
  test(
    'reconciliation is idempotent and cancels stale plans on restore/delete',
    () async {
      final port = Port();
      final plan = planReminders(
        'recall',
        [],
        location: tz.UTC,
        now: DateTime.utc(2026),
        hour: 9,
        minute: 0,
        dailyReview: true,
      );
      expect(
        await reconcileNotifications(port, 'recall', plan, enabled: true),
        1,
      );
      expect(
        await reconcileNotifications(port, 'recall', plan, enabled: true),
        1,
      );
      expect(port.scheduled.length, 1);
      await reconcileNotifications(port, 'recall', [], enabled: true);
      expect(port.canceled, [plan.single.id]);
    },
  );
  test('disable cancels owned requests without asking permission', () async {
    final port = Port()..grant = false;
    port.old[1] = 'old';
    expect(await reconcileNotifications(port, 'keep', [], enabled: false), 0);
    expect(port.canceled, [1]);
    expect(port.asked, false);
  });
  test('OS scheduling errors propagate and cannot become success', () async {
    final port = Port()..fail = true;
    final plan = planReminders(
      'recall',
      [],
      location: tz.UTC,
      now: DateTime.utc(2026),
      hour: 9,
      minute: 0,
      dailyReview: true,
    );
    await expectLater(
      reconcileNotifications(port, 'recall', plan, enabled: true),
      throwsStateError,
    );
    expect(port.scheduled, isEmpty);
  });

  test('a daily review becomes dated copies where toasts cannot repeat', () {
    data.initializeTimeZones();
    final hcm = tz.getLocation('Asia/Ho_Chi_Minh');
    final plan = planReminders(
      'recall',
      const [],
      location: hcm,
      now: DateTime.utc(2026, 11, 2, 1),
      hour: 20,
      minute: 0,
      dailyReview: true,
      dailyCopies: 14,
    );
    expect(plan, hasLength(14));
    expect(plan.every((r) => !r.daily), isTrue);
    expect(plan.first.key, 'recall:daily-review:2026-11-02');
    expect(plan.last.key, 'recall:daily-review:2026-11-15');
    expect(plan.map((r) => r.id).toSet(), hasLength(14));
  });

  test('old zone names from the system still resolve', () {
    data.initializeTimeZones();
    expect(
      resolveZone('Asia/Saigon', const Duration(hours: 7)).name,
      'Asia/Ho_Chi_Minh',
    );
    expect(
      resolveZone(
        'Nowhere/Made_Up',
        const Duration(hours: 7),
      ).timeZone(DateTime.now().millisecondsSinceEpoch).offset,
      const Duration(hours: 7),
    );
  });
}
