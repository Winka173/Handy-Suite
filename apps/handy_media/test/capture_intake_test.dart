import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart' show kitTheme, menu;
import 'package:handy_files/handy_files.dart';
import 'package:handy_files/camera.dart';
import 'package:handy_media/capture_editor.dart';
import 'package:handy_media/annotation_canvas.dart';
import 'package:handy_media/capture_draft.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'annotation_image_edit_test.dart' show editFixture, editPress;
import 'capture_test.dart' show Store;
import 'quick_tools_test.dart' show Files;

class BatchFiles extends Files implements BatchHandyFiles {
  List<ImportedBytes> selected = [];
  @override
  Future<List<ImportedBytes>> importManyBytes({
    required List<String> extensions,
    int maxFiles = 50,
    int maxEachBytes = 20000000,
    int maxTotalBytes = 60000000,
    dynamic cancellation,
  }) async => selected;
}

class Camera implements ScanCamera {
  ImportedBytes? next;
  @override
  bool get supported => true;
  @override
  Future<ImportedBytes?> capture() async => next;
  @override
  Future<ImportedBytes?> recover() async => null;
}

void main() {
  testWidgets(
    'batch preflight is atomic; canceled camera preserves source; pan and zoom do not edit layers',
    (tester) async {
      final initial = editFixture(), files = BatchFiles(), camera = Camera();
      final valid = ImportedBytes('next.png', initial.assets.values.single);
      files.selected = [
        valid,
        ImportedBytes('broken.png', Uint8List.fromList([137, 80, 78, 71])),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureEditor(
            initial: initial,
            files: files,
            camera: camera,
            onCommit: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await editPress(tester, find.byKey(const Key('capture-import-images')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnnotationCanvas>(find.byType(AnnotationCanvas)).step.id,
        initial.project.steps.single.id,
      );
      expect(find.byTooltip('Undo'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find
                  .ancestor(
                    of: find.byTooltip('Undo'),
                    matching: find.byType(IconButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
      files.selected = [valid, valid];
      await editPress(tester, find.byKey(const Key('capture-import-images')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnnotationCanvas>(find.byType(AnnotationCanvas))
            .step
            .title,
        'next.png',
      );
      await editPress(tester, find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnnotationCanvas>(find.byType(AnnotationCanvas))
            .step
            .toJson(),
        initial.project.steps.single.toJson(),
      );
      await editPress(tester, find.byKey(const Key('capture-camera')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnnotationCanvas>(find.byType(AnnotationCanvas))
            .step
            .toJson(),
        initial.project.steps.single.toJson(),
      );
      await editPress(tester, find.byKey(const Key('capture-zoom')));
      await editPress(tester, find.byKey(const Key('capture-pan')));
      final canvas = tester.widget<AnnotationCanvas>(
        find.byType(AnnotationCanvas),
      );
      expect(canvas.panEnabled, isTrue);
      expect(canvas.transformation!.value.getMaxScaleOnAxis(), 2);
      await tester.drag(
        find.byKey(const Key('annotation-viewport')),
        const Offset(-50, -20),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnnotationCanvas>(find.byType(AnnotationCanvas))
            .step
            .toJson(),
        initial.project.steps.single.toJson(),
      );
    },
  );

  testWidgets(
    'editor title recovers through a separate draft without committing library',
    (tester) async {
      final initial = editFixture(), store = Store();
      var commits = 0;
      final draft = CaptureDraft(store, initial.project.id);
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureEditor(
            initial: initial,
            files: Files(),
            draft: draft,
            onCommit: (_) async {
              commits++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('capture-title')),
        'Recovered title',
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect((await draft.load())!.project.title, 'Recovered title');
      expect(commits, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'flattened share previews opaque masks; Cancel leaves the editor intact',
    (tester) async {
      final initial = editFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureEditor(
            initial: initial,
            files: Files(),
            onCommit: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await menu(tester, 'capture-share-png');
      for (
        var i = 0;
        i < 30 && find.byType(AlertDialog).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.text('Review flattened image'), findsOneWidget);
      final preview = tester.widget<Image>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Image),
        ),
      );
      final decoded = decodeBoundedImage(
        ((preview.image as ResizeImage).imageProvider as MemoryImage).bytes,
      );
      expect(decoded.rgba.sublist(0, 4), [0, 0, 0, 255]);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(CaptureEditor), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
