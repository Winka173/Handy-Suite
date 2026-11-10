import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/sync/drive_sync.dart';
import 'package:handy_habit/sync/drive_provider.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'ui_test.dart' show MemoryStore;

const today = '2026-11-10';
final now = DateTime.utc(2026, 11, 10, 9);
HabitState seeded() => HabitState(
  habits: [
    Habit(
      id: 'h',
      title: 'Water',
      type: 'count',
      created: today,
      schedules: [Schedule(id: 's', from: today, target: 8000)],
    ),
  ],
  settings: {'onboarded': true},
);
Future<HabitController> device(HabitState s) async {
  final store = MemoryStore()..value = s;
  final c = HabitController(open: () async => store, clock: () => now);
  await c.load();
  addTearDown(c.dispose);
  return c;
}

HabitDriveSync drive(
  HabitController c,
  HabitSyncProvider folder, {
  bool allow = true,
  SyncMetadataStore? metadata,
  Duration delay = const Duration(days: 1),
  Future<void> Function()? revoke,
}) {
  final d = HabitDriveSync(
    c,
    provider: () => folder,
    authorize: () async => allow,
    revoke: revoke ?? () async {},
    account: () => 'habit.test@example.test',
    metadata: metadata ?? MemorySyncMetadata(),
    delay: delay,
  );
  addTearDown(d.dispose);
  return d;
}

Future<void> add(HabitController c, String id) => c.change(
  (s) => record(
    s,
    HabitEvent(
      id: id,
      habit: 'h',
      day: today,
      value: 1000,
      updated: now.toIso8601String(),
    ),
    today: today,
    allowExtra: true,
  ),
);

void main() {
  test(
    'damaged device base refuses auto-sync without rewriting metadata',
    () async {
      final metadata = MemorySyncMetadata()
        ..data = {
          'enabled': true,
          'base': [
            {'invalid': true},
          ],
        };
      final remote = MemoryHabitSyncProvider(),
          a = await device(seeded()),
          d = drive(a, remote, metadata: metadata);
      await d.start();
      expect(d.state, DriveSyncState.error);
      expect(d.errorCode, 'metadata');
      expect(d.pending, greaterThan(0));
      expect(remote.writes, 0);
      await d.disable();
      expect(metadata.data['enabled'], isTrue);
    },
  );
  test(
    'two devices upload and receive while keeping local preferences',
    () async {
      final remote = MemoryHabitSyncProvider();
      final a = await device(seeded()),
          b = await device(HabitState(settings: {'theme': 'dark'}));
      final da = drive(a, remote), db = drive(b, remote);
      expect(await da.enable(), isTrue);
      await db.enable();
      expect(b.state!.habits.single.id, 'h');
      expect(b.state!.settings['theme'], 'dark');
      expect(da.account, 'habit.test@example.test');
      expect(da.lastSync, now);
      expect(da.pending, 0);
      await add(a, 'a');
      await add(b, 'b');
      await da.syncNow();
      await db.syncNow();
      await da.syncNow();
      expect(a.state!.events, hasLength(2));
      expect(b.state!.events, hasLength(2));
    },
  );
  test('cancelling account authorization writes nothing', () async {
    final remote = MemoryHabitSyncProvider(),
        a = await device(seeded()),
        d = drive(a, remote, allow: false);
    expect(await d.enable(), isFalse);
    expect(d.enabled, isFalse);
    expect(remote.writes, 0);
  });
  test('offline failure retains local pending changes and retries', () async {
    final remote = MemoryHabitSyncProvider(),
        a = await device(seeded()),
        d = drive(a, remote);
    await d.enable();
    await add(a, 'a');
    remote.failWrites = 1;
    await d.syncNow();
    expect(d.state, DriveSyncState.error);
    expect(d.pending, greaterThan(0));
    expect(a.state!.events.single.id, 'a');
    await d.syncNow();
    expect(d.state, DriveSyncState.synced);
    expect(d.pending, 0);
  });
  test('local edits during download survive and remain queued', () async {
    final remote = MemoryHabitSyncProvider(),
        a = await device(seeded()),
        d = drive(a, remote);
    await d.enable();
    await add(a, 'a');
    remote.beforePut = () => add(a, 'during');
    await d.syncNow();
    expect(a.state!.events, hasLength(2));
    expect(d.pending, greaterThan(0));
    await d.syncNow();
    expect(d.pending, 0);
  });
  test(
    'off and disconnect preserve both copies; re-enable deduplicates',
    () async {
      final remote = MemoryHabitSyncProvider(), a = await device(seeded());
      var revoked = 0;
      final d = drive(
        a,
        remote,
        revoke: () async {
          revoked++;
        },
      );
      await d.enable();
      await add(a, 'a');
      await d.syncNow();
      final before = remote.files.length;
      await d.disable(disconnect: true);
      expect(d.enabled, isFalse);
      expect(revoked, 1);
      expect(a.state!.events, hasLength(1));
      expect(remote.files, hasLength(before));
      await d.enable();
      expect(a.state!.events, hasLength(1));
    },
  );
  test(
    'newer remote refuses before upload with local and base intact',
    () async {
      final remote = MemoryHabitSyncProvider(),
          a = await device(seeded()),
          d = drive(a, remote);
      await d.enable();
      await add(a, 'a');
      final writes = remote.writes, base = d.base.map((o) => o.id).toList();
      remote.files['$habitSyncRoot/commits/future.json'] = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'handy-habit-sync',
            'version': 99,
            'schema': 99,
          }),
        ),
      );
      await d.syncNow();
      expect(d.state, DriveSyncState.newerRemote);
      expect(d.errorCode, 'newer');
      expect(a.state!.events.single.id, 'a');
      expect(remote.writes, writes);
      expect(d.base.map((o) => o.id), base);
    },
  );
  test('restart resumes saved opt-in and device base', () async {
    final metadata = MemorySyncMetadata(),
        remote = MemoryHabitSyncProvider(),
        a = await device(seeded());
    final d = drive(a, remote, metadata: metadata);
    await d.enable();
    final next = drive(a, remote, metadata: metadata);
    await next.start();
    expect(next.enabled, isTrue);
    expect(next.state, DriveSyncState.synced);
    expect(next.lastSync, now);
  });
  test('debounce and foreground sync pending edits', () async {
    final remote = MemoryHabitSyncProvider(), a = await device(seeded());
    final d = drive(a, remote, delay: const Duration(milliseconds: 5));
    await d.enable();
    await add(a, 'a');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(d.pending, 0);
    await add(a, 'b');
    d.resumed();
    await d.syncNow();
    expect(d.pending, 0);
  });
  test(
    'auth and quota errors have distinct states and do not delete records',
    () async {
      for (final failure in [DriveFailure.authNeeded, DriveFailure.quota]) {
        final a = await device(seeded()), d = drive(a, _ErrorProvider(failure));
        await d.enable();
        expect(d.errorCode, failure.name);
        expect(a.state!.habits.single.id, 'h');
      }
    },
  );
  test(
    'disable during an upload prevents applying it after disconnect',
    () async {
      final remote = MemoryHabitSyncProvider(),
          a = await device(seeded()),
          d = drive(a, remote);
      await d.enable();
      final entered = Completer<void>(), release = Completer<void>();
      remote.beforePut = () async {
        entered.complete();
        await release.future;
      };
      final run = d.syncNow();
      await entered.future;
      final off = d.disable();
      release.complete();
      await run;
      await off;
      expect(d.enabled, isFalse);
      expect(d.state, DriveSyncState.off);
    },
  );
}

class _ErrorProvider extends MemoryHabitSyncProvider {
  final DriveFailure failure;
  _ErrorProvider(this.failure);
  @override
  Future<Set<String>> list(String folder) async =>
      throw DriveException(failure);
}
