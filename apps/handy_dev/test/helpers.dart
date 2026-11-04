import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_dev/app.dart';
import 'package:handy_dev/http_transport.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';

class Files implements HandyFiles {
  String? next, output;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => next == null ? null : ImportedText('input.json', next!);
  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async {
    output = text;
    return 'file:///exports/$name';
  }

  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    output = String.fromCharCodes(bytes);
    return 'file:///exports/$name';
  }
}

class Store implements DocumentRepository {
  String? text;
  bool fail = false;
  @override
  Future<String?> load() async => text;
  @override
  Future<void> save(String value) async {
    if (fail) throw StateError('Disk full');
    text = value;
  }
}

class DevPreferences implements PreferencesRepository {
  HandyPreferences value = HandyPreferences();
  bool fail = false;
  @override
  Future<HandyPreferences> load() async => value;
  @override
  Future<void> save(HandyPreferences next) async {
    if (fail) throw StateError('Disk full');
    value = next;
  }
}

Future<void> start(
  WidgetTester tester, {
  DevPreferences? prefs,
  Files? files,
  Store? store,
  HttpTransport? transport,
  Store? history,
  Size size = const Size(420, 1100),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    DevApp(
      preferences: prefs ?? DevPreferences(),
      files: files ?? Files(),
      documents: store ?? Store(),
      transport: transport,
      history: history ?? Store(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> paste(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('dev-input')), text);
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await reveal(tester, f);
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> openRequests(WidgetTester tester) async {
  await tester.tap(find.text('Requests'));
  await tester.pumpAndSettle();
}

Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}
