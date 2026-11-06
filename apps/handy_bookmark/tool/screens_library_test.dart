// Review shots of the library screens (home, collections, results) across
// widths, themes and text sizes, for the Warm Modern Library redesign.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_library_test.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Key, Size;
import 'package:flutter_test/flutter_test.dart';
import 'screens_test.dart' show boot, shot, tapKey;

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.view(File(p).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    const ui = '../../packages/handy_ui/fonts';
    await _font('packages/handy_ui/Geist', [
      '$ui/Geist-Regular.ttf',
      '$ui/Geist-Medium.ttf',
      '$ui/Geist-Bold.ttf',
    ]);
    final sdk = Platform.environment['FLUTTER_ROOT']!;
    await _font('Newsreader', [
      for (final f in Directory('fonts').listSync())
        if (f.path.endsWith('.ttf')) f.path,
    ]);
    await _font('MaterialIcons', [
      '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  for (final (label, size, theme, scale) in [
    ('narrow', const Size(320, 640), 'light', 1.0),
    ('narrow-dark', const Size(320, 640), 'dark', 1.0),
    ('phone-large-text', const Size(390, 844), 'light', 2.0),
  ]) {
    testWidgets('$label library', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await boot(t, size, theme: theme);
      await shot(t, 'lib-$label-home');
      await tapKey(t, 'collection-food');
      await shot(t, 'lib-$label-collection');
      await tapKey(t, 'save-view');
      await shot(t, 'lib-$label-gallery');
    });
  }

  for (final (label, size) in [
    ('phone-dark', const Size(390, 844)),
    ('tablet-dark', const Size(900, 1100)),
    ('desktop-dark', const Size(1440, 900)),
  ]) {
    testWidgets('$label library', (t) async {
      await boot(t, size, theme: 'dark');
      await shot(t, 'lib-$label-home');
    });
  }

  testWidgets('phone everything', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'place-all');
    await shot(t, 'lib-phone-everything');
  });
  testWidgets('phone search', (t) async {
    await boot(t, const Size(390, 844));
    await t.enterText(find.byKey(const Key('save-search')), 'bánh');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await t.pumpAndSettle();
    await shot(t, 'lib-phone-search');
    await t.enterText(find.byKey(const Key('save-search')), 'zzqy');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await t.pumpAndSettle();
    await shot(t, 'lib-phone-search-none');
  });
}
