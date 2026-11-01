import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs/corner_editor.dart';
import 'package:handy_docs/session.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';
import 'session_test.dart' show samplePng;

Future<Docs> scan(
  WidgetTester tester, [
  List<ScanPage> pages = const [],
]) async {
  final docs = Docs();
  if (pages.isNotEmpty) docs.scan.text = ScanSession(pages).serialize();
  await start(tester, docs: docs);
  await go(tester, '/scan');
  return docs;
}

List<ScanPage> saved(Docs docs) => ScanSession.parse(docs.scan.text!).pages;

void main() {
  testWidgets('a canceled picker and a broken picture leave the scan alone', (
    tester,
  ) async {
    final docs = await scan(tester, [ScanPage('old', 'Saved', samplePng())]);
    final original = docs.scan.text;
    await tapKey(tester, 'scan-import');
    expect(docs.scan.text, original);
    docs.files.next = ImportedBytes('broken.png', Uint8List(20));
    await tapKey(tester, 'scan-import');
    expect(docs.scan.text, original);
    expect(find.byType(CornerEditor), findsNothing);
  });

  testWidgets(
    'a failed page save keeps the editor and its corners; a retry saves and closes',
    (tester) async {
      final docs = await scan(tester);
      docs.scan.fail = true;
      docs.files.next = ImportedBytes('Page.png', samplePng());
      await tapKey(tester, 'scan-import');
      await tapKey(tester, 'save-scan-page');
      expect(find.byType(CornerEditor), findsOneWidget);
      expect(docs.scan.text, isNull);
      expect(docs.scan.attempts, 1);
      docs.scan.fail = false;
      await tapKey(tester, 'save-scan-page');
      expect(find.byType(CornerEditor), findsNothing);
      expect(saved(docs).single.name, 'Page.png');
      expect(find.text('1. Page.png'), findsOneWidget);
    },
  );

  testWidgets('pages move, delete after asking, and become one PDF', (
    tester,
  ) async {
    final docs = await scan(tester, [
      ScanPage('a', 'First', samplePng()),
      ScanPage('b', 'Second', samplePng()),
    ]);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('scan-page-a')),
        matching: find.byKey(const Key('more-menu')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move later'));
    await tester.pumpAndSettle();
    expect(saved(docs).map((p) => p.id), ['b', 'a']);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('scan-page-b')),
        matching: find.byKey(const Key('more-menu')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();
    expect(saved(docs), hasLength(2));
    await tapKey(tester, 'scan-export');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
    expect(docs.files.name, 'handy-docs-scan.pdf');
    expect(utf8.decode(docs.files.exported!.sublist(0, 5)), '%PDF-');
  });

  testWidgets('a restore asks first and refuses a damaged session', (
    tester,
  ) async {
    final docs = await scan(tester, [ScanPage('a', 'Kept', samplePng())]);
    final before = docs.scan.text;
    docs.files.next = ImportedBytes(
      'session.json',
      Uint8List.fromList(
        utf8.encode(
          ScanSession([
            ScanPage('x', 'One', samplePng()),
            ScanPage('y', 'Two', samplePng()),
          ]).serialize(),
        ),
      ),
    );
    await menu(tester, 'scan-restore');
    expect(find.text('Restore this scan?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();
    expect(docs.scan.text, before);
    docs.files.next = ImportedBytes('bad.json', Uint8List.fromList([1, 2]));
    await menu(tester, 'scan-restore');
    expect(docs.scan.text, before);
  });

  testWidgets('a photo taken while the app was closed is offered back', (
    tester,
  ) async {
    final docs = Docs()..camera.lost = ImportedBytes('lost.png', samplePng());
    await start(tester, docs: docs);
    await go(tester, '/scan');
    expect(
      find.text('A photo was taken while the app was closed.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(
      find.text('A photo was taken while the app was closed.'),
      findsNothing,
    );
    expect(docs.scan.text, isNull);
  });

  testWidgets('four corner drags move the geometry and stay inside', (
    tester,
  ) async {
    List<ScanPoint> corners = fullScanCorners();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: StatefulBuilder(
                builder: (context, setState) => CornerCanvas(
                  png: samplePng(),
                  ratio: 1,
                  corners: corners,
                  onChange: (v) => setState(() => corners = v),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(const ValueKey('scan-corner-0')),
      const Offset(40, 35),
    );
    await tester.pump();
    expect(corners.first.x, greaterThan(0));
    expect(corners.first.y, greaterThan(0));
    validateScanCorners(corners);
    await tester.drag(
      find.byKey(const ValueKey('scan-corner-0')),
      const Offset(-500, -500),
    );
    await tester.pump();
    expect(corners.first.x, 0);
    expect(corners.first.y, 0);
  });
}
