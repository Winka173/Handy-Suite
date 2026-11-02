import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_card_engine/handy_card_engine.dart';

/// Measures the editor core on scenes of 10, 100 and 500 elements on two
/// sides, and writes the numbers to build/card-performance.json. The
/// limits are generous ceilings that catch regressions, not targets.
void main() {
  test('editor core timings at 10, 100 and 500 elements', () {
    final registry = ElementRegistry.standard();
    final results = <String, Object>{};
    for (final n in [10, 100, 500]) {
      var doc = blankDocument(size: cardSizes[0], at: DateTime.utc(2026));
      final els = [
        for (var i = 0; i < n; i++)
          registry
              .create(
                i.isEven ? 'rect' : 'text',
                at: Vec((i * 7) % 250 + 2, (i * 13) % 150 + 2),
                props: i.isEven ? const {} : {'text': 'Nguyễn Minh Anh $i'},
              )
              .copyWith(
                frame: Frame(
                  (i * 7) % 240.0,
                  (i * 13) % 140.0,
                  12,
                  8,
                  (i * 5) % 90.0,
                ),
              ),
      ];
      doc = withPageElements(doc, doc.pages.first.id, els);
      doc = withPageElements(
        doc,
        doc.pages.last.id,
        els.map(cloneElement).toList(),
      );
      final session = EditorSession(doc, registry: registry);
      final ids = {for (final e in els.take(n ~/ 2)) e.id};
      int time(void Function() f, {int repeat = 1}) {
        final sw = Stopwatch()..start();
        for (var i = 0; i < repeat; i++) f();
        return (sw.elapsedMicroseconds / repeat).round();
      }

      final hit = time(
        () => hitTest(session.elements, const Vec(120, 70)),
        repeat: 200,
      );
      final drag = time(() {
        session.begin('Move');
        for (var i = 1; i <= 60; i++) {
          session.preview(
            (b) => withPageElements(
              b,
              session.page,
              moveBy(b.page(session.page).elements, ids, Vec(i * 0.5, 0)),
            ),
          );
        }
        session.commit();
      });
      final encode = time(() => doc.encode(), repeat: 10);
      final text = doc.encode();
      final decode = time(
        () => CardDocument.decode(text, registry),
        repeat: 10,
      );
      final svg = time(() => exportSvg(doc, doc.pages.first.id), repeat: 3);
      results['$n'] = {
        'hitTestMicros': hit,
        'dragOf60MovesMicros': drag,
        'encodeMicros': encode,
        'decodeMicros': decode,
        'svgMicros': svg,
        'jsonBytes': utf8.encode(text).length,
      };
      // Ceilings: a 60-move drag of half of 500 elements under 3 s on the
      // host, a hit test under 5 ms.
      if (n == 500) {
        expect(drag, lessThan(3000000));
        expect(hit, lessThan(5000));
      }
    }
    Directory('build').createSync(recursive: true);
    File('build/card-performance.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'measuredOn': 'flutter test host (${Platform.operatingSystem})',
        'results': results,
      }),
    );
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(results));
  });
}
