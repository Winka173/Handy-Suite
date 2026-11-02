import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_spend/app.dart';
import 'package:handy_spend/controller.dart';
import 'package:handy_spend/privacy.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'controller_test.dart' show TestSpendStore;

export 'controller_test.dart' show TestSpendStore;

class Preferences implements PreferencesRepository {
  HandyPreferences value;
  Preferences([String locale = 'en'])
    : value = HandyPreferences(locale: locale);
  @override
  Future<HandyPreferences> load() async => value;
  @override
  Future<void> save(HandyPreferences next) async => value = next;
}

/// No device lock in widget tests.
class NoLock extends SpendPrivacy {
  @override
  bool get supported => false;
}

/// Files that keep what was exported and hand out the next import.
class Files implements HandyFiles {
  final output = <String, Uint8List>{};
  ImportedBytes? next;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    output[name.split('.').last] = bytes;
    return name;
  }

  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) => exportBytes(
    name,
    Uint8List.fromList(utf8.encode(text)),
    mimeType: 'text/plain',
  );

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
  }) async => null;
}

/// A camera that hands out [next]; unsupported unless asked, so tests
/// meet the plain file picker by default.
class FakeCamera implements ScanCamera {
  @override
  final bool supported;
  ImportedBytes? next;
  FakeCamera({this.supported = false});
  @override
  Future<ImportedBytes?> capture() async => next;
  @override
  Future<ImportedBytes?> recover() async => null;
}

String today([String zone = 'Asia/Ho_Chi_Minh']) =>
    reportDay(DateTime.now().toUtc().toIso8601String(), zone);
String inDays(int n) => day(calendar(today()).add(Duration(days: n)));

/// A cash account holding [opening] VND since [since] days ago.
Account cash({int opening = 1000000, int since = 40, String id = 'cash'}) =>
    Account(
      id: id,
      name: id == 'cash' ? 'Cash' : id,
      currency: 'VND',
      opening: BigInt.from(opening),
      asOf: inDays(-since),
    );

/// Pumps the whole app on [store] and waits for the ledger to open.
Future<SpendController> start(
  WidgetTester tester, {
  TestSpendStore? store,
  Size size = const Size(420, 900),
  String locale = 'en',
  HandyFiles? files,
  double textScale = 1,
  ScanCamera? camera,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final c = SpendController(open: () async => store ?? TestSpendStore());
  await c.load();
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    SpendApp(
      controller: c,
      files: files ?? Files(),
      preferences: Preferences(locale),
      privacy: NoLock(),
      camera: camera ?? FakeCamera(),
      enableDrop: false,
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  return c;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  // A long list builds only what is near the screen.
  if (f.evaluate().isEmpty)
    await tester.scrollUntilVisible(
      f,
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .hitTestable()
          .first,
    );
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> typeKey(WidgetTester tester, String key, String text) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f.first);
  await tester.enterText(f.first, text);
  await tester.pumpAndSettle();
}

/// Runs real async work (isolates, file IO) until [done] or a few seconds.
Future<void> settleReal(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}
