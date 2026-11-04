import 'package:flutter_test/flutter_test.dart';
import 'package:handy_card_engine/handy_card_engine.dart';

final registry = ElementRegistry.standard();
final at = DateTime.utc(2026, 11, 4);

Set<String> colours(CardDocument d) => {
  for (final p in d.pages) ...[
    if (p.background != null) p.background!,
    for (final e in p.all)
      for (final k in ['color', 'fill', 'stroke', 'background'])
        if (e.props[k] case final String v) v.toUpperCase(),
  ],
};

void main() {
  final library = cardTemplates.where((t) => t.id.contains('-')).toList();

  test('every library template is drawn in a known palette', () {
    var known = 0;
    for (final t in library) {
      if (paletteOf(t.build(registry, at)) != null) known++;
    }
    // The extended library is built from the five looks.
    expect(known, greaterThanOrEqualTo(130));
  });

  test('switching palette moves every role and keeps the design valid', () {
    for (final t in library.take(40)) {
      final d = t.build(registry, at);
      final from = paletteOf(d);
      if (from == null) continue;
      for (final to in cardPalettes.where((p) => p.id != from.id).take(3)) {
        final next = recolorDocument(d, to)!;
        next.validate();
        final after = colours(next);
        // Nothing of the old palette is left unless the new one shares it.
        for (final role in ['bg', 'ink', 'accent']) {
          final old = from.role(role);
          if ({to.bg, to.ink, to.muted, to.accent, to.onAccent}.contains(old))
            continue;
          expect(after, isNot(contains(old)), reason: '${t.id} → ${to.id}');
        }
        expect(paletteOf(next)?.id, to.id, reason: '${t.id} → ${to.id}');
        // Geometry and words are untouched.
        expect(
          next.pages.first.all.map((e) => e.frame.x),
          d.pages.first.all.map((e) => e.frame.x),
        );
      }
    }
  });

  test('a colour the person chose stays', () {
    final t = library.firstWhere(
      (t) => paletteOf(t.build(registry, at))?.id == 'paper',
    );
    var d = t.build(registry, at);
    final first = d.pages.first.elements.first;
    d = d.copyWith(
      pages: [
        d.pages.first.copyWith(
          elements: [
            first.copyWith(props: {...first.props, 'color': '0A7B83'}),
            ...d.pages.first.elements.skip(1),
          ],
        ),
        ...d.pages.skip(1),
      ],
    );
    final night = cardPalettes.firstWhere((p) => p.id == 'night');
    final next = recolorDocument(d, night)!;
    expect(next.pages.first.elements.first.props['color'], '0A7B83');
    expect(next.pages.first.background, night.bg);
  });

  test('a design with its own colours is left alone', () {
    final d = CardDocument(
      id: 'x',
      width: 85,
      height: 55,
      pages: [CardPage(id: 'p', background: '0A7B83')],
    );
    expect(paletteOf(d), isNull);
    expect(recolorDocument(d, cardPalettes.first), isNull);
  });

  test('no violet or indigo palette', () {
    for (final p in cardPalettes) {
      final v = int.parse(p.accent, radix: 16);
      final r = v >> 16 & 255, g = v >> 8 & 255, b = v & 255;
      expect(b > r && b > g && r > g, isFalse, reason: p.id);
    }
  });
}
