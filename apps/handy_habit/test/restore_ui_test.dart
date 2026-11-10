import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_core/sealed.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'ui_test.dart' as fixtures;
import 'safety_fonts.dart';

class RestoreFiles implements HandyFiles {
  ImportedBytes? file;
  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => file;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async => null;
}

Future<void> openImport(
  WidgetTester tester,
  HabitController c,
  RestoreFiles files,
) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('restore-capture'),
      child: HabitApp(
        controller: c,
        files: files,
        clock: () => DateTime.utc(2024, 1, 8, 12),
      ),
    ),
  );
  await tester.pumpAndSettle();
  Navigator.of(
    tester.element(find.byType(Scaffold).first),
  ).pushNamed('/settings');
  await tester.pumpAndSettle();
  await fixtures.tapKey(tester, 'habit-import');
}

Future<void> waitForCrypto(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (find.byKey(const Key('password-error')).evaluate().isNotEmpty ||
        find.byKey(const Key('import-cancel')).evaluate().isNotEmpty)
      return;
  }
  fail('Password task did not finish');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadSafetyFonts);
  for (final width in [320.0, 1440.0]) {
    for (final locale in ['en', 'vi']) {
      for (final theme in ['light', 'dark']) {
        testWidgets('preview $width $locale $theme fits with large text', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.5;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final store = fixtures.MemoryStore()
            ..value = fixtures.seeded().copy({
              'settings': {'onboarded': true, 'locale': locale, 'theme': theme},
            });
          final c = HabitController(open: () async => store);
          await c.load();
          final files = RestoreFiles()
            ..file = ImportedBytes('backup.zip', backup(fixtures.seeded()));
          await openImport(tester, c, files);
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('import-cancel')), findsOneWidget);
          if (Platform.environment['HABIT_RUN2_SHOTS']
              case final String directory) {
            await tester.runAsync(() async {
              final render = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('restore-capture')),
              );
              final shot = await render.toImage();
              final bytes = await shot.toByteData(format: ImageByteFormat.png);
              final file = File(
                '$directory/preview-${width.toInt()}-$locale-$theme.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              shot.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
          c.dispose();
        });
      }
    }
  }
  testWidgets(
    'restore preview gives size/date/schema/trash; cancel and stale merge preserve data',
    (tester) async {
      final store = fixtures.MemoryStore()..value = fixtures.seeded();
      final c = HabitController(open: () async => store);
      await c.load();
      final files = RestoreFiles()
        ..file = ImportedBytes('old.zip', backup(fixtures.seeded()));
      await openImport(tester, c, files);
      expect(find.textContaining('bytes · Schema 3'), findsOneWidget);
      expect(find.textContaining('items in Trash'), findsOneWidget);
      final saved = c.state!.toJson();
      await fixtures.tapKey(tester, 'import-cancel');
      expect(c.state!.toJson(), saved);
      await fixtures.tapKey(tester, 'habit-import');
      await c.change(
        (s) => s.copy({
          'settings': {...s.settings, 'theme': 'dark'},
        }),
      );
      final newer = c.state!.toJson();
      await fixtures.tapKey(tester, 'import-merge');
      expect(c.state!.toJson(), newer);
      expect(find.textContaining('Nothing changed.'), findsOneWidget);
    },
  );
  for (final scenario in ['wrong password', 'tamper', 'opened']) {
    final tamper = scenario == 'tamper', opened = scenario == 'opened';
    testWidgets('sealed $scenario and cancel preserve local data', (
      tester,
    ) async {
      final sealed = await tester.runAsync(() async {
        final key = await SealKey.create('correct password', iterations: 10000);
        return seal(backup(fixtures.seeded()), key);
      });
      if (tamper) sealed![sealed.length - 1] ^= 1;
      final files = RestoreFiles()
        ..file = ImportedBytes('automatic.hseal', sealed!);
      final store = fixtures.MemoryStore()..value = fixtures.seeded();
      final c = HabitController(open: () async => store);
      await c.load();
      final saved = c.state!.toJson();
      await openImport(tester, c, files);
      await tester.enterText(
        find.byKey(const Key('password-first')),
        tamper || opened ? 'correct password' : 'wrong password',
      );
      await tester.tap(find.byKey(const Key('password-ok')));
      await tester.pump();
      await waitForCrypto(tester);
      if (opened) {
        expect(find.byKey(const Key('import-cancel')), findsOneWidget);
      } else {
        expect(
          find.text(tamper ? 'The file is damaged.' : 'Wrong password.'),
          findsOneWidget,
        );
      }
      expect(c.state!.toJson(), saved);
      await fixtures.tapKey(
        tester,
        opened ? 'import-cancel' : 'password-cancel',
      );
      expect(c.state!.toJson(), saved);
    });
  }
}
