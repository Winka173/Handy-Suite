import 'package:handy_recall/handy_recall.dart';
import 'package:test/test.dart';

List<String> marks(DictationCheck c) => [
  for (final w in c.words) '${w.mark.name}:${w.typed}/${w.expected}',
];

void main() {
  test('a right sentence is all right, whatever the case and commas', () {
    final c = checkDictation('Tôi đi học, mỗi ngày.', 'tôi đi học mỗi ngày');
    expect(c.allRight, isTrue);
    expect(c.rightCount, 5);
  });
  test('one wrong word stays one wrong word', () {
    final c = checkDictation('I have been to Hanoi', 'I have bean to Hanoi');
    expect(marks(c), [
      'right:I/I',
      'right:have/have',
      'wrong:bean/been',
      'right:to/to',
      'right:Hanoi/Hanoi',
    ]);
    expect(c.allRight, isFalse);
    expect(c.expectedCount, 5);
  });
  test('missing and extra words are told apart', () {
    expect(marks(checkDictation('a b c', 'a c')), [
      'right:a/a',
      'missing:/b',
      'right:c/c',
    ]);
    expect(marks(checkDictation('a b', 'a x b y')), [
      'right:a/a',
      'extra:x/',
      'right:b/b',
      'extra:y/',
    ]);
  });
  test('Vietnamese marks count unless accents are ignored', () {
    expect(checkDictation('Mẹ mua cá', 'Me mua ca').allRight, isFalse);
    expect(
      checkDictation('Mẹ mua cá', 'Me mua ca', ignoreAccents: true).allRight,
      isTrue,
    );
    expect(checkDictation('Paris', 'paris', matchCase: true).allRight, isFalse);
    expect(checkDictation('', 'anything').allRight, isFalse);
  });
}
