import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:image/image.dart' as image;

const now = '2026-10-31T08:00:00.000Z';
void main() {
  test(
    'default creation and review use legacy-compatible millisecond timestamps',
    () {
      final c = createCard(id: 'fresh', deckId: 'd', front: 'Q', back: 'A');
      expect(c.dueAt, contains('T'));
      expect(() => reviewCard(c, 'good'), returnsNormally);
    },
  );
  RecallCard card([String id = 'a']) => createCard(
    id: id,
    deckId: 'd',
    front: 'Câu hỏi 😀',
    back: 'Đáp án',
    now: now,
  );
  RecallState state() => saveCard(
    saveDeck(emptyRecallState(), const RecallDeck(id: 'd', name: 'Kiến thức')),
    card(),
  );
  RecallImage picture() {
    final bitmap = image.Image(width: 8, height: 4);
    image.fill(bitmap, color: image.ColorRgb8(10, 20, 30));
    return RecallImage.fromJson({
      'dataUri':
          'data:image/png;base64,${base64Encode(image.encodePng(bitmap))}',
      'mask': {'x': 0.25, 'y': 0.25, 'width': 0.5, 'height': 0.5},
    });
  }

  test('legacy v1 keeps scheduler and IDs exactly through backup', () {
    final original = state(),
        restored = parseRecallBackup(exportRecallBackup(original));
    expect(restored.toJson(), original.toJson());
    expect(restored.cards.single.dueAt, now);
    expect(restored.cards.single.ease, 2.5);
    expect(restored.cards.single.intervalDays, 0);
  });
  test('CRUD preserves order and deck delete cascades only matching cards', () {
    var s = state();
    s = saveDeck(s, const RecallDeck(id: 'e', name: 'Other'));
    s = saveCard(
      s,
      createCard(id: 'b', deckId: 'e', front: 'Q', back: 'A', now: now),
    );
    s = saveCard(s, card().copyWith({'front': 'Changed'}));
    expect(s.cards.map((c) => c.id), ['a', 'b']);
    expect(removeDeck(s, 'd').cards.single.id, 'b');
    expect(removeCard(s, 'b').cards.single.id, 'a');
    expect(() => s.cards.clear(), throwsUnsupportedError);
  });
  for (final v in [
    ('again', 600000, 1, 2.3),
    ('hard', 86400000, 0, 2.35),
    ('good', 86400000, 0, 2.5),
    ('easy', 345600000, 0, 2.65),
  ]) {
    test('new card ${v.$1} canonical schedule', () {
      final c = reviewCard(card(), v.$1, now: now);
      expect(
        DateTime.parse(c.dueAt).difference(DateTime.parse(now)).inMilliseconds,
        v.$2,
      );
      expect(c.reviewCount, 1);
      expect(c.lapses, v.$3);
      expect(c.ease, closeTo(v.$4, 1e-10));
    });
  }
  test('good progresses 1 day,3 days,7.5 days', () {
    var c = reviewCard(card(), 'good', now: now);
    c = reviewCard(c, 'good', now: c.dueAt);
    expect(c.intervalDays, 3);
    c = reviewCard(c, 'good', now: c.dueAt);
    expect(c.intervalDays, 7.5);
  });
  test('legacy ease and fractional interval preserved before review', () {
    final original = card().copyWith({
      'reviewCount': 17,
      'lapses': 3,
      'ease': 2.123456789,
      'intervalDays': 7.123456789,
      'lastReviewedAt': '2026-10-30T08:00:00Z',
    });
    final imported = parseRecallBackup(
      exportRecallBackup(
        RecallState(
          decks: [const RecallDeck(id: 'd', name: 'D')],
          cards: [original],
        ),
      ),
    ).cards.single;
    expect(imported.ease, original.ease);
    expect(imported.intervalDays, original.intervalDays);
    expect(imported.lastReviewedAt, original.lastReviewedAt);
  });
  test('scheduling rejects backwards reviews and caps ease/interval', () {
    var c = reviewCard(card(), 'good', now: now);
    expect(
      () => reviewCard(c, 'good', now: '2026-10-30T08:00:00Z'),
      throwsFormatException,
    );
    expect(() => reviewCard(c, 'unknown', now: now), throwsFormatException);
    c = c.copyWith({'intervalDays': 36500, 'ease': 3.5});
    expect(reviewCard(c, 'easy', now: now).intervalDays, 36500);
    expect(reviewCard(c, 'easy', now: now).ease, 3.5);
    expect(
      () => reviewCard(c.copyWith({'reviewCount': 1000000}), 'good', now: now),
      throwsFormatException,
    );
  });
  test('due queue and stats are deterministic filtered and stable', () {
    final c = card(),
        b = card('b'),
        future = reviewCard(card('future'), 'good', now: now);
    final s = RecallState(
      decks: [const RecallDeck(id: 'd', name: 'D')],
      cards: [b, future, c],
    );
    expect(dueCards(s, now: now).map((c) => c.id), ['a', 'b']);
    expect(recallStats(s, now: now), {
      'total': 3,
      'due': 2,
      'newCards': 2,
      'reviewed': 1,
      'lapses': 0,
    });
    expect(dueCards(s, now: now, deckId: 'missing'), isEmpty);
  });
  test('strict timestamps reject rollover, timezone normalizes', () {
    expect(card().copyWith({'dueAt': '2026-10-31T15:00:00+07:00'}).dueAt, now);
    for (final value in [
      '2026-02-30T08:00:00Z',
      '2023-02-29T08:00:00Z',
      '2026-10-31',
      '2026-10-31T25:00:00Z',
    ]) {
      expect(() => card().copyWith({'dueAt': value}), throwsFormatException);
    }
  });
  test('history duplicate missing-reference and numeric guards', () {
    for (final change in <Map<String, Object?>>[
      {'ease': 1.2},
      {'ease': 3.6},
      {'reviewCount': -1},
      {'lapses': 1},
      {'intervalDays': double.nan},
      {'reviewCount': 1},
      {'reviewCount': 0, 'lastReviewedAt': now},
      {'id': '../x'},
      {'front': ' '},
      {'back': 'x' * 20001},
    ]) {
      expect(() => card().copyWith(change), throwsFormatException);
    }
    expect(
      () => validateRecallState({
        'version': 1,
        'decks': [],
        'cards': [card().toJson()],
      }),
      throwsFormatException,
    );
    expect(
      () => validateRecallState({
        'version': 1,
        'decks': [
          {'id': 'd', 'name': 'D'},
        ],
        'cards': [card().toJson(), card().toJson()],
      }),
      throwsFormatException,
    );
  });
  test(
    'legacy one-mask migrates without moving coordinates and supports multiple',
    () {
      final legacy = picture();
      expect(legacy.masks.length, 1);
      final second = const OcclusionMask(x: 0, y: 0, width: 0.1, height: 0.2),
          multi = legacy.copyWith(masks: [legacy.mask, second]);
      final c = card().copyWith({'image': multi.toJson()}),
          s = RecallState(
            decks: [const RecallDeck(id: 'd', name: 'D')],
            cards: [c],
          );
      final restored = parseRecallBackup(exportRecallBackup(s)).cards.single;
      expect(restored.image!.masks.length, 2);
      expect(restored.image!.mask.toJson(), legacy.mask.toJson());
      expect(
        reviewCard(restored, 'easy', now: now).image!.toJson(),
        multi.toJson(),
      );
      expect(decodeRecallImage(multi.toJson()).dataUri, multi.dataUri);
    },
  );
  test('invalid image data and mask boundaries rejected', () {
    final p = picture();
    for (final mask in [
      const OcclusionMask(x: -0.1, y: 0, width: 0.5, height: 0.5),
      const OcclusionMask(x: 0.9, y: 0, width: 0.5, height: 0.5),
      const OcclusionMask(x: 0, y: 0, width: 0, height: 1),
    ]) {
      expect(() => p.copyWith(masks: [mask]), throwsFormatException);
    }
    // Schema 2: a plain picture has no covers (it used to need one).
    expect(p.copyWith(masks: []).masks, isEmpty);
    expect(() => p.copyWith(side: 'left'), throwsFormatException);
    expect(
      () => p.copyWith(masks: List.filled(33, p.mask)),
      throwsFormatException,
    );
    for (final uri in [
      'https://example.com/a.png',
      'file:///a',
      'data:image/svg+xml;base64,AA==',
      'data:image/png;base64,AAAA',
      'data:image/png;base64,!!!!',
    ]) {
      expect(
        () => RecallImage.fromJson({'dataUri': uri, 'mask': p.mask.toJson()}),
        throwsFormatException,
      );
    }
  });
  test('CSV literal quotes Unicode multiline and formula text roundtrip', () {
    final originals = [
      card().copyWith({
        'front': '="A", 😀\nnext',
        'back': '"Đáp án"\r\nsecond',
      }),
    ];
    final csv = exportCardsCsv(originals),
        imported = importCardsCsv('\ufeff$csv', 'd', 'new', now: now);
    expect(imported.single.front, originals.single.front);
    expect(imported.single.back, originals.single.back);
    expect(imported.single.reviewCount, 0);
    expect(imported.single.id, 'new_1');
    expect(imported.single.image, isNull);
  });
  for (final invalid in [
    'question,answer\na,b',
    'front,back\n"unclosed,b',
    'front,back\n"a"oops,b',
    'front,back\na,b,c',
    'front,back\n,b',
  ]) {
    test(
      'CSV rejects ${invalid.replaceAll('\n', ' ')}',
      () => expect(
        () => importCardsCsv(invalid, 'd', 'new', now: now),
        throwsFormatException,
      ),
    );
  }
  test('CSV no rows, blank lines and limits', () {
    expect(importCardsCsv('front,back\r\n\r\n', 'd', 'n', now: now), isEmpty);
    expect(() => parseRecallBackup('x' * 16000001), throwsFormatException);
    expect(
      () => importCardsCsv('front,back\n${'x' * 20001},b', 'd', 'n', now: now),
      throwsFormatException,
    );
  });
  test('maximum card count still permits edit/review but rejects insert', () {
    final s = RecallState(
      decks: [const RecallDeck(id: 'd', name: 'D')],
      cards: List.generate(recallCardLimit, (i) => card('c$i')),
    );
    expect(validateRecallState(s.toJson()).cards.length, recallCardLimit);
    expect(() => saveCard(s, card('extra')), throwsFormatException);
    expect(
      saveCard(
        s,
        reviewCard(s.cards.first, 'good', now: now),
      ).cards.first.reviewCount,
      1,
    );
  });
}
