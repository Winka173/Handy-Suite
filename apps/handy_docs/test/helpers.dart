import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs/app.dart';
import 'package:handy_docs/capture.dart';
import 'package:handy_docs/pdf/pdf_desk.dart';
import 'package:handy_docs/sign/fill_controller.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';

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

/// A file picker and save dialog that remember what passed through them.
class Files implements HandyFiles, BatchHandyFiles {
  ImportedBytes? next;
  ImportedText? text;
  List<ImportedBytes> many = [];
  Uint8List? exported;
  String? name, mime;
  bool cancel = false, fail = false;

  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => next;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => text;
  @override
  Future<List<ImportedBytes>> importManyBytes({
    required List<String> extensions,
    int maxFiles = 50,
    int maxEachBytes = 20000000,
    int maxTotalBytes = 60000000,
    CancellationToken? cancellation,
  }) async => many;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    if (fail) throw StateError('Provider failed');
    if (cancel) return null;
    this.name = name;
    mime = mimeType;
    exported = Uint8List.fromList(bytes);
    return 'file:///exports/$name';
  }

  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async => exportBytes(
    name,
    Uint8List.fromList(utf8.encode(text)),
    mimeType: 'text/plain',
  );
}

class Camera implements ScanCamera {
  bool on = false;
  ImportedBytes? photo, lost;
  @override
  bool get supported => on;
  @override
  Future<ImportedBytes?> capture() async => photo;
  @override
  Future<ImportedBytes?> recover() async => lost;
}

class Prefs implements PreferencesRepository {
  HandyPreferences value = HandyPreferences(locale: 'en');
  bool fail = false;
  @override
  Future<HandyPreferences> load() async => value;
  @override
  Future<void> save(HandyPreferences next) async {
    if (fail) throw StateError('Disk full');
    value = next;
  }
}

/// Everything a Docs test may look into afterwards.
class Docs {
  final scan = Store(),
      markdown = Store(),
      reader = Store(),
      log = Store(),
      signatures = Store();
  final files = Files();
  final camera = Camera();
  final prefs = Prefs();
  late final history = ExportHistory('docs', documents: log);
}

Future<Docs> start(
  WidgetTester tester, {
  Docs? docs,
  Size size = const Size(800, 900),
  PdfDesk? desk,
  Future<FillSource> Function(Uint8List)? fill,
}) async {
  final d = docs ?? Docs();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    DocsApp(
      files: d.files,
      documents: d.scan,
      markdownDocuments: d.markdown,
      readerDocuments: d.reader,
      preferences: d.prefs,
      camera: d.camera,
      history: d.history,
      signatureDocuments: d.signatures,
      pdfDesk: desk,
      openFillSource: fill,
    ),
  );
  await tester.pumpAndSettle();
  return d;
}

/// Opens a place the way a link or a desk tile would.
Future<void> go(WidgetTester tester, String route) async {
  Navigator.of(
    tester.element(find.byKey(const Key('docs-desk'))),
  ).pushNamed(route);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    // Search the visible list from its top.
    final list = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .hitTestable()
        .first;
    tester.state<ScrollableState>(list).position.jumpTo(0);
    await tester.pumpAndSettle();
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(f, 200, scrollable: list);
    }
  }
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Picks [key] from whichever visible "More" menu holds it.
Future<void> menu(WidgetTester tester, String key) async {
  final menus = find.byKey(const Key('more-menu')).hitTestable();
  for (var i = menus.evaluate().length - 1; i >= 0; i--) {
    await tester.tap(menus.at(i));
    await tester.pumpAndSettle();
    final item = find.byKey(Key(key));
    if (item.evaluate().isNotEmpty) {
      await tester.tap(item);
      await tester.pumpAndSettle();
      return;
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }
  fail('No menu on screen holds $key');
}

Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

String sourceText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('markdown-source')))
    .controller!
    .text;
