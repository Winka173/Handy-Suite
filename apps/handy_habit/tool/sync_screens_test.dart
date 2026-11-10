// Host-rendered real widgets; no devices, OAuth or network.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit/design/identity.dart';
import 'package:handy_habit/design/theme.dart';
import 'package:handy_habit/reminders.dart';
import 'package:handy_habit/run_notice.dart';
import 'package:handy_habit/sync/drive_sync.dart';
import 'package:handy_habit/sync/sync_page.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../test/drive_sync_test.dart' as fixture;
import '../test/ui_test.dart' show MemoryStore;

final boundary = GlobalKey();
Future<void> shot(WidgetTester t, String name) async {
  await t.pump();
  final root = Platform.environment['SHOTS_DIR'] ?? 'build/run9-sync-shots';
  await t.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bitmap = await render.toImage(pixelRatio: 1.5);
    final png = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$root/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    bitmap.dispose();
  });
}

Future<void> fonts() async {
  final loader = FontLoader('Nunito');
  for (final f in Directory(
    'fonts',
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
    loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.view(
          File(
            r'C:/Users/Winka/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ).readAsBytesSync().buffer,
        ),
      ),
    );
  await icons.load();
}

void main() {
  setUpAll(fonts);
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final locale in ['en', 'vi']) {
      for (final theme in ['light', 'dark']) {
        for (final scale in [1.0, 1.5]) {
          testWidgets('sync matrix $width $locale $theme $scale', (t) async {
            t.view.physicalSize = Size(width, width == 1440 ? 1000 : 844);
            t.view.devicePixelRatio = 1;
            t.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetDevicePixelRatio);
            addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
            for (final state in [
              DriveSyncState.off,
              DriveSyncState.connecting,
              DriveSyncState.synced,
              DriveSyncState.pending,
              DriveSyncState.error,
              DriveSyncState.newerRemote,
            ]) {
              final store = MemoryStore()
                ..value = prepareHabitSync(fixture.seeded());
              final c = HabitController(
                open: () async => store,
                clock: () => fixture.now,
              );
              await c.load();
              final metadata = MemorySyncMetadata()
                ..data = {
                  'enabled': ![
                    DriveSyncState.off,
                    DriveSyncState.connecting,
                  ].contains(state),
                  'device': 'render',
                  'account': state == DriveSyncState.off
                      ? null
                      : 'linh.habit@example.test',
                  'lastSync':
                      state == DriveSyncState.off ||
                          state == DriveSyncState.connecting
                      ? null
                      : fixture.now.toIso8601String(),
                  'activity': state == DriveSyncState.off
                      ? <String>[]
                      : [fixture.now.toIso8601String()],
                  'base': state == DriveSyncState.synced
                      ? store.value.operations.map((o) => o.toJson()).toList()
                      : <dynamic>[],
                };
              final drive = HabitDriveSync(
                c,
                metadata: metadata,
                provider: () => MemoryHabitSyncProvider(),
                authorize: () async => false,
              );
              await drive.initialize();
              drive.state = state;
              drive.errorCode = state == DriveSyncState.error
                  ? 'offline'
                  : state == DriveSyncState.newerRemote
                  ? 'newer'
                  : null;
              final scope = HabitScope(
                controller: c,
                files: const SystemHandyFiles(),
                reminders: HabitReminders(),
                notices: HabitRunNotices(),
                clock: () => fixture.now,
                drive: drive,
              );
              await t.pumpWidget(
                RepaintBoundary(
                  key: boundary,
                  child: HandyApp(
                    app: 'habit',
                    title: 'Handy Habit',
                    accent: habitAccent,
                    brand: habitIdentity,
                    themeOverride: habitTheme,
                    theme: theme,
                    locale: locale,
                    home: HabitSyncPage(scope: scope),
                  ),
                ),
              );
              await t.pumpAndSettle();
              final name =
                  '${width.toInt()}-$locale-$theme-${(scale * 100).toInt()}-${state.name}';
              await shot(t, '$name-top');
              expect(t.takeException(), isNull);
              final scroll = find.byKey(const Key('sync-scroll'));
              await t.drag(scroll, const Offset(0, -600));
              await t.pumpAndSettle();
              await shot(t, '$name-detail');
              expect(t.takeException(), isNull);
              await Scrollable.ensureVisible(
                t.element(find.byKey(const Key('sync-privacy'))),
                alignment: 1,
              );
              await t.pumpAndSettle();
              await shot(t, '$name-privacy');
              expect(t.takeException(), isNull);
              await t.pumpWidget(const SizedBox());
              drive.dispose();
              scope.dispose();
              c.dispose();
            }
          });
        }
      }
    }
  }
}
