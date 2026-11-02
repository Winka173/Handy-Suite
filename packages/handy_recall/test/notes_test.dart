import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:image/image.dart' as image;

const now = '2026-10-31T08:00:00.000Z';
const later = '2026-11-02T08:00:00.000Z';

RecallState deck({bool reverse = false}) => saveDeck(
  emptyRecallState(),
  RecallDeck(id: 'd', name: 'Words', reverse: reverse),
);

String Function() ids([String prefix = 'n']) {
  var i = 0;
  return () => '$prefix${++i}';
}

RecallImage picture({
  List<OcclusionMask> masks = const [],
  String side = 'front',
}) {
  final bitmap = image.Image(width: 8, height: 4);
  image.fill(bitmap, color: image.ColorRgb8(10, 20, 30));
  return RecallImage(
    dataUri: 'data:image/png;base64,${base64Encode(image.encodePng(bitmap))}',
    masks: masks,
    side: side,
  );
}

void main() {
  group('cloze', () {
    const text = '{{c1::Paris}} is the capital of {{c2::France::country}}.';
    test('numbers, blanks with hints, answers and other clozes as text', () {
      expect(clozeNumbers(text), [1, 2]);
      expect(clozeNumbers('{{c3::a}} {{c3::b}} {{c1::c}}'), [1, 3]);
      expect(clozeNumbers('no cloze {{c0::zero}} {c1::x}'), isEmpty);
      expect(clozeSpans(text, 2, revealed: false), const [
        ClozeSpan('Paris is the capital of ', ClozePart.text),
        ClozeSpan('[country]', ClozePart.blank),
        ClozeSpan('.', ClozePart.text),
      ]);
      expect(
        clozeText(text, 1, revealed: false),
        '[…] is the capital of France.',
      );
      expect(
        clozeSpans(text, 1, revealed: true).first,
        const ClozeSpan('Paris', ClozePart.answer),
      );
      expect(
        clozeText('{{c1::a}} and {{c1::b}}', 1, revealed: false),
        '[…] and […]',
      );
    });
    test('making a cloze from a selection, a new number each time', () {
      var r = makeCloze('Paris is in France', 0, 5);
      expect(r.text, '{{c1::Paris}} is in France');
      expect(r.cursor, '{{c1::Paris}}'.length);
      r = makeCloze(r.text, r.text.length - 6, r.text.length);
      expect(r.text, '{{c1::Paris}} is in {{c2::France}}');
      // Same number, selection given backwards, empty selection.
      expect(makeCloze('a b', 3, 2, same: true).text, 'a {{c1::b}}');
      final empty = makeCloze('{{c1::a}} ', 10, 10);
      expect(empty.text, '{{c1::a}} {{c2::}}');
      expect(empty.cursor, 16);
    });
  });

  group('notes', () {
    test('a reverse card is a sibling with its own schedule', () {
      var s = saveNote(
        deck(),
        deckId: 'd',
        front: '犬',
        back: 'dog',
        reverse: true,
        newId: ids(),
        now: now,
      );
      expect(s.cards.length, 2);
      final forward = s.cards.first, back = s.cards.last;
      expect(forward.note, isNotEmpty);
      expect(back.note, forward.note);
      expect((back.reversed, back.question, back.answer), (true, 'dog', '犬'));
      // Grading one leaves the other untouched.
      s = saveCard(s, reviewCard(forward, 'easy', now: now));
      expect(s.cards.last.reviewCount, 0);
      expect(s.cards.first.reviewCount, 1);
      // Editing either edits both; the schedule stays.
      s = saveNote(
        s,
        deckId: 'd',
        from: s.cards.last,
        front: '猫',
        back: 'cat',
        reverse: true,
        newId: ids('x'),
        now: later,
      );
      expect(s.cards.map((c) => (c.front, c.back)), [
        ('猫', 'cat'),
        ('猫', 'cat'),
      ]);
      expect(s.cards.first.reviewCount, 1);
      // Switching the reverse off drops only the reverse card.
      s = saveNote(
        s,
        deckId: 'd',
        from: s.cards.first,
        front: '猫',
        back: 'cat',
        newId: ids('y'),
      );
      expect(s.cards.single.id, forward.id);
      expect(s.cards.single.reviewCount, 1);
    });

    test('cloze notes: one card per number; editing adds and drops', () {
      var s = saveNote(
        deck(reverse: true),
        deckId: 'd',
        front: '{{c1::H2O}} is {{c2::water}}',
        back: '',
        reverse: true, // never applies to clozes
        newId: ids(),
        now: now,
      );
      expect(s.cards.map((c) => c.cloze), [1, 2]);
      expect(s.cards.any((c) => c.reversed), isFalse);
      final c1 = s.cards.first;
      s = saveCard(s, reviewCard(c1, 'good', now: now));
      s = saveNote(
        s,
        deckId: 'd',
        from: s.cards.last,
        front: '{{c1::H2O}} is water, {{c3::NaCl}} is salt',
        back: 'chemistry',
        newId: ids('z'),
        now: later,
      );
      expect(s.cards.map((c) => c.cloze), [1, 3]);
      expect(s.cards.first.id, c1.id);
      expect(s.cards.first.reviewCount, 1);
      expect(s.cards.last.dueAt, later);
      // Deleting the note deletes every card made from it.
      expect(removeNote(s, s.cards.last).cards, isEmpty);
    });

    test('a covered picture cannot be reversed; a plain one can', () {
      expect(
        () => saveNote(
          deck(),
          deckId: 'd',
          front: 'Heart',
          back: 'parts',
          image: picture(
            masks: const [OcclusionMask(x: 0, y: 0, width: .5, height: .5)],
          ),
          reverse: true,
          newId: ids(),
        ),
        throwsFormatException,
      );
      final s = saveNote(
        deck(),
        deckId: 'd',
        front: '',
        back: 'a lake',
        image: picture(),
        reverse: true,
        newId: ids(),
        now: now,
      );
      expect(s.cards.first.imageOnQuestion, isTrue);
      expect(s.cards.last.imageOnQuestion, isFalse);
    });

    test('review order keeps siblings apart', () {
      final s = saveNote(
        deck(),
        deckId: 'd',
        front: 'a',
        back: 'b',
        reverse: true,
        newId: ids(),
        now: now,
      );
      final other = createCard(
        id: 'o',
        deckId: 'd',
        front: 'q',
        back: 'x',
        now: now,
      );
      final due = [...s.cards, other];
      expect(reviewOrder(due).map((c) => c.id), ['n2', 'o', 'n3']);
      // After the first card of the note, its sibling waits for the rest.
      expect(reviewOrder([due[1], other], seen: {'n1'}).map((c) => c.id), [
        'o',
        'n3',
      ]);
    });
  });

  group('schema 2', () {
    test('version 1 files load and roundtrip through version 2', () {
      final v1 = {
        'version': 1,
        'decks': [
          {'id': 'd', 'name': 'Old'},
        ],
        'cards': [
          {
            'id': 'c',
            'deckId': 'd',
            'front': 'Q',
            'back': 'A',
            'dueAt': now,
            'intervalDays': 3,
            'reviewCount': 2,
            'lapses': 0,
            'ease': 2.5,
            'lastReviewedAt': now,
          },
        ],
      };
      final s = parseRecallBackup(jsonEncode(v1));
      final json = jsonDecode(exportRecallBackup(s)) as Map;
      expect(json['version'], recallSchemaVersion);
      expect((json['cards'] as List).single, (v1['cards'] as List).single);
      expect(parseRecallBackup(jsonEncode(json)).toJson(), s.toJson());
    });

    test('every new field survives backup and restore', () {
      var s = saveDeck(
        emptyRecallState(),
        const RecallDeck(
          id: 'd',
          name: 'Nihongo',
          reverse: true,
          speakFront: 'ja-JP',
          speakBack: 'vi-VN',
        ),
      );
      s = saveNote(
        s,
        deckId: 'd',
        front: '水',
        back: 'nước',
        reverse: true,
        newId: ids(),
        now: now,
      );
      s = saveNote(
        s,
        deckId: 'd',
        front: '{{c1::東京}} is big',
        back: '',
        newId: ids('k'),
        now: now,
      );
      s = saveCard(
        s,
        createCard(
          id: 'p',
          deckId: 'd',
          front: '',
          back: 'Fuji',
          image: picture(side: 'back'),
          now: now,
        ),
      );
      final restored = parseRecallBackup(exportRecallBackup(s));
      expect(restored.toJson(), s.toJson());
      expect(restored.decks.single.speakFront, 'ja-JP');
      expect(restored.cards.where((c) => c.reversed).length, 1);
      expect(
        restored.cards.firstWhere((c) => c.cloze == 1).front,
        contains('東京'),
      );
      expect(restored.cards.last.image!.side, 'back');
    });

    test('invalid new fields are refused', () {
      final base = createCard(
        id: 'c',
        deckId: 'd',
        front: 'Q',
        back: 'A',
        now: now,
      );
      for (final bad in <Map<String, Object?>>[
        {'cloze': 2},
        {'cloze': 1, 'front': '{{c1::x}}', 'reversed': true},
        {'reversed': 'yes'},
        {'note': 'bad id!'},
        {'front': '', 'back': ''},
        {'back': ''},
      ]) {
        expect(() => base.copyWith(bad), throwsFormatException, reason: '$bad');
      }
      expect(
        base.copyWith({'cloze': 1, 'front': '{{c1::x}}', 'back': ''}).cloze,
        1,
      );
      for (final lang in ['ja JP', '<script>', 'x' * 40, 'j']) {
        expect(
          () =>
              RecallDeck.fromJson({'id': 'd', 'name': 'D', 'speakFront': lang}),
          throwsFormatException,
        );
      }
    });

    test(
      'CSV: cloze rows become cloze cards, reverse on request, one row per note',
      () {
        final cards = importCardsCsv(
          'front,back\n"{{c1::a}} {{c2::b}}",x\nq,r',
          'd',
          'imp',
          now: now,
          reverse: true,
        );
        expect(cards.map((c) => (c.id, c.cloze, c.reversed)), [
          ('imp_1', 1, false),
          ('imp_1_c2', 2, false),
          ('imp_2', 0, false),
          ('imp_2_r', 0, true),
        ]);
        expect(cards.first.note, 'imp_1');
        expect(exportCardsCsv(cards).split('\r\n').length, 3);
      },
    );
  });
}
