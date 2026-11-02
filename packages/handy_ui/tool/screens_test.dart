// Review screenshots of the shared settings sections, with the real faces.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/sealed.dart';
import 'package:handy_files/auto_backup.dart';
import 'package:handy_ui/kit.dart';
import '../test/backup_test.dart' show MemoryFolders;

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.view(File(p).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

final _root = GlobalKey();

Future<void> shot(WidgetTester t, String name) async {
  final dir = Platform.environment['SHOTS_DIR'] ?? 'build/shots';
  Directory(dir).createSync(recursive: true);
  await t.pumpAndSettle();
  await t.runAsync(() async {
    final b =
        _root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> show(WidgetTester t, Size size, List<Widget> sections) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildHandyTheme(const Color(0xFFB7791F), Brightness.light),
        home: Scaffold(
          appBar: AppBar(title: const Text('Cài đặt')),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: sections,
          ),
        ),
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
}

HandyAutoBackup backup(AutoBackupSettings s, {bool web = false}) =>
    HandyAutoBackup(
      app: 'keep',
      extension: 'zip',
      build: () async => Uint8List(1),
      store: (_) async {},
      initial: s,
      folders: MemoryFolders()..web = web,
    );

void main() {
  setUpAll(() async {
    const fonts = 'fonts';
    await _font('packages/handy_ui/Geist', [
      '$fonts/Geist-Regular.ttf',
      '$fonts/Geist-Medium.ttf',
      '$fonts/Geist-Bold.ttf',
    ]);
    await _font('packages/handy_ui/Bricolage', [
      '$fonts/BricolageGrotesque-Medium.ttf',
      '$fonts/BricolageGrotesque-Display.ttf',
    ]);
    final sdk = Platform.environment['FLUTTER_ROOT']!;
    await _font('MaterialIcons', [
      '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('backup $label', (t) async {
      late SealKey key;
      await t.runAsync(
        () async => key = await SealKey.create('x', iterations: 10000),
      );
      const drive = BackupFolder('tree', 'content://x', 'Handy trên Drive');
      await show(t, size, [
        HandyAutoBackupSection(backup: backup(const AutoBackupSettings())),
      ]);
      await shot(t, 'kit-backup-empty-$label');
      await show(t, size, [
        HandyAutoBackupSection(
          backup: backup(
            AutoBackupSettings(
              enabled: true,
              folder: drive,
              seal: key,
              last: DateTime.now().subtract(const Duration(hours: 3)),
              lastName: 'handy-keep-2026-11-02-0930.zip.hseal',
            ),
          ),
        ),
        const HandyMoreApps(
          app: 'keep',
          listings: {
            'spend': 'https://example.org/spend',
            'habit': 'https://example.org/habit',
            'save': 'https://example.org/save',
          },
        ),
      ]);
      await shot(t, 'kit-backup-done-$label');
      await show(t, size, [
        HandyAutoBackupSection(
          backup: backup(
            AutoBackupSettings(
              enabled: true,
              folder: drive,
              last: DateTime(2026, 10, 28, 21, 4),
              lastName: 'handy-keep-2026-10-28-2104.zip',
              lastError: 'unreachable',
            ),
          ),
        ),
      ]);
      await shot(t, 'kit-backup-error-$label');
      await show(t, size, [
        HandyAutoBackupSection(
          backup: backup(const AutoBackupSettings(), web: true),
        ),
      ]);
      await shot(t, 'kit-backup-web-$label');
      t.view.reset();
    });
  }
}
