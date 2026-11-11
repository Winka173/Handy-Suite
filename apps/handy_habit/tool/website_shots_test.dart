// Website kit: the app's real screens as marketing stills, in Vietnamese and
// English, light and dark, phone (390×844 @3x) and desktop (1440×900 @2x).
// Real fonts and the same lived-in sample data as the store shots (no lorem
// ipsum); host renders of the real UI, not device recordings.
//
//   KIT_DIR=../../website-kit/handy-habit/screenshots [KIT_LANGS=vi,en] \
//     flutter test --no-pub --timeout 600s tool/website_shots_test.dart
//
// Files: `<form>-<lang>-<NN>-<scene>.png`, forms mobile, mobile-dark,
// desktop, desktop-dark; each scene number is the same screen everywhere.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../test/ui_test.dart' show MemoryStore, tapKey;
import 'store_shots_test.dart' show loadFonts, now, sample;

final _out = Platform.environment['KIT_DIR'] ?? 'build/website-kit';
final _langs = (Platform.environment['KIT_LANGS'] ?? 'vi,en').split(',');
final _root = GlobalKey();

enum Form {
  mobile('mobile', Size(390, 844), 3, 'light'),
  mobileDark('mobile-dark', Size(390, 844), 3, 'dark'),
  desktop('desktop', Size(1440, 900), 2, 'light'),
  desktopDark('desktop-dark', Size(1440, 900), 2, 'dark');

  final String label;
  final Size size;
  final double ratio;
  final String theme;
  const Form(this.label, this.size, this.ratio, this.theme);
}

Future<void> _save(WidgetTester t, Form form, String lang, String name) async {
  await t.pumpAndSettle();
  await t.pump(const Duration(milliseconds: 400));
  await t.runAsync(() async {
    final b =
        _root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: form.ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('$_out/${form.label.split('-').first}');
    dir.createSync(recursive: true);
    File(
      '$_out/${form.label.split('-').first}/${form.label}-$lang-$name.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(loadFonts);
  for (final lang in _langs)
    for (final form in Form.values)
      testWidgets('kit $lang ${form.label}', (t) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          t.view.physicalSize = form.size * form.ratio;
          t.view.devicePixelRatio = form.ratio;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final base = sample(lang);
          final disk = MemoryStore()
            ..value = base.copy({
              'settings': {
                ...base.settings,
                'theme': form.theme,
                'locale': lang,
                'onboarded': true,
              },
            });
          final c = HabitController(open: () async => disk, clock: () => now);
          await c.load();
          addTearDown(() async {
            await t.pumpWidget(const SizedBox());
            c.dispose();
          });
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await t.pumpWidget(
            RepaintBoundary(
              key: _root,
              child: HabitApp(controller: c, clock: () => now, device: false),
            ),
          );
          await t.pumpAndSettle();
          final nav = t.state<NavigatorState>(find.byType(Navigator).first);
          Future<void> open(String route) async {
            unawaited(nav.pushNamed(route));
            await t.pumpAndSettle();
          }

          Future<void> close() async {
            nav.pop();
            await t.pumpAndSettle();
          }

          Future<void> shot(String name) => _save(t, form, lang, name);
          // Let the mark decode before the first picture.
          await t.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 1)),
          );
          await t.pump();

          await shot('01-today');
          await open('/habit/read');
          await shot('02-habit');
          await close();
          await open('/habit/reduce');
          await shot('03-habit-reduce');
          await close();
          await open('/habits');
          await shot('04-habits');
          await close();
          await tapKey(t, 'today-new');
          await shot('05-quick-add');
          await tapKey(t, 'quick-add-templates');
          await shot('06-templates');
          await close();
          await open('/routines');
          await shot('07-routines');
          await close();
          await open('/routine/morning');
          await shot('08-routine');
          await tapKey(t, 'routine-start');
          if (find.byIcon(Icons.play_arrow).evaluate().isNotEmpty)
            await tapKey(t, 'routine-pause');
          await t.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 6)),
          );
          await t.pump(const Duration(milliseconds: 300));
          await shot('09-runner');
          await open('/progress');
          await shot('10-progress-month');
          await tapKey(t, 'range-year');
          await shot('11-progress-year');
          await tapKey(t, 'insights-week-review');
          await shot('12-week-review');
          await close();
          await open('/settings');
          await shot('20-settings');
          await open('/settings/notifications');
          await shot('21-notifications');
          await close();
          await open('/settings/preferences');
          await shot('22-defaults');
          await close();
          await open('/settings/widgets');
          await shot('23-widgets');
          await close();
          await open('/help');
          await shot('24-how-to');
          await open('/help/start');
          await shot('25-how-to-topic');
          await close();
          await open('/pro');
          await shot('30-pro');
          await open('/settings/studio');
          await shot('31-studio');
          await close();
          await open('/welcome');
          await shot('50-welcome-1');
          await tapKey(t, 'welcome-next');
          await shot('50-welcome-2');
          await tapKey(t, 'welcome-next');
          await shot('50-welcome-3');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
}
