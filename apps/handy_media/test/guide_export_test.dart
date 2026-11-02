import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart' show kitTheme, menu;
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_media/capture_editor.dart';
import 'package:handy_media/annotation_painter.dart';
import 'package:handy_media/annotation_canvas.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:image/image.dart' as img;
import 'quick_tools_test.dart' show Files, png;
import 'capture_test.dart' show bundle;

class GuideFiles extends Files {
  final outputs = <String, Uint8List>{};
  bool cancel = false, fail = false;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    cancellation?.check();
    if (fail) throw StateError('Export provider failed');
    if (cancel) return null;
    outputs[name] = Uint8List.fromList(bytes);
    return 'saved';
  }

  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) => exportBytes(
    name,
    Uint8List.fromList(utf8.encode(text)),
    mimeType: 'text/markdown',
    cancellation: cancellation,
  );
}

PortableCapture guideBundle() {
  final p = bundle();
  final first = p.project.steps.first.copyWith(
    annotations: [
      ProjectLayer(
        id: 'mask',
        kind: 'redact',
        geometry: const LayerGeometry(.2, .2, .4, .4),
      ),
    ],
  );
  final second = ProjectStep.parse({
    ...first.toJson(),
    'id': 'step-two',
    'annotations': [],
  });
  return PortableCapture(
    CaptureProject.parse({
      ...p.project.toJson(),
      'kind': 'comparison',
      'steps': [first.toJson(), second.toJson()],
    }),
    p.assets,
  );
}

Future<void> guideReveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    // A drag through the canvas is an annotation gesture. Navigate the outer
    // list without moving a layer while locating controls below the canvas.
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(
        (position.pixels + 300).clamp(0, position.maxScrollExtent),
      );
      await tester.pumpAndSettle();
    }
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> guidePress(WidgetTester tester, Finder finder) async {
  await guideReveal(tester, finder);
  await tester.tap(finder.hitTestable());
  // Export waits for a review dialog while its progress indicator animates.
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> guideSettle(WidgetTester tester) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final undo in [false, true]) {
    testWidgets('metadata apply (undo=$undo) preserves source', (tester) async {
      final input = guideBundle();
      PortableCapture? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureEditor(
            initial: input,
            files: GuideFiles(),
            onCommit: (value) async => saved = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await menu(tester, 'capture-project-details');
      await tester.enterText(
        find.byKey(const Key('capture-project-tags')),
        'work\nreview',
      );
      await tester.tap(find.byKey(const Key('capture-project-details-apply')));
      await tester.pumpAndSettle();
      if (undo) await guidePress(tester, find.byTooltip('Undo'));
      await guidePress(tester, find.byKey(const Key('capture-save')));
      await guideSettle(tester);
      expect(saved!.project.tags, undo ? [] : ['work', 'review']);
      expect(saved!.project.id, input.project.id);
      expect(
        saved!.project.steps.map((s) => s.toJson()).toList(),
        input.project.steps.map((s) => s.toJson()).toList(),
      );
      expect(input.project.tags, isEmpty);
    });
    testWidgets('repeated mask (undo=$undo) is confirmed and atomic', (
      tester,
    ) async {
      final input = guideBundle();
      PortableCapture? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureEditor(
            initial: input,
            files: GuideFiles(),
            onCommit: (value) async => saved = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await guidePress(tester, find.byKey(const ValueKey('layer-mask')));
      await guidePress(tester, find.byKey(const Key('capture-repeat-mask')));
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      await guidePress(tester, find.byKey(const Key('capture-repeat-mask')));
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      if (undo) await guidePress(tester, find.byTooltip('Undo'));
      await guidePress(tester, find.byKey(const Key('capture-save')));
      await guideSettle(tester);
      expect(input.project.steps[1].annotations, isEmpty);
      if (undo) {
        expect(saved!.project.steps[1].annotations, isEmpty);
        return;
      }
      final mask = saved!.project.steps[1].annotations.single;
      expect(mask.kind, 'redact');
      expect(
        mask.geometry.toJson(),
        input.project.steps[0].annotations.single.geometry.toJson(),
      );
      expect(mask.color, '#000000');
      expect(mask.text, isEmpty);
    });
  }
  testWidgets(
    'pending save ignores canvas edits and a failure preserves the draft',
    (tester) async {
      final input = guideBundle(), gate = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureEditor(
            initial: input,
            files: GuideFiles(),
            onCommit: (_) => gate.future,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('layer-mask')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('capture-save')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('layer-mask'))),
        const Offset(50, 30),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final canvas = tester.widget<AnnotationCanvas>(
        find.byType(AnnotationCanvas),
      );
      expect(
        canvas.step.annotations.single.geometry.toJson(),
        input.project.steps.first.annotations.single.geometry.toJson(),
      );
      gate.completeError(StateError('Disk full'));
      await guideSettle(tester);
      expect(find.byType(CaptureEditor), findsOneWidget);
      await guideReveal(
        tester,
        find.textContaining('editor draft was preserved'),
      );
      expect(find.textContaining('editor draft was preserved'), findsOneWidget);
    },
  );
  testWidgets(
    'metadata cancel and oversized tags keep the dialog and saved source intact',
    (tester) async {
      final input = guideBundle();
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureEditor(
            initial: input,
            files: GuideFiles(),
            onCommit: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await menu(tester, 'capture-project-details');
      await tester.enterText(
        find.byKey(const Key('capture-project-tags')),
        List.filled(33, 'tag').join('\n'),
      );
      await tester.tap(find.byKey(const Key('capture-project-details-apply')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Check tag limits'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(input.project.tags, isEmpty);
    },
  );
  testWidgets('bounded renderer preserves opaque masks in reduced output', (
    tester,
  ) async {
    final step = guideBundle().project.steps.first;
    final bytes = await tester.runAsync(
      () => flattenAnnotation(step, png(), maxWidth: 50, maxHeight: 50),
    );
    final raster = decodeBoundedImage(bytes!);
    expect((raster.width, raster.height), (50, 50));
    expect(raster.rgba.sublist((20 * 50 + 20) * 4, (20 * 50 + 20) * 4 + 4), [
      0,
      0,
      0,
      255,
    ]);
    await expectLater(
      flattenAnnotation(step, png(), maxWidth: 0),
      throwsFormatException,
    );
  });
  testWidgets(
    'Markdown UI exports reviewed source without committing the project',
    (tester) async {
      final input = guideBundle(), files = GuideFiles();
      var commits = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureEditor(
            initial: input,
            files: files,
            onCommit: (_) async {
              commits++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await guidePress(tester, find.byKey(const Key('guide-export-options')));
      await guidePress(tester, find.byKey(const Key('guide-export-md')));
      expect(find.text('Review before sharing'), findsOneWidget);
      await tester.tap(find.byKey(const Key('guide-review-confirm')));
      await guideSettle(tester);
      expect(
        utf8.decode(files.outputs['handy-media-guide.md']!),
        contains('## 2. Step'),
      );
      expect(commits, 0);
    },
  );
  testWidgets(
    'review cancel, canceled file provider and export failure preserve the editor source',
    (tester) async {
      final files = GuideFiles(), input = guideBundle();
      var commits = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: CaptureEditor(
            initial: input,
            files: files,
            onCommit: (_) async {
              commits++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await guidePress(tester, find.byKey(const Key('guide-export-options')));
      await guidePress(tester, find.byKey(const Key('guide-export-html')));
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(files.outputs, isEmpty);
      files.cancel = true;
      await guidePress(tester, find.byKey(const Key('guide-export-options')));
      await guidePress(tester, find.byKey(const Key('guide-export-md')));
      await tester.tap(find.byKey(const Key('guide-review-confirm')));
      await guideSettle(tester);
      expect(find.text('Export canceled'), findsOneWidget);
      expect(files.outputs, isEmpty);
      files.cancel = false;
      files.fail = true;
      await guidePress(tester, find.byKey(const Key('guide-export-options')));
      await guidePress(tester, find.byKey(const Key('guide-export-md')));
      await tester.tap(find.byKey(const Key('guide-review-confirm')));
      await guideSettle(tester);
      expect(find.textContaining('editor draft was preserved'), findsOneWidget);
      expect(commits, 0);
      expect(input.project.steps.length, 2);
    },
  );
  testWidgets('GIF export: options, review, then a frame per step with '
      'masks and caption bar painted in', (tester) async {
    final input = guideBundle(), files = GuideFiles();
    var commits = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: kitTheme,
        home: CaptureEditor(
          initial: input,
          files: files,
          onCommit: (_) async {
            commits++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Dismissing the options makes nothing.
    await guidePress(tester, find.byKey(const Key('guide-export-options')));
    await guidePress(tester, find.byKey(const Key('guide-export-gif')));
    expect(find.byKey(const Key('gif-make')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Review before sharing'), findsNothing);
    expect(files.outputs, isEmpty);

    await guidePress(tester, find.byKey(const Key('guide-export-options')));
    await guidePress(tester, find.byKey(const Key('guide-export-gif')));
    expect(
      find.text('2 frames · 100 × 144 px · 4 s, then it starts again'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('1 s'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 s'));
    await tester.pumpAndSettle();
    expect(
      find.text('2 frames · 100 × 144 px · 2 s, then it starts again'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('gif-make')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gif-make')));
    await tester.pumpAndSettle();
    expect(find.text('Review before sharing'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-review-confirm')));
    await guideSettle(tester);
    final gif = img.decodeGif(files.outputs['handy-media-guide.gif']!)!;
    expect(gif.numFrames, 2);
    expect((gif.width, gif.height), (100, 144));
    final first = gif.frames.first;
    expect(first.frameDuration, 1000);
    // The opaque mask over 20%-60% of step 1 is painted in.
    expect([first.getPixel(40, 40).r, first.getPixel(40, 40).g], [0, 0]);
    // Step 2 has no mask: white there.
    expect(gif.frames[1].getPixel(40, 40).r, greaterThan(240));
    // The caption bar is near-black at the frame's foot.
    expect(first.getPixel(97, 141).r, lessThan(60));
    expect(commits, 0);
    expect(input.project.steps.first.annotations.single.kind, 'redact');
  });
}
