import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/design/studio_style.dart';
import 'package:handy_habit/design/palette.dart';
import 'package:handy_habit/design/studio_page.dart';
import 'package:handy_habit/insights/smart_report.dart';
import 'package:handy_habit/insights/smart_review.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'pro_test.dart' as p;
import 'run3_ui_test.dart' as host;
import 'run4_routines_test.dart' show tap;
import 'contrast_test.dart' show contrast;
import 'package:pdf/pdf.dart' show TtfParser;

HabitState smartSeed() {
  final h = Habit(
    id: 'read',
    title: 'Read 6 pages',
    created: '2023-10-01',
    type: 'quantity',
    unit: 'pages',
    category: 'Learning',
    schedules: [Schedule(id: 's', from: '2023-10-01', target: 6000)],
  );
  return HabitState(
    habits: [h],
    settings: {
      'habitDayParts': {h.id: 'morning'},
    },
    events: [
      for (var i = 0; i < 99; i++)
        if (i % 10 != 1)
          HabitEvent(
            id: 'e$i',
            habit: h.id,
            day: addDays(h.created, i),
            value: 6000,
          ),
    ],
    moods: [
      for (var i = 0; i < 28; i++)
        MoodEntry(
          day: addDays('2023-12-11', i),
          mood: i % 10 == 1 ? 2 : 4,
          recordedAt: '2024-01-08T00:00:00Z',
        ),
    ],
  );
}

void main() {
  for (final locale in ['en', 'vi'])
    p.proTest('new screens use bundled Nunito glyphs $locale', (t) async {
      final (_, store, _) = await p.bootPro(
        t,
        open: false,
        state: smartSeed(),
        locale: locale,
      );
      store.accept(p.FakeHabitStore.snapshot('owned', pro: true));
      final strings = <String>[];
      for (final route in [
        '/progress/smart',
        '/settings/studio',
        '/pro?feature=reports',
        '/pro?feature=mood',
      ]) {
        await host.go(t, route);
        strings.addAll(
          t
              .widgetList<Text>(find.byType(Text))
              .map((w) => w.data ?? w.textSpan!.toPlainText()),
        );
      }
      for (final f in Directory(
        'fonts',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
        final cmap = TtfParser(
          f.readAsBytesSync().buffer.asByteData(),
        ).charToGlyphIndexMap;
        for (final s in strings)
          for (final rune in s.runes.where((r) => r > 32))
            expect(
              cmap[rune] ?? 0,
              isNot(0),
              reason: '${f.path} U+${rune.toRadixString(16)} in $s',
            );
      }
    });
  p.proTest('quiet runner and retained bead fallback use current entitlement', (
    t,
  ) async {
    final (_, store, _) = await p.bootPro(t, open: false);
    store.accept(p.FakeHabitStore.snapshot('owned', pro: true));
    await host.go(t, '/settings/studio');
    await tap(t, 'studio-runner-quiet');
    await tap(t, 'studio-apply');
    await host.go(t, '/routines');
    await tap(t, 'start-r');
    expect(find.byKey(const Key('runner-track')), findsNothing);
    store.accept(p.FakeHabitStore.snapshot('ready'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('runner-track')), findsOneWidget);
  });
  p.proTest(
    'failed studio write retains preview for retry and checks stale choices',
    (t) async {
      final disk = host.GatedStore();
      final (c, store, _) = await p.bootPro(
        t,
        open: false,
        memoryStore: disk,
        state: smartSeed(),
      );
      store.accept(p.FakeHabitStore.snapshot('owned', pro: true));
      await host.go(t, '/settings/studio');
      await tap(t, 'studio-palette-grove');
      disk.fail = true;
      await tap(t, 'studio-apply');
      expect(c.state!.settings['studio'], isNull);
      expect(find.byType(HabitStudioPage), findsOneWidget);
      expect(
        t
            .widget<ChoiceChip>(find.byKey(const Key('studio-palette-grove')))
            .selected,
        true,
      );
      disk.fail = false;
      await tap(t, 'studio-apply');
      expect(c.state!.settings['studio'], containsPair('palette', 'grove'));
      await host.go(t, '/settings/studio');
      await c.change(
        (s) => s.copy({
          'settings': {
            ...s.settings,
            'studio': const StudioStyle(palette: 'ochre').toJson(),
          },
        }),
      );
      await t.pumpAndSettle();
      await tap(t, 'studio-apply');
      expect(c.state!.settings['studio'], containsPair('palette', 'ochre'));
      expect(find.byType(HabitStudioPage), findsOneWidget);
      expect(find.textContaining('Your saved look changed.'), findsOneWidget);
    },
  );
  for (final palette in studioPalettes)
    for (final dark in [false, true])
      test('$palette $dark all studio text/controls meet AA', () {
        final p = studioPalette(palette, dark);
        for (final bg in [p.canvas, p.surface, p.raised, p.tint, p.ochreField])
          for (final fg in [p.ink, p.muted])
            expect(
              contrast(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason: '$palette $dark $fg/$bg',
            );
        for (final pair in [
          (p.onAnchor, p.anchor),
          (p.onVermilion, p.vermilion),
          (p.anchor, p.canvas),
          (p.vermilion, p.tint),
          (p.ochre, p.ochreField),
        ])
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        for (final bg in [p.canvas, p.surface])
          expect(contrast(p.control, bg), greaterThanOrEqualTo(3));
      });
  test(
    'studio validates imported preferences and falls back without erasing them',
    () {
      final settings = {
        'studio': {
          'palette': 'grove',
          'layout': 'cards',
          'spacing': 'airy',
          'runner': 'quiet',
          'icons': {'read': 'leaf', 'bad': 'unsupported'},
        },
      };
      final style = StudioStyle.read(settings, pro: true);
      expect(style.icons, {'read': 'leaf'});
      expect(StudioStyle.read(settings, pro: false).palette, 'vermilion');
      expect((settings['studio']!['icons'] as Map)['read'], 'leaf');
      expect(
        StudioStyle.read({
          'studio': {
            'palette': 'unknown',
            'icons': [1],
          },
        }, pro: true).palette,
        'vermilion',
      );
    },
  );
  p.proTest(
    'free insights use disposable history; core Progress remains free',
    (t) async {
      final (c, _, _) = await p.bootPro(t, open: false, state: smartSeed());
      final before = jsonEncode(c.state!.toJson());
      await host.go(t, '/progress/smart');
      expect(find.byKey(const Key('smart-demo-label')), findsOneWidget);
      expect(find.textContaining('9/10 goals kept'), findsOneWidget);
      expect(find.textContaining('6/10 goals kept'), findsOneWidget);
      expect(find.byKey(const Key('smart-report')), findsNothing);
      expect(find.byKey(const Key('goal-accept-read')), findsNothing);
      await tap(t, 'smart-quarter');
      expect(jsonEncode(c.state!.toJson()), before);
      host.nav(t).pop();
      await t.pumpAndSettle();
      await host.go(t, '/progress');
      expect(find.byKey(const Key('progress-finding')), findsOneWidget);
    },
  );
  p.proTest(
    'Pro decisions persist, change tomorrow and leave past history intact',
    (t) async {
      final (c, store, _) = await p.bootPro(t, open: false, state: smartSeed());
      store.accept(p.FakeHabitStore.snapshot('owned', pro: true));
      await t.pumpAndSettle();
      await host.go(t, '/progress/smart');
      expect(find.byKey(const Key('smart-demo-label')), findsNothing);
      await tap(t, 'goal-accept-read');
      await t.tap(find.text('Accept goal'));
      await t.pumpAndSettle();
      expect(scheduleOn(c.state!.habits.single, '2024-01-08')!.target, 6000);
      expect(scheduleOn(c.state!.habits.single, '2024-01-09')!.target, 8000);
      expect(find.byKey(const Key('goal-accept-read')), findsNothing);
      expect(c.state!.events.length, smartSeed().events.length);
    },
  );
  p.proTest(
    'dismiss writes only a decision and Pro loss removes advanced controls',
    (t) async {
      final (c, store, _) = await p.bootPro(t, open: false, state: smartSeed());
      store.accept(p.FakeHabitStore.snapshot('owned', pro: true));
      await host.go(t, '/progress/smart');
      await tap(t, 'goal-dismiss-read');
      expect(c.state!.habits.single.schedules.length, 1);
      expect(c.state!.settings['goalDecisions'], isNotEmpty);
      store.accept(p.FakeHabitStore.snapshot('ready'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('smart-demo-label')), findsOneWidget);
      expect(find.byKey(const Key('smart-report')), findsNothing);
    },
  );
  p.proTest(
    'studio preview and cancel never write; free Apply opens exact Pro demo',
    (t) async {
      final (c, _, _) = await p.bootPro(t, open: false, state: smartSeed());
      final before = jsonEncode(c.state!.toJson());
      await host.go(t, '/settings/studio');
      await tap(t, 'studio-palette-grove');
      await tap(t, 'studio-layout-cards');
      expect(jsonEncode(c.state!.toJson()), before);
      await tap(t, 'studio-apply');
      expect(host.route(t), '/pro?feature=studio');
      expect(jsonEncode(c.state!.toJson()), before);
      host.nav(t).pop();
      await t.pumpAndSettle();
      host.nav(t).pop();
      await t.pumpAndSettle();
      expect(c.state!.settings['studio'], isNull);
    },
  );
  p.proTest(
    'Pro applies studio to Today; refund uses free look and retains choices',
    (t) async {
      final (c, store, _) = await p.bootPro(t, open: false, state: smartSeed());
      store.accept(p.FakeHabitStore.snapshot('owned', pro: true));
      await host.go(t, '/settings/studio');
      await tap(t, 'studio-palette-grove');
      await tap(t, 'studio-layout-cards');
      await tap(t, 'studio-spacing-airy');
      await tap(t, 'studio-runner-quiet');
      await tap(t, 'studio-icon-leaf');
      expect(
        find.descendant(
          of: find.byKey(const Key('studio-preview')),
          matching: find.byIcon(Icons.eco_outlined),
        ),
        findsOneWidget,
      );
      await tap(t, 'studio-apply');
      expect(find.byType(HabitStudioPage), findsNothing);
      final ctx = t.element(find.byKey(const Key('habit-read')));
      expect(StudioStyle.of(ctx).palette, 'grove');
      expect(StudioStyle.of(ctx).icons, {'read': 'leaf'});
      expect(HabitPalette.of(ctx).canvas, studioPalette('grove', false).canvas);
      final saved = jsonEncode(c.state!.settings['studio']);
      store.accept(p.FakeHabitStore.snapshot('ready'));
      await t.pumpAndSettle();
      expect(
        StudioStyle.of(t.element(find.byKey(const Key('habit-read')))).palette,
        'vermilion',
      );
      expect(jsonEncode(c.state!.settings['studio']), saved);
      store.accept(p.FakeHabitStore.snapshot('owned', pro: true));
      await t.pumpAndSettle();
      expect(
        StudioStyle.of(t.element(find.byKey(const Key('habit-read')))).layout,
        'cards',
      );
    },
  );
  p.proTest('PDF preview and real bilingual bytes use the same evidence', (
    t,
  ) async {
    final (c, store, _) = await p.bootPro(t, open: false, state: smartSeed());
    store.accept(p.FakeHabitStore.snapshot('owned', pro: true));
    await host.go(t, '/progress/smart');
    await tap(t, 'smart-report');
    expect(find.byKey(const Key('smart-report-save')), findsOneWidget);
    for (final vi in [false, true]) {
      await c.change(
        (s) => s.copy({
          'settings': {...s.settings, 'locale': vi ? 'vi' : 'en'},
        }),
      );
      await t.pumpAndSettle();
      final ctx = t.element(find.byKey(const Key('smart-report-save')));
      final sections = smartReview(ctx, smartSeed(), '2024-01-08', 'month');
      final bytes = await t.runAsync(
        () => smartReportPdf(
          sections,
          today: '2024-01-08',
          zone: 'Asia/Ho_Chi_Minh',
          vi: vi,
        ),
      );
      expect(ascii.decode(bytes!.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(5000));
      await t.runAsync(() async {
        final file = File('build/run13/report-${vi ? 'vi' : 'en'}.pdf');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
      });
    }
    store.accept(p.FakeHabitStore.snapshot('ready'));
    await t.pumpAndSettle();
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('smart-report-save')))
          .onPressed,
      isNull,
    );
  });
}
