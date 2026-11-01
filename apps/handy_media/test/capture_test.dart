import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart' show kitTheme, menu, start;
import 'package:handy_media/capture_library.dart';
import 'package:handy_media/capture_editor.dart';
import 'package:handy_media/annotation_canvas.dart';
import 'package:handy_media/annotation_painter.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_files/handy_files.dart';
import 'quick_tools_test.dart' show Files, png;

File fixture(String name) {
  final file = File('test-fixtures/flutter-snap/$name');
  return file.existsSync()
      ? file
      : File('../../test-fixtures/flutter-snap/$name');
}

class Store implements DocumentRepository {
  String? text;
  bool fail = false;
  int attempts = 0;
  @override
  Future<String?> load() async => text;
  @override
  Future<void> save(String value) async {
    attempts++;
    if (fail) throw StateError('Disk full');
    text = value;
  }
}

PortableCapture bundle() {
  final source = CaptureProject.create('fixture', title: 'Project');
  final step = ProjectStep(
    id: 'step',
    title: 'Step',
    body: 'Body',
    imageUri: 'file:///owned/image.png',
    imageWidth: 100,
    imageHeight: 100,
    annotations: [defaultLayer('rect', 'rect')],
  );
  return PortableCapture(source.copyWith(steps: [step]), {
    step.imageUri: png(),
  });
}

void main() {
  testWidgets(
    'preview scales original-coordinate strokes consistently with export',
    (tester) async {
      final bytes = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        canvas.drawColor(Colors.white, BlendMode.src);
        final layer = ProjectLayer(
          id: 'outline',
          kind: 'rect',
          color: '#000000',
          geometry: const LayerGeometry(0.2, 0.2, 0.4, 0.4),
        );
        AnnotationPainter([
          layer,
        ], const Size(100, 100)).paint(canvas, const Size(200, 200));
        final picture = recorder.endRecording();
        try {
          final image = await picture.toImage(200, 200);
          try {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            return data!.buffer.asUint8List();
          } finally {
            image.dispose();
          }
        } finally {
          picture.dispose();
        }
      });
      final decoded = decodeBoundedImage(bytes!);
      expect(
        decoded.rgba.sublist((80 * 200 + 38) * 4, (80 * 200 + 38) * 4 + 4),
        [0, 0, 0, 255],
      );
      expect(
        decoded.rgba.sublist((80 * 200 + 36) * 4, (80 * 200 + 36) * 4 + 4),
        [255, 255, 255, 255],
      );
    },
  );
  testWidgets('freehand pen creates actual normalized multi-point stroke', (
    tester,
  ) async {
    final source = bundle().project.steps.single;
    List<ProjectPoint>? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: kitTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: AnnotationCanvas(
                step: source,
                png: png(),
                selected: null,
                onSelect: (_) {},
                onChange: (_) {},
                onGestureStart: () {},
                onGestureEnd: () {},
                drawing: true,
                onStroke: (points) => result = points,
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byKey(const Key('capture-pen-input'))) +
          const Offset(20, 20),
    );
    await gesture.moveBy(const Offset(40, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(30, -10));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(result, isNotNull);
    expect(result!.length, greaterThanOrEqualTo(2));
    expect(result!.last.x, greaterThan(result!.first.x));
    expect(
      result!.every((p) => p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1),
      isTrue,
    );
  });
  test(
    'actual legacy ZIP → library → ZIP preserves all fields, layers and pixels',
    () {
      final source = parsePortableProject(
        fixture('legacy-project.zip').readAsBytesSync(),
      );
      final library = CaptureLibrary([source]),
          restored = CaptureLibrary.parse(library.serialize());
      expect(
        restored.projects.single.project.toJson(),
        source.project.toJson(),
      );
      expect(restored.projects.single.assets, source.assets);
      final exported = parsePortableProject(
        buildPortableProject(
          restored.projects.single.project,
          restored.projects.single.assets,
        ),
      );
      expect(exported.project.toJson(), source.project.toJson());
      expect(exported.assets, source.assets);
      expect(
        () => library.save(source, importing: true),
        throwsFormatException,
      );
    },
  );
  test(
    'legacy JSON keeps missing image URI and every annotation without path reads',
    () {
      final source = CaptureProject.fromText(
        fixture('legacy-project.json').readAsStringSync(),
      );
      final restored = CaptureLibrary.parse(
        CaptureLibrary([PortableCapture(source, {})]).serialize(),
      ).projects.single;
      expect(restored.project.toJson(), source.toJson());
      expect(restored.assets, isEmpty);
      expect(
        () => buildPortableProject(restored.project, restored.assets),
        throwsFormatException,
      );
      final raw = jsonDecode(CaptureLibrary([restored]).serialize());
      raw['projects'][0]['assets'] = {
        'file:///unreferenced.png': base64Encode(png()),
      };
      expect(
        () => CaptureLibrary.parse(jsonEncode(raw)),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'cancelled/corrupt import and failed write preserve existing library',
    (tester) async {
      final store = Store()..text = CaptureLibrary([bundle()]).serialize(),
          files = Files(),
          before = store.text;
      await start(tester, documents: store, files: files);
      await menu(tester, 'capture-import');
      expect(store.text, before);
      files.next = ImportedBytes('broken.zip', Uint8List(20));
      await menu(tester, 'capture-import');
      expect(store.text, before);
      expect(store.attempts, 0);
      files.next = ImportedBytes(
        'legacy.zip',
        fixture('legacy-project.zip').readAsBytesSync(),
      );
      store.fail = true;
      await menu(tester, 'capture-import');
      expect(store.text, before);
      expect(store.attempts, 1);
      store.fail = false;
      await menu(tester, 'capture-import');
      expect(CaptureLibrary.parse(store.text!).projects.length, 2);
    },
  );
  testWidgets(
    'save failure retains editor/title; successful retry commits before closing',
    (tester) async {
      final store = Store()..fail = true;
      var attempted = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CaptureEditor(
                      initial: bundle(),
                      files: Files(),
                      onCommit: (value) async {
                        attempted++;
                        await store.save(CaptureLibrary([value]).serialize());
                      },
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('capture-title')),
        'Changed title',
      );
      await tester.tap(find.byKey(const Key('capture-save')));
      await tester.pumpAndSettle();
      expect(attempted, 1);
      expect(find.byType(CaptureEditor), findsOneWidget);
      expect(store.text, isNull);
      store.fail = false;
      await tester.tap(find.byKey(const Key('capture-save')));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureEditor), findsNothing);
      expect(
        CaptureLibrary.parse(store.text!).projects.single.project.title,
        'Changed title',
      );
    },
  );
  testWidgets(
    'layer move/resize at image edge keeps normalized bounds and points',
    (tester) async {
      var step = bundle().project.steps.single;
      var starts = 0, ends = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: StatefulBuilder(
                  builder: (context, setState) => AnnotationCanvas(
                    step: step,
                    png: png(),
                    selected: 'rect',
                    onSelect: (_) {},
                    onChange: (next) => setState(
                      () => step = step.copyWith(annotations: [next]),
                    ),
                    onGestureStart: () => starts++,
                    onGestureEnd: () => ends++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.drag(
        find.byKey(const ValueKey('layer-rect')),
        const Offset(1000, 1000),
      );
      await tester.pump();
      final moved = step.annotations.single.geometry;
      expect(moved.x + moved.width, closeTo(1, 0.00001));
      expect(moved.y + moved.height, closeTo(1, 0.00001));
      await tester.drag(
        find.byKey(const Key('layer-resize')),
        const Offset(-30, -20),
      );
      await tester.pump();
      step.annotations.single.geometry.validate();
      expect(step.annotations.single.geometry.width, lessThan(moved.width));
      expect(starts, 2);
      expect(ends, 2);
    },
  );
  testWidgets(
    'flattened PNG paints opaque redaction into original-resolution pixels',
    (tester) async {
      final source = bundle().project.steps.single,
          redact = ProjectLayer(
            id: 'redact',
            kind: 'redact',
            geometry: const LayerGeometry(0.2, 0.2, 0.4, 0.4),
          );
      final overlap = ProjectLayer(
        id: 'overlap',
        kind: 'highlight',
        geometry: const LayerGeometry(0.2, 0.2, 0.4, 0.4),
        color: '#FF0000',
      );
      final bytes = await tester.runAsync(
        () => flattenAnnotation(
          source.copyWith(annotations: [redact, overlap]),
          png(),
        ),
      );
      final decoded = decodeBoundedImage(bytes!);
      expect((decoded.width, decoded.height), (100, 100));
      expect(
        decoded.rgba.sublist((40 * 100 + 40) * 4, (40 * 100 + 40) * 4 + 4),
        [0, 0, 0, 255],
      );
      expect(decoded.rgba.sublist(0, 4), [255, 255, 255, 255]);
    },
  );
}
