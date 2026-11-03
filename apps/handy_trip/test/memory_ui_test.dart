import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_core/handy_core.dart' show CancellationToken;
import 'package:handy_trip/controller.dart';
import 'package:handy_trip/scope.dart';
import 'package:handy_trip/platform/location.dart';
import 'package:handy_trip/platform/reminders.dart';
import 'package:handy_trip/features/sharing/memory_book.dart';
import 'package:handy_trip/features/passport/stamp_export.dart';
import 'package:handy_trip/features/media/photo_proposal.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'ui_test.dart' as fixtures;

// Host filesystem port for real serializer output; production uses OS pickers.
class FixtureFiles implements HandyFiles {
  final Directory dir;
  bool cancel = false;
  final outputs = <String>[];
  FixtureFiles(this.dir);
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    if (cancel) return null;
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    outputs.add(file.path);
    return file.path;
  }

  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async => null;
}

TripState seeded() {
  var s = fixtures.sample();
  final p = prepareAsset(
    'photo-metadata.jpg',
    File('test/fixtures/photo-metadata.jpg').readAsBytesSync(),
    caption: 'Private photo caption',
  );
  s = addPreparedAsset(s, p);
  s = s.put(
    'places',
    s.place('p').copy({
      'geo': {'lat': 10.78, 'lon': 106.7},
    }),
  );
  return checkIn(
    s,
    Visit({
      'id': 'v',
      'trip': 't',
      'stop': 's',
      'place': 'p',
      'at': '2026-11-02T01:00:00Z',
      'zone': 'Asia/Ho_Chi_Minh',
      'origin': 'manual',
      'confirmed': true,
      'created': '2026-11-02T01:00:00Z',
      'updated': '2026-11-02T01:00:00Z',
      'assets': [p.asset.key],
    }),
    now: DateTime.utc(2026, 11, 2, 2, 30),
  );
}

Future<void> waitFor(WidgetTester t, bool Function() ready) async {
  for (var i = 0; i < 200 && !ready(); i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pump();
  }
  expect(
    ready(),
    isTrue,
    reason: find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .join('\n'),
  );
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FixtureFiles files;
  late TripController c;
  late TripScope scope;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('trip-memory-ui-');
    files = FixtureFiles(directory);
    c = TripController(open: () async => fixtures.MemoryStore(seeded()));
    await c.load();
    scope = TripScope(
      controller: c,
      files: files,
      locationPort: SystemForegroundLocation(),
      reminders: TripReminders(),
      clock: () => DateTime.utc(2026, 11, 2, 2, 30),
    )..chooseTrip('t');
  });
  tearDown(() async {
    scope.dispose();
    c.dispose();
    await directory.delete(recursive: true);
  });
  test(
    'stamp PNG/PDF and both book layouts create real standalone outputs',
    () async {
      final loader = FontLoader('packages/handy_ui/Geist')
        ..addFont(rootBundle.load('packages/handy_ui/fonts/Geist-Regular.ttf'));
      await loader.load();
      final out = Directory('../../docs/qa/evidence/exports')
        ..createSync(recursive: true);
      for (final style in ['ledger', 'postcard']) {
        final png = await stampPng(c.state!, 'v', style: style),
            codec = await ui.instantiateImageCodec(png),
            frame = await codec.getNextFrame();
        expect(frame.image.width, 1200);
        expect(frame.image.height, 800);
        frame.image.dispose();
        codec.dispose();
        await File('${out.path}/trip-stamp-$style.png').writeAsBytes(png);
        await File(
          '${out.path}/trip-stamp-$style.pdf',
        ).writeAsBytes(await stampPdf(c.state!, 'v', style: style));
      }
      for (final layout in ['daybook', 'contact-sheet']) {
        final pdf = await memoryBookPdf(c.state!, 't', layout: layout);
        expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
        await File('${out.path}/trip-memory-$layout.pdf').writeAsBytes(pdf);
        await File(
          '${out.path}/trip-memory-$layout.zip',
        ).writeAsBytes(memoryBookZip(c.state!, 't', layout: layout));
      }
    },
  );
  testWidgets(
    'stamp requires review; real PNG export and cancellation never mutate data',
    (t) async {
      final before = c.state!.toJson();
      await fixtures.editorHost(
        t,
        scope,
        (context) => exportPersonalStamp(context, scope, 'v'),
      );
      await fixtures.tap(t, find.byKey(const Key('trip-form-save')));
      expect(files.outputs, isEmpty);
      await fixtures.tap(t, find.byType(SwitchListTile).first);
      await t.tap(find.byKey(const Key('trip-form-save')));
      await waitFor(t, () => files.outputs.isNotEmpty);
      expect((File(files.outputs.single).readAsBytesSync()).take(4), [
        137,
        80,
        78,
        71,
      ]);
      expect(c.state!.toJson(), before);
      files.cancel = true;
      await fixtures.editorHost(
        t,
        scope,
        (context) => exportMemoryBook(context, scope, 't'),
      );
      await fixtures.tap(t, find.byType(SwitchListTile).last);
      await t.tap(find.byKey(const Key('trip-form-save')));
      await waitFor(
        t,
        () => find.textContaining('Export cancelled').evaluate().isNotEmpty,
      );
      expect(find.byKey(const Key('trip-form-save')), findsOneWidget);
      expect(c.state!.toJson(), before);
      await fixtures.tap(t, find.text('Cancel'));
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'metadata preview creates nothing until user confirms the existing check-in form',
    (t) async {
      final original = c.state!, asset = original.assets.first;
      await fixtures.editorHost(
        t,
        scope,
        (context) => showPhotoProposal(context, scope, asset.key),
      );
      await t.tap(find.byKey(const Key('trip-form-save')));
      await waitFor(
        t,
        () => find.text('Review photo suggestions').evaluate().isNotEmpty,
      );
      expect(c.state!.toJson(), original.toJson());
      await fixtures.tap(t, find.text('Review a check-in'));
      await fixtures.tap(t, find.byKey(const Key('trip-form-save')));
      expect(c.state!.visits.length, 1);
      await waitFor(
        t,
        () =>
            t
                .widget<SwitchListTile>(
                  find.widgetWithText(
                    SwitchListTile,
                    'I confirm that I visited this place',
                  ),
                )
                .onChanged !=
            null,
      );
      expect(
        t
            .widget<SwitchListTile>(
              find.widgetWithText(
                SwitchListTile,
                'I confirm that I visited this place',
              ),
            )
            .onChanged,
        isNotNull,
        reason: 'The failed confirmation must release the form busy state',
      );
      expect(
        t
            .widget<SwitchListTile>(
              find.widgetWithText(
                SwitchListTile,
                'I confirm that I visited this place',
              ),
            )
            .value,
        isFalse,
        reason: 'A refused save must not silently check the confirmation',
      );
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
      expect(
        t
            .widget<SwitchListTile>(
              find.widgetWithText(
                SwitchListTile,
                'I confirm that I visited this place',
              ),
            )
            .value,
        isTrue,
      );
      await t.tap(find.byKey(const Key('trip-form-save')));
      await waitFor(t, () => c.state!.visits.length == 2);
      expect(c.state!.visits.last.origin, 'photo-suggestion');
      expect(c.state!.visits.last.data['geo'], isNull);
      expect(c.state!.files[asset.path], original.files[asset.path]);
      await t.pumpWidget(const SizedBox());
    },
  );
}
