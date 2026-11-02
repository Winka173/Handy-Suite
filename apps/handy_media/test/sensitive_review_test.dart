import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media/annotation_canvas.dart';
import 'package:handy_media/capture_editor.dart';
import 'package:handy_media/guide/text_reader.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import 'guide_export_test.dart' show GuideFiles, guideBundle, guidePress;
import 'helpers.dart' show kitTheme;

/// Reads the same words from any picture, as a recogniser would.
class FakeReader implements TextReader {
  List<OcrLine> lines;
  bool available;
  int reads = 0;
  FakeReader(this.lines, {this.available = true});
  @override
  bool get supported => available;
  @override
  Future<List<OcrLine>> read(
    Uint8List png, {
    CancellationToken? cancellation,
  }) async {
    reads++;
    return lines;
  }
}

const words = [
  OcrLine(
    'Email: lan@x.vn',
    OcrBox(5, 70, 90, 8),
    words: [
      OcrWord('Email:', OcrBox(5, 70, 30, 8)),
      OcrWord('lan@x.vn', OcrBox(40, 70, 55, 8)),
    ],
  ),
  OcrLine('OTP 482913', OcrBox(5, 85, 60, 8)),
  // Under the guide's existing mask: already hidden, not proposed.
  OcrLine('0901234567', OcrBox(30, 30, 20, 8)),
];

ProjectStep shown(WidgetTester tester) =>
    tester.widget<AnnotationCanvas>(find.byType(AnnotationCanvas)).step;

Future<List<PortableCapture>> open(
  WidgetTester tester,
  TextReader reader,
) async {
  final saved = <PortableCapture>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: kitTheme,
      home: CaptureEditor(
        key: UniqueKey(),
        initial: guideBundle(),
        files: GuideFiles(),
        reader: reader,
        onCommit: (b) async => saved.add(b),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  testWidgets('found places are proposed, reviewed one by one, and only '
      'hidden when chosen', (tester) async {
    final reader = FakeReader(words);
    final saved = await open(tester, reader);
    await guidePress(tester, find.byKey(const Key('capture-find-sensitive')));
    await tester.pumpAndSettle();
    expect(reader.reads, 1);
    expect(find.byKey(const Key('sensitive-review')), findsOneWidget);
    expect(find.text('2 places to hide?'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('One-time code'), findsOneWidget);
    // The list shows a hint, never the value.
    expect(find.text('l…n'), findsOneWidget);
    expect(find.textContaining('482913'), findsNothing);
    // The picture shows the proposals; the guide itself is untouched.
    expect(shown(tester).annotations, hasLength(3));
    final state = tester.state<CaptureEditorState>(find.byType(CaptureEditor));
    expect(state.c.project.steps.first.annotations, hasLength(1));
    expect(state.c.dirty, isFalse);
    // Drop the code, keep the email.
    await guidePress(tester, find.byKey(const Key('sensitive-row-1')));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 chosen'), findsOneWidget);
    expect(shown(tester).annotations.last.kind, 'rect');
    await tester.tap(find.byKey(const Key('sensitive-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sensitive-review')), findsNothing);
    final layers = state.c.project.steps.first.annotations;
    expect(layers, hasLength(2));
    expect(layers.last.kind, 'redact');
    expect(layers.last.color, '#000000');
    expect(layers.last.geometry.y, closeTo((70 - 2) / 100, 1e-9));
    expect(find.text('1 place hidden. Undo brings it back.'), findsOneWidget);
    // One undo takes it back.
    await guidePress(tester, find.byTooltip('Undo'));
    expect(state.c.project.steps.first.annotations, hasLength(1));
    expect(saved, isEmpty);
  });

  testWidgets('cancel and Escape leave the step as it was', (tester) async {
    await open(tester, FakeReader(words));
    final state = tester.state<CaptureEditorState>(find.byType(CaptureEditor));
    await guidePress(tester, find.byKey(const Key('capture-find-sensitive')));
    await tester.pumpAndSettle();
    // Choose none: nothing to hide.
    await guidePress(tester, find.byKey(const Key('sensitive-all')));
    expect(
      tester
          .widget<ButtonStyleButton>(find.byKey(const Key('sensitive-apply')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('sensitive-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sensitive-review')), findsNothing);
    expect(state.c.project.steps.first.annotations, hasLength(1));
    expect(shown(tester).annotations, hasLength(1));
    await guidePress(tester, find.byKey(const Key('capture-find-sensitive')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sensitive-review')), findsNothing);
    expect(state.c.project.steps.first.annotations, hasLength(1));
    expect(state.c.dirty, isFalse);
  });

  testWidgets('nothing found says so; no reader hides the action', (
    tester,
  ) async {
    await open(
      tester,
      FakeReader([const OcrLine('Settings', OcrBox(0, 0, 50, 8))]),
    );
    await guidePress(tester, find.byKey(const Key('capture-find-sensitive')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sensitive-review')), findsNothing);
    expect(find.textContaining('Reading can miss words'), findsOneWidget);
    await open(tester, FakeReader(words, available: false));
    expect(find.byKey(const Key('capture-find-sensitive')), findsNothing);
    await open(tester, const NoTextReader());
    expect(find.byKey(const Key('capture-find-sensitive')), findsNothing);
  });
}
