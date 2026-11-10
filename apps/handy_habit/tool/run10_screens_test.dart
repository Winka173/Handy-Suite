// Host raster evidence, not browser/device evidence.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_store/handy_store.dart';
import '../test/run10_advanced_test.dart' as f;
import '../test/run4_routines_test.dart' as actions;

final root = GlobalKey();
Future<void> shot(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  await t.pump(const Duration(milliseconds: 400));
  await t.runAsync(() async {
    final boundary =
        root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final dir = Platform.environment['SHOTS_DIR'] ?? 'build/run10-shots';
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    picture.dispose();
  });
  expect(t.takeException(), isNull);
}

Future<void> fonts() async {
  Future<void> load(String family, Iterable<String> files) async {
    final font = FontLoader(family);
    for (final p in files)
      font.addFont(
        Future.value(ByteData.view(File(p).readAsBytesSync().buffer)),
      );
    await font.load();
  }

  await load(
    'Nunito',
    Directory('fonts')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.ttf'))
        .map((f) => f.path),
  );
  await load('MaterialIcons', [
    'C:/Users/Winka/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
}

HabitState fixture(String locale, String theme) {
  final vi = locale == 'vi';
  final base = f.advancedSeed();
  final r = base.routines.single;
  return base.copy({
    'settings': {...base.settings, 'locale': locale, 'theme': theme},
    'routines': [
      r.copy({
        'title': vi ? 'Một chút vận động' : 'A little movement',
        'steps': [
          r.steps[0].copy({
            'title': vi ? 'Đi bộ đến công viên' : 'Walk to the park',
          }).toJson(),
          r.steps[1].copy({
            'title': vi ? 'Giãn cơ nhẹ nhàng' : 'Stretch gently',
            'logic': {
              ...r.steps[1].logic.toJson(),
              'branch': vi ? 'Vận động' : 'Movement',
            },
          }).toJson(),
          r.steps[2].copy({
            'title': vi ? 'Đọc vài trang sách' : 'Read a few pages',
            'logic': {
              ...r.steps[2].logic.toJson(),
              'branch': vi ? 'Vận động' : 'Movement',
            },
          }).toJson(),
        ],
      }).toJson(),
    ],
  });
}

void main() {
  setUpAll(fonts);
  for (final width in [320.0, 390.0, 1440.0]) {
    for (final locale in ['en', 'vi']) {
      for (final theme in ['light', 'dark']) {
        for (final scale in [1.0, 1.5]) {
          testWidgets('run10 $width $locale $theme $scale', (t) async {
            t.view.physicalSize = Size(width, 900);
            t.view.devicePixelRatio = 1;
            t.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetDevicePixelRatio);
            addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
            final (_, entitlement) = await f.bootAdvanced(
              t,
              pro: false,
              state: fixture(locale, theme),
              boundary: root,
            );
            final stem =
                '${width.toInt()}-$locale-$theme-${scale == 1 ? '100' : '150'}';
            await actions.route(t, '/routine/r/edit');
            await shot(t, '$stem-builder-basic');
            await actions.tap(t, 'routine-advanced');
            await shot(t, '$stem-builder-advanced-free');
            await f.textTap(
              t,
              locale == 'vi' ? 'Nhóm bước dùng lại' : 'Reusable step blocks',
            );
            await shot(t, '$stem-pro-demo');
            entitlement.accept(
              StoreSnapshot(
                status: 'owned',
                productId: entitlement.config.productId,
                owned: true,
                verified: true,
              ),
            );
            await t.pumpAndSettle();
            await f.textTap(
              t,
              locale == 'vi' ? 'Nhóm bước dùng lại' : 'Reusable step blocks',
            );
            await shot(t, '$stem-builder-advanced');
            await actions.tap(t, 'draft-edit-weekday');
            await actions.tap(t, 'step-advanced');
            await f.textTap(
              t,
              locale == 'vi' ? 'Ngày thực hiện' : 'Days to run',
            );
            await Scrollable.ensureVisible(
              t.element(
                find
                    .text(locale == 'vi' ? 'Ngày thực hiện' : 'Days to run')
                    .first,
              ),
              alignment: .05,
            );
            await shot(t, '$stem-condition');
            await actions.tap(t, 'editor-save');
            await actions.tap(t, 'editor-save');
            await actions.route(t, '/routine/r');
            await actions.tap(t, 'routine-start');
            await shot(t, '$stem-branch');
            await actions.tap(t, 'branch-B');
            await actions.tap(t, 'routine-complete-step');
            await actions.tap(t, 'runner-finish');
            await shot(t, '$stem-summary');
          });
        }
      }
    }
  }
}
