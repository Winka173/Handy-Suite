import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_trip/controller.dart';
import 'package:handy_trip/data/store_native.dart';
import 'package:handy_trip/scope.dart';
import 'package:handy_trip/features/checkins/editor.dart';
import 'package:handy_trip/platform/location.dart';
import 'package:handy_trip/platform/media.dart';
import 'package:handy_trip/platform/reminders.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import '../test/ui_test.dart' as fixtures;
import 'native_test.dart' show complete;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real denied Android GPS uses explicit manual fallback', (
    t,
  ) async {
    final dir = (await t.runAsync(getApplicationSupportDirectory))!;
    final c = TripController(
      open: () async =>
          NativeTripStore('${dir.path}/trip-permissions-qa.sqlite'),
    );
    await t.runAsync(c.load);
    await t.runAsync(() => c.change((s) => fixtures.sample()));
    final scope = TripScope(
      controller: c,
      files: const SystemHandyFiles(),
      locationPort: SystemForegroundLocation(),
      reminders: TripReminders(),
      clock: () => DateTime.utc(2026, 11, 2, 2, 30),
    )..chooseTrip('t');
    await fixtures.editorHost(
      t,
      scope,
      (context) =>
          editCheckIn(context, scope, place: c.state!.places.single, gps: true),
    );
    await complete(
      t,
      () => find
          .textContaining('Location unavailable or denied')
          .evaluate()
          .isNotEmpty,
    );
    expect(
      find.textContaining('Location unavailable or denied'),
      findsOneWidget,
    );
    await fixtures.tap(t, find.byKey(const Key('trip-confirm')));
    await fixtures.tap(t, find.byType(SwitchListTile).first);
    await t.tap(find.byKey(const Key('trip-form-save')));
    await complete(t, () => c.state!.visits.length == 1);
    expect(c.state!.visits.single.origin, 'manual');
    expect(c.state!.visits.single.data['geo'], isNull);
    await t.pumpWidget(const SizedBox());
    scope.dispose();
    c.dispose();
    binding.reportData = {
      'physicalDevice': false,
      'pid': pid,
      'gpsDeniedFallback':
          'actual OS permission revoked/user-fixed; manual commit passed',
    };
  });
  testWidgets('real Android photo picker cancellation imports nothing', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Trip photo picker cancellation QA')),
      ),
    );
    final files = (await t.runAsync(() => TripCamera().gallery()))!;
    expect(files, isEmpty);
    binding.reportData = {
      ...binding.reportData ?? {},
      'galleryCancel':
          'actual OS picker dismissed by QA Android Back; zero imported files',
    };
  });
  testWidgets(
    'denied notification permission leaves reminder in app without scheduling',
    (t) async {
      final port = TripReminders();
      final state = fixtures
          .sample()
          .copy({
            'settings': {'notifications': true},
          })
          .put(
            'alarms',
            TripAlarm({
              'id': 'denied-alarm',
              'trip': 't',
              'type': 'booking',
              'target': 'b',
              'at': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 2))
                  .toIso8601String(),
              'zone': 'UTC',
              'enabled': true,
            }),
          );
      await t.runAsync(() => port.sync(state));
      expect(
        (await t.runAsync(port.port.plugin.pendingNotificationRequests))!,
        isEmpty,
      );
      expect(state.alarms.single.enabled, isTrue);
      binding.reportData = {
        ...binding.reportData ?? {},
        'notificationDenied':
            'OS denied: no scheduled notifications, in-app rule preserved',
      };
    },
  );
}
