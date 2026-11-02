import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_trip/app.dart';
import 'package:handy_trip/controller.dart';
import 'package:handy_trip/data/store_native.dart';
import 'package:handy_trip/scope.dart';
import 'package:handy_trip/platform/location.dart';
import 'package:handy_trip/platform/reminders.dart';
import 'package:handy_trip/features/sharing/memory_book.dart';
import 'package:handy_trip/features/passport/stamp_export.dart';
import 'package:handy_trip/features/trips/replay.dart';
import 'package:handy_trip/features/media/photo_proposal.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import '../test/ui_test.dart' as fixtures;
import '../test/memory_ui_test.dart' show FixtureFiles;
import 'native_test.dart' show complete;
import 'photo_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native signatures: real PNG/PDF/book outputs, EXIF review, illustrative replay',
    (t) async {
      final dir = (await t.runAsync(getApplicationSupportDirectory))!,
          out = Directory('${dir.path}/trip-memory-qa-exports');
      await out.create(recursive: true);
      final files = FixtureFiles(out),
          store = NativeTripStore('${dir.path}/trip-memory-qa.sqlite'),
          c = TripController(open: () async => store);
      await t.runAsync(c.load);
      expect(c.error, isNull);
      var state = fixtures.sample();
      final asset = prepareAsset(
        'QA-camera-metadata.jpg',
        base64Decode(photoFixture),
        caption: 'QA fixture, not a real travel photograph',
      );
      state = addPreparedAsset(state, asset);
      state = state.put(
        'places',
        state.place('p').copy({
          'geo': {'lat': 10.78, 'lon': 106.7},
        }),
      );
      state = state.put(
        'notes',
        state.notes.single.copy({
          'trip': 't',
          'assets': [asset.asset.key],
        }),
      );
      state = checkIn(
        state,
        Visit({
          'id': 'v',
          'trip': 't',
          'stop': 's',
          'place': 'p',
          'at': '2026-11-02T01:00:00Z',
          'zone': 'Asia/Ho_Chi_Minh',
          'origin': 'manual',
          'confirmed': true,
          'assets': [asset.asset.key],
          'created': '2026-11-02T01:00:00Z',
          'updated': '2026-11-02T01:00:00Z',
        }),
        now: DateTime.utc(2026, 11, 2, 2, 30),
      );
      state = state.put(
        'trips',
        state.trip('t').copy({
          'id': 'second',
          'title': 'Second journey',
          'cover': null,
        }),
      );
      await t.runAsync(() => c.change((s) => state));
      final scope = TripScope(
        controller: c,
        files: files,
        locationPort: SystemForegroundLocation(),
        reminders: TripReminders(),
        clock: () => DateTime.utc(2026, 11, 2, 2, 30),
      )..chooseTrip('t');
      final before = c.state!.toJson();
      await fixtures.editorHost(
        t,
        scope,
        (context) => exportPersonalStamp(context, scope, 'v'),
      );
      await fixtures.tap(t, find.byType(SwitchListTile).last);
      await t.tap(find.byKey(const Key('trip-form-save')));
      await complete(t, () => files.outputs.isNotEmpty);
      final png = await File(files.outputs.single).readAsBytes();
      expect(png.take(4), [137, 80, 78, 71]);
      await fixtures.editorHost(
        t,
        scope,
        (context) => exportMemoryBook(context, scope, 't'),
      );
      await fixtures.tap(t, find.byType(SwitchListTile).last);
      await t.tap(find.byKey(const Key('trip-form-save')));
      await complete(t, () => files.outputs.length == 2);
      final pdf = await File(files.outputs.last).readAsBytes();
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      expect(c.state!.toJson(), before);
      await fixtures.editorHost(
        t,
        scope,
        (context) => showPhotoProposal(context, scope, asset.asset.key),
      );
      await t.tap(find.byKey(const Key('trip-form-save')));
      await complete(
        t,
        () => find.text('Review photo suggestions').evaluate().isNotEmpty,
      );
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
      await t.pumpAndSettle();
      await binding.takeScreenshot('trip-native-photo-proposal');
      expect(c.state!.visits.length, 1);
      await fixtures.tap(t, find.text('Review a check-in'));
      await fixtures.tap(
        t,
        find.descendant(
          of: find.widgetWithText(
            SwitchListTile,
            'I confirm that I visited this place',
          ),
          matching: find.byType(Switch),
        ),
      );
      await t.tap(find.byKey(const Key('trip-form-save')));
      await complete(t, () => c.state!.visits.length == 2);
      expect(c.state!.visits.last.origin, 'photo-suggestion');
      expect(c.state!.visits.last.data['geo'], isNull);
      expect(c.state!.files[asset.asset.path], base64Decode(photoFixture));
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        TripApp(
          controller: c,
          files: files,
          clock: () => DateTime.utc(2026, 11, 2, 2, 30),
        ),
      );
      await t.pumpAndSettle();
      await fixtures.tap(t, find.text('Passport').last);
      await binding.takeScreenshot('trip-native-passport-photos');
      await t.pumpWidget(const SizedBox());
      await fixtures.editorHost(
        t,
        scope,
        (context) => showTripReplay(context, scope, 't'),
      );
      await binding.takeScreenshot('trip-native-replay');
      final reopened = await store.read();
      expect(reopened.toJson(), c.state!.toJson());
      expect(readBackup(fullBackup(reopened)).toJson(), reopened.toJson());
      final html = memoryBookZip(reopened, 't');
      binding.reportData = {
        ...binding.reportData ?? {},
        'physicalDevice': false,
        'pid': pid,
        'visits': 2,
        'uniquePlaces': 1,
        'nativeSignatures':
            'UI -> real serializers -> private Android filesystem, fresh SQLite read and ZIP equality; OS save picker is a separate unverified surface',
        'exports': {
          'trip-native-personal-stamp.png': base64Encode(png),
          'trip-native-memory-book.pdf': base64Encode(pdf),
          'trip-native-memory-book.zip': base64Encode(html),
        },
      };
      await t.pumpWidget(const SizedBox());
      scope.dispose();
      c.dispose();
    },
  );
}
