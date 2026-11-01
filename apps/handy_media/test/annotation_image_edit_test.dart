import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart' show kitTheme, menu;
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_media/annotation_image_edit.dart';
import 'package:handy_media/capture_editor.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import 'quick_tools_test.dart' show Files;

PortableCapture editFixture() {
  final bytes = encodeScanPng(
    ScanRaster(
      width: 80,
      height: 40,
      rgba: Uint8List.fromList(List.filled(80 * 40 * 4, 255)),
    ),
  );
  final layer = ProjectLayer(
    id: 'mask',
    kind: 'redact',
    color: '#000000',
    geometry: const LayerGeometry(0, .0, .5, 1),
  );
  final step = ProjectStep(
    id: 'step',
    title: 'Original',
    body: 'Instructions',
    imageUri: 'file:///original/image.png',
    imageWidth: 80,
    imageHeight: 40,
    annotations: [layer],
  );
  return PortableCapture(
    CaptureProject.create(
      'image-edit',
      title: 'Image edit',
    ).copyWith(steps: [step]),
    {step.imageUri: bytes},
  );
}

Future<void> editPress(WidgetTester tester, Finder finder) async {
  // A message from the last step may float over the step strip.
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
      .clearSnackBars();
  await tester.pumpAndSettle();
  final scroll = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .first;
  if (finder.evaluate().isEmpty) {
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      final position = tester.state<ScrollableState>(scroll).position;
      position.jumpTo(
        (position.pixels + 200).clamp(0, position.maxScrollExtent),
      );
      await tester.pumpAndSettle();
    }
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> verifyAnnotationImageEdit(WidgetTester tester) async {
  final original = editFixture(), files = Files();
  await tester.pumpWidget(
    MaterialApp(
      theme: kitTheme,
      home: CaptureEditor(
        initial: original,
        files: files,
        onCommit: (_) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  await menu(tester, 'capture-image-rotate');
  await tester.tap(find.byKey(const Key('confirm-cancel')));
  await tester.pumpAndSettle();
  await menu(tester, 'capture-backup-zip');
  expect(parsePortableProject(files.exported!).project.steps.single.toJson(), {
    ...original.project.steps.single.toJson(),
    'imageUri': 'file:///portable/assets/image-0.png',
  });
  await menu(tester, 'capture-image-rotate');
  await tester.tap(find.byKey(const Key('confirm-action')));
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (i > 2 &&
        find.byKey(const Key('guide-export-cancel')).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
  await menu(tester, 'capture-backup-zip');
  final changed = parsePortableProject(files.exported!),
      step = changed.project.steps.single;
  expect((step.imageWidth, step.imageHeight), (40, 80));
  expect(step.annotations, isEmpty);
  expect(step.id, 'step');
  final raster = decodeBoundedImage(changed.assets[step.imageUri]!);
  expect(raster.rgba.sublist(4 * 10, 4 * 10 + 4), [0, 0, 0, 255]);
  await editPress(tester, find.byTooltip('Undo'));
  await tester.pumpAndSettle();
  await menu(tester, 'capture-backup-zip');
  final restored = parsePortableProject(files.exported!);
  expect(restored.project.steps.single.toJson(), {
    ...original.project.steps.single.toJson(),
    'imageUri': 'file:///portable/assets/image-0.png',
  });
  expect(
    restored.assets[restored.project.steps.single.imageUri],
    original.assets.values.single,
  );
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'flatten edits reuse masks, preserve originals and validate crop/cancellation',
    (tester) async {
      final bundle = editFixture(),
          step = bundle.project.steps.single,
          bytes = bundle.assets.values.single;
      final before = Uint8List.fromList(bytes);
      final outputs = await tester.runAsync(
        () async => [
          await editAnnotatedImage(step, bytes, 'rotate'),
          await editAnnotatedImage(step, bytes, 'resize'),
          await editAnnotatedImage(
            step,
            bytes,
            'crop',
            cropLayer: step.annotations.single,
          ),
        ],
      );
      expect(
        outputs!.map(
          (b) => (decodeBoundedImage(b).width, decodeBoundedImage(b).height),
        ),
        [(40, 80), (40, 20), (40, 40)],
      );
      final crop = decodeBoundedImage(outputs[2]);
      expect(crop.rgba.take(4), [0, 0, 0, 255]);
      expect(bytes, before);
      expect(step.annotations.length, 1);
      await expectLater(
        editAnnotatedImage(step, bytes, 'crop'),
        throwsFormatException,
      );
      await expectLater(
        editAnnotatedImage(
          step,
          bytes,
          'rotate',
          cancellation: CancellationToken()..cancel(),
        ),
        throwsA(isA<Cancelled>()),
      );
      expect(bytes, before);
    },
  );
  testWidgets(
    'annotation image transform cancel and Undo preserve exact portable originals',
    verifyAnnotationImageEdit,
  );
}
