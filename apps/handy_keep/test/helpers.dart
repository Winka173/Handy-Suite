import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_keep/app.dart';
import 'package:handy_notifications/controller.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart' show qrPng;
import 'package:handy_ui/kit.dart';
import 'package:timezone/timezone.dart' as tz;

class Store implements DocumentRepository {
  String? text;
  bool fail = false;
  Completer<void>? hold;
  @override
  Future<String?> load() async => text;
  @override
  Future<void> save(String value) async {
    await hold?.future;
    if (fail) throw Exception('write rejected');
    text = value;
  }
}

class Preferences implements PreferencesRepository {
  HandyPreferences value = HandyPreferences(locale: 'en');
  @override
  Future<HandyPreferences> load() async => value;
  @override
  Future<void> save(HandyPreferences next) async => value = next;
}

/// Files that record what was exported and hand out queued imports.
class Files implements HandyFiles {
  Uint8List? png;
  String? text;
  ImportedBytes? nextBytes;
  ImportedText? nextText;
  Completer<ImportedBytes?>? pending;
  bool fail = false, cancel = false;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async {
    if (fail) throw Exception('Disk unavailable');
    if (cancel) return null;
    this.text = text;
    return 'saved';
  }

  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    if (fail) throw Exception('Disk unavailable');
    if (cancel) return null;
    png = bytes;
    return 'saved';
  }

  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => pending != null ? await pending!.future : nextBytes;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => nextText;
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

class _Port implements NotificationsPort {
  @override
  Future<bool> allowed(bool request) async => true;
  @override
  Future<Map<int, String>> pending(String namespace) async => {};
  @override
  Future<void> schedule(String namespace, ReminderRequest request) async {}
  @override
  Future<void> cancel(int id) async {}
}

class _Settings implements ReminderSettingsStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

ReminderController testReminders() => ReminderController(
  'keep',
  port: _Port(),
  store: _Settings(),
  location: () async => tz.UTC,
);

/// A real PNG (a QR code), enough to pass the signature check and decode.
final pngBytes = qrPng('photo');

Future<void> start(
  WidgetTester tester, {
  Store? store,
  Files? files,
  Camera? camera,
  Preferences? prefs,
  Size size = const Size(420, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    KeepApp(
      documents: store ?? Store(),
      files: files ?? Files(),
      camera: camera ?? Camera(),
      preferences: prefs ?? Preferences(),
      reminders: testReminders(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapKey(
  WidgetTester tester,
  String key, {
  bool settle = true,
}) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  settle ? await tester.pumpAndSettle() : await tester.pump();
}
