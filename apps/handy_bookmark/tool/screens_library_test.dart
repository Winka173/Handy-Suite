// Review shots of the library screens (home, collections, results) across
// widths, themes and text sizes, for the Warm Modern Library redesign.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_library_test.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show Navigator, Scaffold;
import 'package:flutter/widgets.dart' show Key, Scrollable, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
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
    await _font('packages/handy_ui/Bricolage', [
      '$ui/BricolageGrotesque-Medium.ttf',
      '$ui/BricolageGrotesque-Display.ttf',
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
    await tapKey(t, 'home-library');
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

  // The Library page (2026-11-06): every place, the collections' tree, the
  // tags, and the kept smart collections and saved searches under Advanced.
  for (final (label, size, theme, scale) in [
    ('phone', const Size(390, 844), 'light', 1.0),
    ('phone-dark', const Size(390, 844), 'dark', 1.0),
    ('narrow-large-text', const Size(320, 640), 'light', 2.0),
  ]) {
    testWidgets('$label library page', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await boot(t, size, theme: theme, extras: true);
      await tapKey(t, 'home-library');
      await shot(t, 'lib-$label-library');
      await tapKey(t, 'library-advanced');
      await t.scrollUntilVisible(
        find.byKey(const Key('smart-new')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await shot(t, 'lib-$label-library-advanced');
    });
  }

  // Choosing a collection's cover from its own pictures.
  Future<void> pictured(SaveController c) => c.update(
    (l) => l.copyWith(
      bookmarks: [
        for (final b in l.bookmarks)
          b.copyWith(thumbnailUrl: 'https://img.example.com/${b.id}.jpg'),
      ],
    ),
  );
  for (final (label, size, theme, scale) in [
    ('phone', const Size(390, 844), 'light', 1.0),
    ('phone-dark', const Size(390, 844), 'dark', 1.0),
    ('narrow-large-text', const Size(320, 640), 'light', 2.0),
    ('desktop', const Size(1440, 900), 'light', 1.0),
  ]) {
    testWidgets('$label cover chooser', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final c = await boot(t, size, theme: theme);
      await pictured(c);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pumpAndSettle();
      await tapKey(t, 'collection-food');
      await tapKey(t, 'list-more');
      await tapKey(t, 'collection-cover');
      await shot(t, 'lib-$label-cover-chooser');
      final last = c.library!.bookmarks.lastWhere(
        (b) => b.collectionId == 'food',
      );
      await tapKey(t, 'cover-${last.id}');
      await shot(t, 'lib-$label-cover-chosen');
      if (size.width < 700) {
        Navigator.of(t.element(find.byType(Scaffold).last)).pop();
        await t.pumpAndSettle();
        await shot(t, 'lib-$label-cover-home');
      }
    });
  }

  for (final (label, size, theme) in [
    ('phone', const Size(390, 844), 'light'),
    ('phone-dark', const Size(390, 844), 'dark'),
  ]) {
    testWidgets('$label pro looks', (t) async {
      final c = await boot(t, size, theme: theme);
      final nav = Navigator.of(t.element(find.byKey(const Key('save-home'))));
      nav.pushNamed('/looks');
      await t.pumpAndSettle();
      await shot(t, 'pro-$label-looks');
      await tapKey(t, 'look-ink-paper');
      await shot(t, 'pro-$label-preview-ink');
      await tapKey(t, 'look-next');
      await shot(t, 'pro-$label-preview-midnight');
      await tapKey(t, 'look-keep');
      nav.pushNamed('/pro');
      await t.pumpAndSettle();
      await shot(t, 'pro-$label-explore');
      expect(c.preferences['look'], isNull);
    });
  }

  testWidgets('phone pro layouts', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'home-library');
    await tapKey(t, 'place-all');
    await tapKey(t, 'save-layout');
    await shot(t, 'pro-layouts-picker');
    await tapKey(t, 'layout-magazine');
    for (var i = 0; i < 8; i++) {
      await shot(t, 'pro-layout-$i');
      if (i < 7) await tapKey(t, 'layout-next');
    }
  });
}
