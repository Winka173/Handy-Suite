import 'package:flutter_test/flutter_test.dart';
import 'package:handy_card_engine/handy_card_engine.dart';

final registry = ElementRegistry.standard();
final at = DateTime.utc(2026, 11, 4);

void main() {
  test('the library: 140+ templates from 40+ layouts, unique ids', () {
    expect(libraryLayoutCount, greaterThanOrEqualTo(40));
    expect(cardTemplates.length, greaterThanOrEqualTo(140));
    expect(
      cardTemplates.map((t) => t.id).toSet(),
      hasLength(cardTemplates.length),
    );
  });

  test('no two templates share their front page geometry', () {
    final seen = <String, String>{};
    for (final t in cardTemplates.where((t) => t.id != 'blank')) {
      final d = t.build(registry, at);
      final sig =
          (d.pages.first.elements
                  .map(
                    (e) =>
                        '${e.type}:${e.frame.x.round()},${e.frame.y.round()},'
                        '${e.frame.width.round()},${e.frame.height.round()}',
                  )
                  .toList()
                ..sort())
              .join('|');
      expect(seen[sig], isNull, reason: '${t.id} repeats ${seen[sig]}');
      seen[sig] = t.id;
    }
  });

  test('every element sits on its page and the words are Vietnamese', () {
    for (final t in cardTemplates.where((t) => t.id != 'blank')) {
      final d = t.build(registry, at);
      var diacritics = false;
      for (final page in d.pages) {
        for (final e in page.elements) {
          final f = e.frame;
          expect(f.x, greaterThanOrEqualTo(-1), reason: '${t.id} ${e.type}');
          expect(f.y, greaterThanOrEqualTo(-1), reason: '${t.id} ${e.type}');
          expect(
            f.x + f.width,
            lessThanOrEqualTo(d.width + 1),
            reason: '${t.id} ${e.type}',
          );
          expect(
            f.y + f.height,
            lessThanOrEqualTo(d.height + 1),
            reason: '${t.id} ${e.type}',
          );
          final text = e.props['text'];
          if (text is String &&
              RegExp('[ăâđêôơưáàảãạ]').hasMatch(text.toLowerCase())) {
            diacritics = true;
          }
        }
      }
      expect(diacritics, isTrue, reason: t.id);
    }
  });
}
