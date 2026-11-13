// The design tokens, measured: WCAG 2.2 AA contrast for every pair the
// screens put together, the five type sizes, and the keyboard's focus ring.
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/design/theme.dart';
import 'package:handy_bookmark/ui/focus_ring.dart';
import 'package:handy_ui/kit.dart';
import 'widget_test.dart' show start;

double _channel(double v) =>
    v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
double _luminance(Color c) =>
    .2126 * _channel(c.r) + .7152 * _channel(c.g) + .0722 * _channel(c.b);
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

void main() {
  for (final (name, p) in [
    ('light', BookmarkPalette.light),
    ('dark', BookmarkPalette.dark),
  ]) {
    test('$name: every text pair reaches 4.5:1', () {
      final text = <String, (Color, Color)>{
        'ink on ground': (p.ink, p.canvas),
        'ink on surface': (p.ink, p.surface),
        'ink on raised': (p.ink, p.raised),
        'ink on tint': (p.ink, p.tint),
        'muted on ground': (p.muted, p.canvas),
        'muted on surface': (p.muted, p.surface),
        // A save without a picture: its source's name on the quiet field.
        'muted on raised': (p.muted, p.raised),
        'muted on tint': (p.muted, p.tint),
        'action words on ground': (p.primary, p.canvas),
        'action words on surface': (p.primary, p.surface),
        'action words on tint': (p.primary, p.tint),
        'button label': (p.onPrimary, p.primary),
        'band title': (p.bandInk, p.band),
        'band counts': (p.bandSub, p.band),
        'Save label on gold': (p.onGold, p.gold),
        'done mark on ground': (p.sage, p.canvas),
        'done mark on its tint': (p.sage, p.sageTint),
        'error on surface': (p.danger, p.surface),
        'error on ground': (p.danger, p.canvas),
        'error on its tint': (p.danger, p.dangerTint),
        'warning on surface': (p.warning, p.surface),
        'warning on its tint': (p.warning, p.warningTint),
      };
      for (final e in text.entries) {
        expect(
          contrast(e.value.$1, e.value.$2),
          greaterThanOrEqualTo(4.5),
          reason: e.key,
        );
      }
    });

    test('$name: control edges and the focus ring reach 3:1', () {
      final edges = <String, (Color, Color)>{
        'field edge on surface': (p.control, p.surface),
        'field edge on ground': (p.control, p.canvas),
        'focus ring on ground': (p.primary, p.canvas),
        'focus ring on surface': (p.primary, p.surface),
        'focus ring on tint': (p.primary, p.tint),
        'gold action on band': (p.gold, p.band),
      };
      // The ring is two lines, the teal and the surface colour: on the
      // band whichever of them parts from it more is the one that reads.
      expect(
        math.max(contrast(p.primary, p.band), contrast(p.surface, p.band)),
        greaterThanOrEqualTo(3),
        reason: 'focus ring on band',
      );
      for (final e in edges.entries) {
        expect(
          contrast(e.value.$1, e.value.$2),
          greaterThanOrEqualTo(3),
          reason: e.key,
        );
      }
    });
  }

  test('the theme sets type at the five sizes only', () {
    for (final b in Brightness.values) {
      final t = bookmarkTheme(ThemeData(brightness: b)).textTheme;
      final scale = <double>{
        BookmarkType.meta,
        BookmarkType.body,
        BookmarkType.lead,
        BookmarkType.section,
        BookmarkType.page,
      };
      for (final s in [
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
        t.titleSmall,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
        t.labelSmall,
      ]) {
        expect(scale, contains(s!.fontSize));
      }
    }
  });

  testWidgets('the keyboard shows a focus ring, a touch does not', (t) async {
    await start(t, size: const Size(1440, 900));
    const screen = Size(1440, 900);
    expect(focusRingRect(screen), isNull, reason: 'no keyboard yet');
    // Tab walks the controls: each one is ringed where it stands.
    final seen = <Rect>{};
    for (var i = 0; i < 6; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      final rect = focusRingRect(screen);
      if (rect != null) seen.add(rect);
    }
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
    expect(seen.length, greaterThanOrEqualTo(3), reason: 'the ring moved');
    for (final r in seen) {
      // A control, never the page.
      expect(
        r.width < screen.width * .9 || r.height < screen.height * .6,
        true,
      );
    }
    // A touch puts the ring away.
    await t.tapAt(const Offset(700, 500));
    await t.pumpAndSettle();
    expect(focusRingRect(screen), isNull);
  });
}
