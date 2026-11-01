import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:archive/archive.dart';
import 'package:handy_keep/app.dart';
import 'package:handy_keep/library.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_storage/src/documents_io.dart';
import 'package:handy_storage/recovery.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import '../test/helpers.dart' show Files;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'corrupt native library is preserved, reset, exported and restored without overwriting new data',
    (tester) async {
      final folder = await Directory.systemTemp.createTemp(
        'handy-recovery-native-',
      );
      final store = FileDocuments('handy-test', 16000000, directory: folder);
      final raw = Uint8List.fromList([0, 255, 42, 13, 10]);
      await store.save('{"broken":true}');
      await File(
        '${folder.path}/handy-test/a.json',
      ).writeAsBytes(raw, flush: true);
      final files = Files();
      final prefs = DevicePreferencesRepository('handy-keep-recovery-native');
      await prefs.save(HandyPreferences(locale: 'en', theme: 'light'));
      await tester.pumpWidget(
        KeepApp(documents: store, files: files, preferences: prefs),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('All local snapshots are corrupt'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('document-recovery')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recovery-reset')));
      // Reset awaits confirmation while the progress indicator animates.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('recovery-confirm')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      final copy = (await store.preserved()).single;
      expect(await store.load(), isNull);
      final zip = ZipDecoder().decodeBytes(
        await store.exportPreserved(copy.id),
        verify: true,
      );
      expect(zip.findFile('a.json')!.content, raw);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('keep-preserved-library-recovery');
      }
      await tester.ensureVisible(find.byKey(const Key('recovery-done')));
      await tester.tap(find.byKey(const Key('recovery-done')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentRecoveryPage), findsNothing);
      expect(
        find.textContaining('All local snapshots are corrupt'),
        findsNothing,
      );
      final restored = InventoryLibrary(
        saveAsset(
          emptyKeepState(),
          createAsset(id: 'restored-item', name: 'Restored camera'),
        ),
        {},
      );
      await store.save(restored.serialize());
      await expectLater(store.undoReset(copy.id), throwsFormatException);
      expect(await store.load(), restored.serialize());
      final stillPreserved = ZipDecoder().decodeBytes(
        await store.exportPreserved(copy.id),
        verify: true,
      );
      expect(stillPreserved.findFile('a.json')!.content, raw);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await folder.delete(recursive: true);
    },
  );
}
