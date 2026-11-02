import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media/annotation_canvas.dart';
import 'package:handy_media/capture_draft.dart';
import 'package:handy_media/capture_library.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'capture_test.dart' show Store, bundle;
import 'helpers.dart';
import 'quick_tools_test.dart' show Files, png;

ProjectStep step(WidgetTester tester) =>
    tester.widget<AnnotationCanvas>(find.byType(AnnotationCanvas)).step;

// Decorative WidgetSpans must not become part of the guide's title assertion.
Finder guideTitle(String title) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.data ??
              widget.textSpan?.toPlainText(includePlaceholders: false)) ==
          title,
);

void main() {
  testWidgets(
    'a new guide opens the picker; leaving without saving leaves no empty guide',
    (tester) async {
      final store = Store()..text = CaptureLibrary([bundle()]).serialize();
      final files = Files()..next = ImportedBytes('First.png', png());
      final drafts = <String, DocumentRepository>{};
      await start(tester, documents: store, files: files, drafts: drafts);
      expect(guideTitle('Project'), findsOneWidget);
      await tapKey(tester, 'capture-new');
      // The picker opened by itself and its picture is step 1.
      expect(step(tester).title, 'First.png');
      expect(CaptureLibrary.parse(store.text!).projects, hasLength(2));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved edits?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('media-studio')), findsOneWidget);
      expect(
        CaptureLibrary.parse(store.text!).projects.single.project.id,
        'fixture',
      );
    },
  );

  testWidgets('a saved new guide is listed first with its steps as film', (
    tester,
  ) async {
    final store = Store()..text = CaptureLibrary([bundle()]).serialize();
    final files = Files()..next = ImportedBytes('First.png', png());
    await start(tester, documents: store, files: files, drafts: {});
    await tapKey(tester, 'capture-new');
    await tester.enterText(find.byKey(const Key('capture-title')), 'Nộp đơn');
    await tester.pumpAndSettle();
    await tapKey(tester, 'capture-save');
    expect(find.byKey(const Key('media-studio')), findsOneWidget);
    final guides = CaptureLibrary.parse(store.text!).projects;
    expect(guides.last.project.title, 'Nộp đơn');
    expect(
      tester.getTopLeft(guideTitle('Nộp đơn')).dy,
      lessThan(tester.getTopLeft(guideTitle('Project')).dy),
    );
  });

  testWidgets('deleting a guide asks first and clears its draft copy', (
    tester,
  ) async {
    final store = Store()..text = CaptureLibrary([bundle()]).serialize();
    final drafts = <String, DocumentRepository>{};
    final draft = Memory();
    drafts['fixture'] = draft;
    draft.text = CaptureLibrary([bundle()]).serialize();
    await start(tester, documents: store, files: Files(), drafts: drafts);
    await menu(tester, 'guide-delete-fixture');
    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();
    expect(CaptureLibrary.parse(store.text!).projects, hasLength(1));
    await menu(tester, 'guide-delete-fixture');
    await tester.tap(find.byKey(const Key('confirm-action')));
    await tester.pumpAndSettle();
    expect(CaptureLibrary.parse(store.text!).projects, isEmpty);
    expect(await CaptureDraft(draft, 'fixture').load(), isNull);
  });

  testWidgets('a draft from last time is offered back, or left alone', (
    tester,
  ) async {
    final store = Store()..text = CaptureLibrary([bundle()]).serialize();
    final draft = Memory();
    final edited = bundle();
    draft.text = CaptureLibrary([
      PortableCapture(
        edited.project.copyWith(title: 'Unsaved name'),
        edited.assets,
      ),
    ]).serialize();
    await start(
      tester,
      documents: store,
      files: Files(),
      drafts: {'fixture': draft},
    );
    await tapKey(tester, 'guide-fixture');
    expect(find.text('Pick up where you left off?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media-studio')), findsOneWidget);
    expect(draft.text, isNotNull);
    await tapKey(tester, 'guide-fixture');
    await tester.tap(find.byKey(const Key('draft-restore')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('capture-title')))
          .controller!
          .text,
      'Unsaved name',
    );
    expect(
      CaptureLibrary.parse(store.text!).projects.single.project.title,
      'Project',
    );
  });

  testWidgets(
    'a tool draws by dragging; keys undo, delete and leave typing alone',
    (tester) async {
      final store = Store()..text = CaptureLibrary([bundle()]).serialize();
      await start(tester, documents: store, files: Files(), drafts: {});
      await tapKey(tester, 'guide-fixture');
      expect(step(tester).annotations, hasLength(1));
      await tester.tap(find.byKey(const Key('capture-tool-rect')));
      await tester.pumpAndSettle();
      final area = tester.getRect(find.byKey(const Key('capture-shape-input')));
      await tester.dragFrom(
        area.topLeft + const Offset(10, 10),
        const Offset(200, 120),
      );
      await tester.pumpAndSettle();
      expect(step(tester).annotations, hasLength(2));
      final drawn = step(tester).annotations.last;
      expect(drawn.kind, 'rect');
      expect(drawn.geometry.width, greaterThan(.1));
      // The new note is chosen and the tool goes back to pick.
      expect(find.byKey(const Key('capture-shape-input')), findsNothing);
      expect(find.byKey(const Key('capture-layer-remove')), findsOneWidget);
      await tester.tap(find.byKey(const Key('capture-color-#2563EB')));
      await tester.pumpAndSettle();
      expect(step(tester).annotations.last.color, '#2563EB');
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(step(tester).annotations, hasLength(1));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(step(tester).annotations, hasLength(2));
      // Delete in a text field deletes text, not the note.
      await tester.ensureVisible(find.byKey(const Key('capture-step-title')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('capture-step-title')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(step(tester).annotations, hasLength(2));
    },
  );

  testWidgets('the quick tools open from the studio', (tester) async {
    await start(tester, documents: Store(), files: Files(), drafts: {});
    expect(
      find.textContaining('Turn screenshots into numbered steps'),
      findsOneWidget,
    );
    await tapKey(tester, 'studio-image');
    expect(find.text('Open the pictures to fix'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // Subtitles moved to Handy Tools: no entry here.
    expect(find.byKey(const Key('studio-subtitles')), findsNothing);
  });

  testWidgets('clearing saved inputs removes the moved subtitle leftovers', (
    tester,
  ) async {
    final prefs = Prefs()
      ..value = HandyPreferences(
        locale: 'en',
        favorites: ['subtitle-srt'],
        drafts: {'subtitle-vtt': 'WEBVTT'},
      );
    await start(
      tester,
      documents: Store(),
      files: Files(),
      drafts: {},
      prefs: prefs,
    );
    await go(tester, '/settings');
    await tapKey(tester, 'settings-clear-inputs');
    await tester.tap(find.byKey(const Key('confirm-action')));
    await tester.pumpAndSettle();
    expect(prefs.value.drafts, isEmpty);
    expect(prefs.value.favorites, isEmpty);
    expect(prefs.value.locale, 'en');
  });

  testWidgets('with nothing left over there is nothing to clear', (
    tester,
  ) async {
    await start(tester, documents: Store(), files: Files(), drafts: {});
    await go(tester, '/settings');
    expect(find.byKey(const Key('settings-clear-inputs')), findsNothing);
  });
}
