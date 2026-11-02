import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall/anki.dart';
import 'package:handy_recall/handy_recall.dart';
import 'anki_fixture.dart';

const now = '2026-11-01T08:00:00.000Z';

RecallState library() =>
    saveDeck(emptyRecallState(), const RecallDeck(id: 'mine', name: 'Mine'));

void expectFixture(AnkiImport a, {int kept = 2, int dropped = 3}) {
  expect(a.decks.single.name, 'Spanish › Basics');
  expect(a.decks.single.cards, 10);
  expect(a.cards.map((c) => c.ankiId), [
    101,
    201,
    202,
    301,
    302,
    401,
    501,
    502,
    801,
    901,
  ]);
  expect(a.notes, 7);
  expect(a.skipped, 3);
  expect(a.count(AnkiKind.basic), 6);
  expect(a.count(AnkiKind.reversed), 2);
  expect(a.count(AnkiKind.cloze), 2);
  expect(a.imagesKept, kept);
  expect(a.imagesDropped, dropped);
  expect(a.sounds, 1);
  expect(a.suspended, 1);
  expect(a.learning, 1);
  expect(a.withHistory, 2);
  AnkiCard card(int id) => a.cards.firstWhere((c) => c.ankiId == id);
  // HTML becomes text; sounds go; entities decode; scripts never survive.
  expect(card(101).front, 'Hola mundo');
  expect(card(101).back, 'Hello\nworld');
  expect(card(901).front, 'Line\ntwo');
  expect(card(901).front, isNot(contains('alert')));
  // Basic (and reversed): one note, the second card is its reverse.
  expect(card(201).kind, AnkiKind.basic);
  expect(card(202).kind, AnkiKind.reversed);
  expect((card(202).front, card(202).back), ('犬', 'dog'));
  expect(card(201).linked && card(202).linked, isTrue);
  // Optional reversed: only where "Add Reverse" was filled in.
  expect(card(401).linked, isFalse);
  expect(card(502).kind, AnkiKind.reversed);
  expect((card(502).front, card(502).back), ('dos', 'two'));
  // Cloze: one card per number in the text, hint kept.
  expect(card(302).cloze, 2);
  expect(card(302).back, 'Europe');
  expect(
    clozeText(card(302).front, 2, revealed: false),
    'Paris is the capital of [country]',
  );
  // Pictures: the answer's picture belongs to the answer side.
  if (kept > 0) {
    expect(card(201).image!.side, 'back');
    expect(card(201).image!.masks, isEmpty);
  }
  expect(card(801).image, isNull);
}

void main() {
  test('legacy .apkg (collection.anki21) previews in full', () {
    final a = readAnkiPackage(legacyPackage(), now: now);
    expect(a.format, AnkiFormat.anki21);
    expectFixture(a);
  });

  test('Anki 2.0 collection.anki2 reads the same', () {
    final a = readAnkiPackage(
      legacyPackage(name: 'collection.anki2'),
      now: now,
    );
    expect(a.format, AnkiFormat.anki2);
    expectFixture(a);
  });

  test('newer collection.anki21b (zstd, schema 18, protobuf) reads', () {
    final a = readAnkiPackage(modernPackage(), now: now);
    expect(a.format, AnkiFormat.anki21b);
    expectFixture(a);
  });

  test('a picture failing its SHA-1 is left out, the card stays', () {
    final a = readAnkiPackage(modernPackage(badChecksum: true), now: now);
    expectFixture(a, kept: 0, dropped: 4);
    expect(a.cards.firstWhere((c) => c.ankiId == 201).image, isNull);
  });

  test('import as new: every card starts fresh, nothing else moves', () {
    final before = library();
    final a = readAnkiPackage(legacyPackage(), now: now);
    final s = a.addTo(before, keepSchedule: false, idPrefix: 'x', now: now);
    expect(s.decks.length, 2);
    expect(s.decks.first.toJson(), before.decks.first.toJson());
    expect(s.cards.length, 10);
    expect(s.cards.every((c) => c.reviewCount == 0 && c.dueAt == now), isTrue);
    final reverse = s.cards.firstWhere((c) => c.id == 'x_202');
    expect(reverse.reversed, isTrue);
    expect(reverse.question, 'dog');
    expect(reverse.imageOnQuestion, isTrue);
    expect(reverse.note, s.cards.firstWhere((c) => c.id == 'x_201').note);
    expect(s.cards.firstWhere((c) => c.id == 'x_401').note, '');
    // The result survives a backup roundtrip unchanged.
    expect(parseRecallBackup(exportRecallBackup(s)).toJson(), s.toJson());
  });

  test('keep schedule maps Anki review state onto Recall', () {
    final a = readAnkiPackage(modernPackage(), now: now);
    final s = a.addTo(library(), keepSchedule: true, idPrefix: 'k', now: now);
    final review = s.cards.firstWhere((c) => c.id == 'k_101');
    expect(review.intervalDays, 12);
    expect(review.ease, closeTo(2.3, 1e-9));
    expect(review.reviewCount, 5);
    expect(review.lapses, 1);
    // Due day 10 counted from the collection's creation.
    expect(review.dueAt, '2023-11-24T22:13:20.000Z');
    expect(review.lastReviewedAt, '2023-11-12T22:13:20.000Z');
    // Learning steps do not exist in Recall: due now, history kept.
    final learning = s.cards.firstWhere((c) => c.id == 'k_301');
    expect((learning.reviewCount, learning.dueAt), (1, now));
    final fresh = s.cards.firstWhere((c) => c.id == 'k_302');
    expect(fresh.reviewCount, 0);
    // The scheduler takes over from there.
    expect(
      reviewCard(review, 'good', now: now).intervalDays,
      closeTo(12 * 2.3, 1e-9),
    );
  });

  test('limits are checked before anything is written', () {
    final a = readAnkiPackage(legacyPackage(), now: now);
    final full = RecallState(
      decks: [const RecallDeck(id: 'd', name: 'D')],
      cards: List.generate(
        recallCardLimit - 5,
        (i) =>
            createCard(id: 'c$i', deckId: 'd', front: 'q', back: 'a', now: now),
      ),
    );
    expect(
      () => a.addTo(full, keepSchedule: false, idPrefix: 'x', now: now),
      throwsFormatException,
    );
  });

  test('not an Anki package, damage and unsafe names are refused', () {
    expect(
      () => readAnkiPackage(Uint8List.fromList([1, 2, 3]), now: now),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'm',
          contains('not an Anki'),
        ),
      ),
    );
    expect(
      () => readAnkiPackage(
        zip({
          'notes.txt': [1, 2],
        }),
        now: now,
      ),
      throwsFormatException,
    );
    expect(
      () => readAnkiPackage(
        zip({
          'collection.anki21': [1, 2, 3],
          '../evil': [1],
        }),
        now: now,
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'm',
          contains('unsafe'),
        ),
      ),
    );
    expect(
      () => readAnkiPackage(
        zip({'collection.anki21': List.filled(600, 7)}),
        now: now,
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'm',
          contains('damaged'),
        ),
      ),
    );
  });

  test('a stored entry whose CRC no longer matches is damaged', () {
    final bytes = legacyPackage(stored: true);
    expect(readAnkiPackage(bytes, now: now).cards, hasLength(10));
    // Flip a byte inside the stored media JSON: only the CRC can tell.
    final at = _find(bytes, '"dog.png"'.codeUnits);
    expect(at, greaterThan(0));
    bytes[at + 2] ^= 0x20;
    expect(
      () => readAnkiPackage(bytes, now: now),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'm',
          contains('damaged'),
        ),
      ),
    );
  });

  test('a newer package that cannot be read says how to re-export', () {
    final broken = zip({
      'collection.anki21b': zstd(List.filled(2000, 1)),
      'meta': pbInt(1, 3),
    });
    expect(
      () => readAnkiPackage(broken, now: now),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'm',
          contains('Support older Anki versions'),
        ),
      ),
    );
  });

  group('SQLite reader', () {
    test('matches SQLite on rowid, overflow, WITHOUT ROWID and wide ints', () {
      final long = List.generate(
        30000,
        (i) => String.fromCharCode(0x61 + i % 26),
      ).join();
      final bytes = sqliteFile((db) {
        db.execute(
          'CREATE TABLE t (id integer primary key, a text, b blob, c real, d int)',
        );
        db.execute(
          'CREATE TABLE w (k text NOT NULL, n integer NOT NULL, v text, PRIMARY KEY (n, k)) without rowid',
        );
        final insert = db.prepare('INSERT INTO t VALUES (?,?,?,?,?)');
        for (var i = 1; i <= 1500; i++) {
          insert.execute([
            i * 7,
            i % 100 == 0 ? '$long$i' : 'row $i ✓',
            Uint8List.fromList([i % 256, 0, 255]),
            i / 3,
            [
              0,
              1,
              -1,
              127,
              -129,
              40000,
              -8388609,
              2147483648,
              -1700000000000,
              9007199254740991,
            ][i % 10],
          ]);
        }
        insert.close();
        final w = db.prepare('INSERT INTO w VALUES (?,?,?)');
        for (var i = 0; i < 800; i++) {
          w.execute(['k$i', i % 37, i % 50 == 0 ? long : 'v$i']);
        }
        w.close();
      });
      final reader = SqliteFile(bytes);
      final rows = reader.rows('t').toList();
      expect(rows.length, 1500);
      expect(rows.first['id'], 7);
      expect(rows[99]['a'], '$long${100}');
      expect(rows[3]['d'], -129);
      expect(rows[6]['d'], 2147483648);
      expect(rows[7]['d'], -1700000000000);
      expect(rows[8]['d'], 9007199254740991);
      expect(rows[2]['c'], closeTo(1.0, 1e-12));
      expect(rows[4]['b'], [5, 0, 255]);
      final w = reader.rows('w').toList();
      expect(w.length, 800);
      final byKey = {for (final r in w) r['k']: r};
      expect(byKey['k50']!['v'], long);
      expect(byKey['k38']!['n'], 1);
      expect(byKey['k38']!['v'], 'v38');
    });

    test('rejects what is not SQLite', () {
      expect(() => SqliteFile(Uint8List(600)), throwsFormatException);
    });
  });
}

int _find(Uint8List hay, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= hay.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}
