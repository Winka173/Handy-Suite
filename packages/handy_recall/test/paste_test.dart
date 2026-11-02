import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall/handy_recall.dart';

void main() {
  test('pasted lines become question and answer cards', () {
    final r = cardsFromPaste('''
- Paris – France
H2O: nước
2. Hello = Xin chào
A line with no answer
''');
    expect(r.mode, PasteMode.pairs);
    expect(r.cards, [
      ('Paris', 'France'),
      ('H2O', 'nước'),
      ('Hello', 'Xin chào'),
    ]);
    expect(r.skipped, 1);
  });

  test('marked words in sentences become blanks, one card per sentence', () {
    final r = cardsFromPaste(
      'Thủ đô của Pháp là **Paris**. Nước sôi ở [100] độ C và đông ở {0} độ. Câu không đánh dấu.',
    );
    expect(r.mode, PasteMode.cloze);
    expect(r.cards.map((c) => c.$1), [
      'Thủ đô của Pháp là {{c1::Paris}}.',
      'Nước sôi ở {{c1::100}} độ C và đông ở {{c2::0}} độ.',
    ]);
    expect(r.skipped, 1);
  });

  test('a paste is added through the card import', () {
    final r = cardsFromPaste(
      'Nước sôi ở [100] độ. Paris – "France"',
      mode: PasteMode.cloze,
    );
    final cards = importCardsCsv(pastedCsv(r.cards), 'd', 'p');
    expect(cards.length, 1);
    final pairs = cardsFromPaste('Q "x" – A', mode: PasteMode.pairs);
    expect(importCardsCsv(pastedCsv(pairs.cards), 'd', 'p').single.back, 'A');
  });
}
