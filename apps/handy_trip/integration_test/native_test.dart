import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_trip/app.dart';
import 'package:handy_trip/controller.dart';
import 'package:handy_trip/data/store_native.dart';
import 'package:handy_trip/features/checkins/editor.dart';
import 'package:handy_trip/platform/location.dart';
import 'package:handy_trip/platform/reminders.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import '../test/ui_test.dart' as fixtures;

Future<void> complete(WidgetTester t, bool Function() ready) async {
  for (var n = 0; n < 240 && !ready(); n++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
  }
  expect(
    ready(),
    isTrue,
    reason: 'Wait for the actual native transaction, not an animation',
  );
  await t.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('TRIP_QA_PHASE', defaultValue: 'write');
  testWidgets(
    'native $phase: relational journal, assets, backups and SQLite restart',
    (t) async {
      final dir = (await t.runAsync(getApplicationSupportDirectory))!;
      final store = NativeTripStore('${dir.path}/handy-trip-qa.sqlite');
      final c = TripController(open: () async => store);
      await t.runAsync(c.load);
      expect(c.error, isNull);
      if (phase == 'write') {
        final original = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGNQaFgARAwQCgAhDgUB9rWiXgAAAABJRU5ErkJggg==',
        );
        final source = File('${dir.path}/qa-original-photo.png');
        await source.writeAsBytes(original);
        var data = fixtures.sample();
        final prepared = prepareAsset('qa-original-photo.png', original);
        data = addPreparedAsset(data, prepared);
        data = data.put(
          'notes',
          data.notes.single.copy({
            'assets': [prepared.asset.key],
          }),
        );
        data = data.put(
          'places',
          Place({
            'id': 'p2',
            'name': 'River walk',
            'geo': {'lat': 10.78, 'lon': 106.7},
            'city': 'Ho Chi Minh City',
          }),
        );
        data = data.put(
          'stops',
          Stop({
            'id': 's2',
            'trip': 't',
            'place': 'p2',
            'title': 'River walk',
            'day': '2026-11-02',
          }),
        );
        await t.runAsync(() => c.change((s) => data));
        final scope = fixtures.makeScope(c)..chooseTrip('t');
        for (final key in ['s', 's2']) {
          await fixtures.editorHost(
            t,
            scope,
            (context) => editCheckIn(
              context,
              scope,
              stop: c.state!.stops.firstWhere((v) => v.key == key),
            ),
          );
          await fixtures.tap(t, find.byType(SwitchListTile).first);
          await t.tap(find.byKey(const Key('trip-form-save')));
          await complete(
            t,
            () => c.state!.visits.length == (key == 's' ? 1 : 2),
          );
        }
        expect(uniquePlaces(c.state!).length, 2);
        expect(c.state!.stops.every((s) => s.status == 'visited'), isTrue);
        final bytes = fullBackup(c.state!);
        final restored = readBackup(bytes);
        expect(jsonEncode(restored.toJson()), jsonEncode(c.state!.toJson()));
        final corrupted = bytes.sublist(0, bytes.length ~/ 2);
        expect(() => readBackup(corrupted), throwsA(anything));
        expect(c.state!.visits.length, 2);
        await t.runAsync(
          () => c.change(
            (s) => s.put('trips', s.trip('t').copy({'status': 'completed'})),
          ),
        );
        final before = c.state!;
        await t.runAsync(() => c.change((s) => s.copy({'notes': []})));
        await t.runAsync(c.undo);
        expect(c.state!.notes.single.assets, [prepared.asset.key]);
        expect(c.state!.files[prepared.asset.path], original);
        expect(await source.readAsBytes(), original);
        expect(
          publicDocument(before).toString(),
          isNot(contains('PRIVATE-ABC')),
        );
        final sentinel = File('${dir.path}/trip-qa-expected.json');
        await sentinel.writeAsString(jsonEncode(c.state!.toJson()));
        scope.dispose();
      } else {
        final expected = jsonDecode(
          await File('${dir.path}/trip-qa-expected.json').readAsString(),
        );
        expect(c.state!.toJson(), expected);
        expect(c.state!.visits.length, 2);
        expect(c.state!.trip('t').status, 'completed');
        expect(await store.integrity(), 'ok');
      }
      await t.pumpWidget(
        TripApp(controller: c, clock: () => DateTime.utc(2026, 11, 2, 2, 30)),
      );
      await t.pumpAndSettle();
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
      await t.pumpAndSettle();
      await binding.takeScreenshot('trip-native-$phase-trips');
      await fixtures.tap(t, find.text('Journal').last);
      await binding.takeScreenshot('trip-native-$phase-journal');
      await fixtures.tap(t, find.text('Passport').last);
      await binding.takeScreenshot('trip-native-$phase-passport');
      await t.pumpWidget(const SizedBox());
      c.dispose();
      binding.reportData = {
        ...binding.reportData ?? {},
        'phase': phase,
        'pid': pid,
        'database': 'QA-only SQLite',
        'visits': 2,
        'uniquePlaces': 2,
        'realHardware': false,
      };
    },
  );
  testWidgets(
    'foreground location adapter returns a real OS fix only after permission',
    (t) async {
      if (!Platform.isAndroid || phase != 'write') return;
      final fix = (await t.runAsync(
        () => SystemForegroundLocation().capture(),
      ))!;
      expect(fix.geo.lat, inInclusiveRange(-90, 90));
      expect(fix.geo.lon, inInclusiveRange(-180, 180));
      expect(fix.accuracy, isNonNegative);
      binding.reportData = {
        ...binding.reportData ?? {},
        'gpsAdapter': 'foreground emulator OS fix; no automatic visit',
        'accuracy': fix.accuracy,
      };
    },
  );
  testWidgets(
    'native reminder schedules, delivers and cancels without remote push',
    (t) async {
      if (!Platform.isAndroid || phase != 'write') return;
      final reminders = TripReminders();
      var state = fixtures.sample().copy({
        'settings': {'notifications': true},
      });
      state = state.put(
        'alarms',
        TripAlarm({
          'id': 'qa-alarm',
          'trip': 't',
          'type': 'booking',
          'target': 'b',
          'at': DateTime.now()
              .toUtc()
              .add(const Duration(seconds: 8))
              .toIso8601String(),
          'zone': 'UTC',
          'enabled': true,
        }),
      );
      await t.runAsync(() => reminders.sync(state));
      final pending = (await t.runAsync(
        reminders.port.plugin.pendingNotificationRequests,
      ))!;
      expect(pending, isNotEmpty);
      await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 20)));
      final delivered = (await t.runAsync(
        reminders.port.plugin.getActiveNotifications,
      ))!;
      expect(delivered.any((n) => n.title == 'Handy Trip'), isTrue);
      await t.runAsync(() => reminders.sync(state.copy({'alarms': []})));
      expect(
        (await t.runAsync(reminders.port.plugin.pendingNotificationRequests))!,
        isEmpty,
      );
      await t.runAsync(() => reminders.port.plugin.cancelAll());
      binding.reportData = {
        ...binding.reportData ?? {},
        'notifications':
            'scheduled/delivered/cancelled on Android emulator; not a physical-device guarantee',
      };
    },
  );
}
