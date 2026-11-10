import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/sync/drive_sync.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'drive_sync_test.dart' as sync;
import 'run3_ui_test.dart' as host;
import 'ui_test.dart' show tapKey;

void main() {
  test('Drive gate is Android plus build define only', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(driveSyncOffered, driveSyncBuild);
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(driveSyncOffered, isFalse);
    }
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets(
    'ungated Settings has no Sync row and offers honest backup guidance',
    (t) async {
      await host.boot(t);
      await host.go(t, '/settings');
      expect(find.byKey(const Key('habit-sync')), findsNothing);
      await t.scrollUntilVisible(find.byKey(const Key('habit-backup')), 500);
      expect(
        find.textContaining('Use backup to move data between platforms.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Sync route supports enable, status, Sync now, turn off and back',
    (t) async {
      final c = await sync.device(sync.seeded()),
          remote = MemoryHabitSyncProvider(),
          d = sync.drive(c, remote);
      await d.initialize();
      await t.pumpWidget(HabitApp(controller: c, device: false, driveSync: d));
      await t.pumpAndSettle();
      await host.go(t, '/settings');
      await tapKey(t, 'habit-sync');
      expect(host.route(t), '/settings/sync');
      expect(find.text('Sync is off'), findsWidgets);
      await tapKey(t, 'sync-primary');
      expect(d.state, DriveSyncState.synced);
      expect(find.text('In sync'), findsOneWidget);
      await tapKey(t, 'sync-primary');
      await tapKey(t, 'sync-off');
      expect(d.enabled, isFalse);
      host.nav(t).pop();
      await t.pumpAndSettle();
      expect(host.route(t), '/settings');
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'mood conflict choices retain both notes and resolve explicitly',
    (t) async {
      final s = prepareHabitSync(sync.seeded());
      HabitState mood(String actor, int v, String note) => recordChange(
        s,
        saveMood(
          s,
          sync.today,
          v,
          now: sync.now,
          expectedRevision: 0,
          note: note,
        ),
        actor: actor,
      );
      final m = mergeHabitStates(
        mood('a', 2, 'Quiet morning'),
        mood('b', 5, 'Good walk'),
      );
      final c = await sync.device(m),
          d = sync.drive(c, MemoryHabitSyncProvider());
      await d.initialize();
      await t.pumpWidget(HabitApp(controller: c, device: false, driveSync: d));
      await t.pumpAndSettle();
      await host.go(t, '/settings/sync');
      final choice = moodSyncConflicts(
        m,
      ).values.single.firstWhere((o) => o.after!['mood'] == 5);
      await t.ensureVisible(find.byKey(Key('resolve-mood-${choice.id}')));
      await t.pumpAndSettle();
      expect(find.textContaining('Quiet morning'), findsOneWidget);
      expect(find.textContaining('Good walk'), findsOneWidget);
      await t.tap(find.byKey(Key('resolve-mood-${choice.id}')));
      await t.pumpAndSettle();
      expect(moodSyncConflicts(c.state!), isEmpty);
      expect(moodOn(c.state!, sync.today)!.mood, 5);
      await t.pumpWidget(const SizedBox());
    },
  );
}
