import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_ui/handy_ui.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_bookmark/app.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/platform/store_native.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real SQLite quick save, clipboard, organization, ZIP restore and responsive screens',
    (tester) async {
      late SaveController controller;
      await tester.runAsync(() async {
        final directory = await getApplicationSupportDirectory();
        controller = SaveController(
          open: () => NativeBookmarkStore.open(
            '${directory.path}/save-integration.sqlite',
          ),
        );
        await controller.initialize();
        await controller.update((_) => SaveLibrary());
        final initial = await controller.quickSave(
          'https://github.com/flutter/flutter\nhttps://youtu.be/dQw4w9WgXcQ',
        );
        expect(initial, hasLength(2));
        await controller.quickSave(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ&utm_source=qa',
        );
        expect(controller.library!.bookmarks, hasLength(2));
        await Clipboard.setData(
          const ClipboardData(text: 'https://example.org/handy-save-clipboard'),
        );
        expect(
          await controller.clipboard(),
          'https://example.org/handy-save-clipboard',
        );
        expect(await controller.clipboard(), isNull);
        await controller.quickSave('https://example.org/handy-save-clipboard');
        final col = SaveCollection(
          id: 'qa-learning',
          name: 'Learning',
          color: '#0f766e',
          icon: 'learning',
        );
        await controller.update(
          (s) => s.copyWith(
            collections: [col],
            bookmarks: [
              s.bookmarks.first.copyWith(
                collectionId: col.id,
                tags: ['flutter'],
                note: 'Offline note',
              ),
              ...s.bookmarks.skip(1),
            ],
          ),
        );
        final before = controller.library!.toJson();
        final zip = SavePortable.export(controller.library!, SaveFormat.zip);
        final preview = SavePortable.preview(
          zip,
          SaveFormat.zip,
          current: SaveLibrary(),
        );
        final restored = preview.commit(
          SaveLibrary(),
          strategy: ImportStrategy.replace,
        );
        expect(restored.toJson(), before);
        await controller.update((_) => restored);
        expect(await controller.store!.integrity(), 'ok');
        await controller.store!.close();
        // initialize opens the same actual SQLite file; no mocked repository.
        await controller.initialize();
        expect(controller.library!.toJson(), before);
      });
      await tester.pumpWidget(
        SaveApp(
          guide: false,
          controller: controller,
          preferences: DevicePreferencesRepository(
            'handy-save-qa',
            knownTools: {},
            workflowSteps: {},
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      // Screenshots come from the Android runner (HANDY_SCREENSHOTS=true).
      var surface = false;
      Future<void> snap(String name) async {
        if (!const bool.fromEnvironment('HANDY_SCREENSHOTS')) return;
        if (!surface) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
          surface = true;
        }
        await binding.takeScreenshot(name);
      }

      await snap('save-home');
      await tester.enterText(find.byKey(const Key('save-search')), 'flutter');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('github.com'), findsWidgets);
      await snap('save-search');
      await tester.tap(find.byTooltip('Clear search').first);
      await tester.pumpAndSettle();
      expect(find.text('Learning'), findsWidgets);
      await tester.tap(find.byKey(const Key('place-focus')));
      await tester.pumpAndSettle();
      await snap('save-focus');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      await snap('save-settings');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-add')));
      await tester.pumpAndSettle();
      await snap('save-quick-add');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
