import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_keep/app.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

const date = '2025-10-31T08:00:00.000Z';
InventoryAsset fixture() =>
    createAsset(id: 'existing-asset', name: 'Original name', now: date);

Future<void> openEditor(
  WidgetTester tester,
  Future<void> Function(AssetEdit) save, {
  Files? files,
  Camera? camera,
  bool newItem = false,
}) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHandyTheme(keepAccent, Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AssetEditor(
                  asset: newItem ? null : fixture(),
                  boxes: const [],
                  locations: const ['Tủ bếp', 'Gác xép'],
                  files: files ?? Files(),
                  camera: camera ?? Camera(),
                  blobs: const {},
                  onCommit: save,
                ),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

Future<void> name(WidgetTester tester, String value) async {
  await tester.enterText(find.byKey(const Key('item-name')), value);
  await tester.pump();
}

void main() {
  testWidgets('new item commits one creation and update instant', (
    tester,
  ) async {
    AssetEdit? committed;
    await openEditor(tester, (value) async => committed = value, newItem: true);
    await name(tester, 'New item');
    await tester.tap(find.byKey(const Key('place-Tủ bếp')));
    await tapKey(tester, 'item-save');
    expect(find.byType(AssetEditor), findsNothing);
    expect(committed!.asset.name, 'New item');
    expect(committed!.asset.location, 'Tủ bếp');
    expect(committed!.asset.updatedAt, committed!.asset.createdAt);
  });

  testWidgets(
    'failed storage keeps asset editor draft and successful retry commits before pop',
    (tester) async {
      var fail = true, calls = 0;
      AssetEdit? committed;
      await openEditor(tester, (value) async {
        calls++;
        if (fail) throw Exception('storage full');
        committed = value;
      });
      await name(tester, 'Edited name');
      await tapKey(tester, 'item-save');
      expect(find.byType(AssetEditor), findsOneWidget);
      expect(find.textContaining('storage full'), findsOneWidget);
      expect(committed, isNull);
      expect(calls, 1);
      fail = false;
      await tapKey(tester, 'item-save');
      expect(find.byType(AssetEditor), findsNothing);
      expect(committed!.asset.id, 'existing-asset');
      expect(committed!.asset.name, 'Edited name');
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending item write blocks double save, edit and Back', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await openEditor(tester, (value) async {
      calls++;
      await pending.future;
    });
    await name(tester, 'Pending name');
    await tapKey(tester, 'item-save', settle: false);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('item-save'))).onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AssetEditor), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AssetEditor), findsNothing);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dirty item Back asks to discard and postframe exit succeeds', (
    tester,
  ) async {
    var calls = 0;
    await openEditor(tester, (_) async => calls++);
    await name(tester, 'Unsaved name');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved name'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-action')));
    await tester.pumpAndSettle();
    expect(find.byType(AssetEditor), findsNothing);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid item name does not call save', (tester) async {
    var calls = 0;
    await openEditor(tester, (_) async => calls++);
    await name(tester, ' ');
    await tapKey(tester, 'item-save');
    expect(find.byType(AssetEditor), findsOneWidget);
    expect(calls, 0);
    expect(find.textContaining('Invalid inventory text'), findsOneWidget);
  });

  testWidgets('pending photo picker blocks exit and preserves editor', (
    tester,
  ) async {
    final files = Files()..pending = Completer<ImportedBytes?>();
    await openEditor(tester, (_) async {}, files: files);
    await tapKey(tester, 'photo-file', settle: false);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AssetEditor), findsOneWidget);
    files.pending!.complete(null);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AssetEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a camera photo is kept; a file that is not an image is refused',
    (tester) async {
      AssetEdit? committed;
      final camera = Camera()..next = ImportedBytes('shot.png', pngBytes);
      final files = Files()
        ..nextBytes = ImportedBytes('notes.png', Uint8List.fromList([1, 2, 3]));
      await openEditor(
        tester,
        (v) async => committed = v,
        files: files,
        camera: camera,
      );
      await tapKey(tester, 'photo-file');
      expect(find.textContaining('PNG or JPEG'), findsOneWidget);
      await tapKey(tester, 'photo-camera');
      await tapKey(tester, 'item-save');
      final uri = committed!.asset.photoUri;
      expect(uri, startsWith('file:///handy-assets/'));
      expect(committed!.blobs[uri], pngBytes);
    },
  );

  testWidgets('dates come from the calendar, never typed', (tester) async {
    AssetEdit? committed;
    await openEditor(tester, (v) async => committed = v);
    await tapKey(tester, 'date-warrantyUntil');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'item-save');
    expect(
      committed!.asset.warrantyUntil,
      DateTime.now().toIso8601String().substring(0, 10),
    );
  });
}
