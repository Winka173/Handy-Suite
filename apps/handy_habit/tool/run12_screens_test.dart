// Real host raster output with synthetic test-store states. No store/device claim.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_store/handy_store.dart';
import 'package:handy_ui/kit.dart';
import '../test/pro_test.dart' as f;
import '../test/run3_ui_test.dart' as host;
import 'run10_screens_test.dart' show fonts;

final root = GlobalKey();
Future<void> shot(WidgetTester t, String name) async {
  if (name.contains('-pro-') &&
      !name.endsWith('-pro-overview') &&
      !name.endsWith('-settings-pro')) {
    await purchaseVisible(t);
  }
  await t.pump(const Duration(milliseconds: 500));
  await t.runAsync(() async {
    final boundary =
        root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final im = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
    final out = Platform.environment['SHOTS_DIR'] ?? 'build/run12/round1';
    Directory(out).createSync(recursive: true);
    File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    im.dispose();
  });
  expect(t.takeException(), isNull, reason: name);
}

Future<void> purchaseVisible(WidgetTester t) async {
  await t.ensureVisible(find.byKey(const Key('pro-purchase')));
  await t.pump(const Duration(milliseconds: 300));
}

void rasterTest(String name, WidgetTesterCallback body) =>
    testWidgets(name, (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await body(t);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

void main() {
  setUpAll(fonts);

  for (final width in [320.0, 390.0, 1440.0]) {
    for (final locale in ['en', 'vi']) {
      for (final theme in ['light', 'dark']) {
        for (final scale in [1.0, 1.5]) {
          rasterTest('run12 $width $locale $theme $scale', (t) async {
            final (_, store, fake) = await f.bootPro(
              t,
              open: false,
              boundary: root,
              width: width,
              locale: locale,
              theme: theme,
              scale: scale,
            );
            final stem =
                '${width.toInt()}-$locale-$theme-${scale == 1 ? 100 : 150}';
            await t.runAsync(
              () => precacheImage(
                const AssetImage('assets/icon.png'),
                root.currentContext!,
              ),
            );
            await shot(t, '$stem-today');
            await host.go(t, '/help');
            await shot(t, '$stem-help');
            await host.go(t, '/pro');
            await shot(t, '$stem-pro-overview');
            await purchaseVisible(t);
            await shot(t, '$stem-pro-price');
            fake.gate = Completer<StoreSnapshot>();
            unawaited(store.action('read'));
            await shot(t, '$stem-pro-loading');
            fake.gate!.complete(fake.value);
            fake.gate = null;
            await t.pumpAndSettle();
            for (final (status, reason) in [
              ('pending', ''),
              ('owned', ''),
              ('canceled', ''),
              ('error', 'verification_failed'),
              ('unavailable', 'store_unavailable'),
            ]) {
              store.accept(
                f.FakeHabitStore.snapshot(
                  status,
                  pro: status == 'owned',
                  reason: reason,
                  price: status == 'pending' ? '99.000 đ' : null,
                ),
              );
              await shot(t, '$stem-pro-$status');
            }
            store.accept(f.FakeHabitStore.snapshot('ready', price: '99.000 đ'));
            fake.gate = Completer<StoreSnapshot>();
            await t.ensureVisible(find.byKey(const Key('pro-restore')));
            await t.tap(find.byKey(const Key('pro-restore')));
            await shot(t, '$stem-pro-restore');
            fake.gate!.complete(fake.value);
            fake.gate = null;
            await t.pumpAndSettle();
            await shot(t, '$stem-pro-not-found');
            store.accept(f.FakeHabitStore.snapshot('unavailable', pro: true));
            await shot(t, '$stem-pro-offline-owned');
            store.accept(f.FakeHabitStore.snapshot('ready'));
            debugDefaultTargetPlatformOverride = TargetPlatform.windows;
            // accept rebuilds the inherited scope after the platform switch.
            store.accept(fake.value);
            await shot(t, '$stem-pro-unsupported');
            debugDefaultTargetPlatformOverride = TargetPlatform.android;
            store.accept(fake.value);
            await host.go(t, '/settings');
            final pro = find.byKey(const Key('settings-pro'));
            await t.scrollUntilVisible(
              pro,
              500,
              scrollable: find.byType(Scrollable).last,
            );
            await t.ensureVisible(pro);
            await shot(t, '$stem-settings-pro');
          });
        }
      }
    }
  }
}
