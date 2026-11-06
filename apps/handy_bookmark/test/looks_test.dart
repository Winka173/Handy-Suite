import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/design/looks.dart';
import 'package:handy_bookmark/design/theme.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

void main() {
  test('every look has unique stable ids and at least one palette', () {
    final ids = allLooks.map((l) => l.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(premiumLooks, hasLength(10));
    for (final l in allLooks) {
      expect(l.light != null || l.dark != null, isTrue, reason: l.id);
    }
    expect(lookById('gone-theme'), isNull, reason: 'unknown ids fall back');
  });

  test('every palette keeps text readable on every surface', () {
    for (final look in allLooks) {
      for (final BookmarkPalette p in [?look.light, ?look.dark]) {
        final where = look.id;
        for (final ground in [p.canvas, p.surface]) {
          expect(
            _contrast(p.ink, ground),
            greaterThanOrEqualTo(7),
            reason: '$where ink',
          );
          expect(
            _contrast(p.muted, ground),
            greaterThanOrEqualTo(4.5),
            reason: '$where muted',
          );
        }
        expect(
          _contrast(p.onPrimary, p.primary),
          greaterThanOrEqualTo(4.5),
          reason: '$where button',
        );
        expect(
          _contrast(p.primary, p.canvas),
          greaterThanOrEqualTo(3),
          reason: '$where accent',
        );
        expect(
          _contrast(p.danger, p.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$where danger',
        );
        expect(
          _contrast(p.warning, p.warningTint),
          greaterThanOrEqualTo(4.5),
          reason: '$where warning',
        );
      }
    }
  });
}
