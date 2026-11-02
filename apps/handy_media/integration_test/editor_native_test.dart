import 'package:flutter_test/flutter_test.dart';
import '../test/helpers.dart' show kitTheme, menu, tapKey;
import 'package:integration_test/integration_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_media/app.dart';
import 'package:handy_media/capture_draft.dart';
import 'package:handy_media/capture_editor.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import '../test/annotation_image_edit_test.dart' show editFixture, editPress;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late WidgetTester current;
  Future<void> snap(String name) async {
    if (!const bool.fromEnvironment('HANDY_SCREENSHOTS')) return;
    await binding.convertFlutterSurfaceToImage();
    await current.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  testWidgets(
    'native draft survives editor disposal and restores exact assets; zoom and share review preserve project',
    (tester) async {
      current = tester;
      final original = editFixture();
      final documents = localDocuments(
        'handy-media-draft-native-qa',
        maxBytes: 30000000,
      );
      final draft = CaptureDraft(documents, original.project.id);
      await tester.runAsync(draft.clear);
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureEditor(
            initial: original,
            files: const SystemHandyFiles(),
            draft: draft,
            onCommit: (_) async =>
                fail('Recovery test must not commit the saved library'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('capture-title')),
        'Recovered native editor',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final reopened = CaptureDraft(documents, original.project.id);
      final saved = (await tester.runAsync(reopened.load))!;
      expect(saved.project.title, 'Recovered native editor');
      expect(saved.assets.values.single, original.assets.values.single);
      expect(
        saved.project.steps.single.toJson(),
        original.project.steps.single.toJson(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureEditor(
            initial: saved,
            files: const SystemHandyFiles(),
            draft: reopened,
            restoredDraft: true,
            onCommit: (_) async => fail('Review must not commit'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await snap('media-editor-draft-restored');
      await editPress(tester, find.byKey(const Key('capture-zoom')));
      await editPress(tester, find.byKey(const Key('capture-pan')));
      await tester.drag(
        find.byKey(const Key('annotation-viewport')),
        const Offset(-40, -20),
      );
      await tester.pumpAndSettle();
      await snap('media-editor-zoom-pan');
      await menu(tester, 'capture-share-png');
      for (
        var i = 0;
        i < 30 && find.byType(AlertDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(find.text('Review flattened image'), findsOneWidget);
      // The export spinner remains active behind this modal until Cancel/Share.
      await tester.pump(const Duration(milliseconds: 300));
      await snap('media-editor-share-review');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(original.project.title, 'Image edit');
      expect(
        (await tester.runAsync(reopened.load))!.assets.values.single,
        original.assets.values.single,
      );
      final portable = parsePortableProject(
        buildPortableProject(saved.project, saved.assets),
      );
      expect(portable.assets.values.single, original.assets.values.single);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => CaptureDraft(documents, original.project.id).clear(),
      );
      final preferences = DevicePreferencesRepository(
        'handy-media-native-qa',
        knownTools: {'subtitle-srt', 'subtitle-vtt'},
        workflowSteps: {},
      );
      await tester.runAsync(
        () => preferences.save(
          HandyPreferences(
            favorites: ['subtitle-srt'],
            drafts: {'subtitle-srt': 'QA saved input'},
          ),
        ),
      );
      await tester.pumpWidget(
        MediaApp(
          preferences: preferences,
          documents: localDocuments('handy-media-catalog-native-qa'),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      await tapKey(tester, 'open-settings');
      await tapKey(tester, 'settings-clear-inputs');
      await snap('media-cleanup-confirm');
      await tester.tap(find.byKey(const Key('confirm-cancel')));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(preferences.load))!.drafts['subtitle-srt'],
        'QA saved input',
      );
      await tapKey(tester, 'settings-clear-inputs');
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      final cleaned = (await tester.runAsync(preferences.load))!;
      expect(cleaned.drafts, isEmpty);
      // The subtitle tool moved to Handy Tools: its pin goes too.
      expect(cleaned.favorites, isEmpty);
      await snap('media-cleanup-complete');
      await tester.runAsync(() => preferences.save(HandyPreferences()));
    },
  );
}
