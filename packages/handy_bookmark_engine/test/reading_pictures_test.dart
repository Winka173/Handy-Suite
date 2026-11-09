import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

const page = '''<html><head><title>Phở</title></head><body><article>
<p>Phở is a soup of broth, rice noodles and herbs, eaten at any hour in Hà Nội and far beyond.</p>
<img src="/bowl.jpg" alt="A bowl of phở" width="800" height="600">
<p>The broth simmers for hours with charred onion, ginger, star anise and cinnamon until it is clear.</p>
<img data-src="https://cdn.example.com/lazy.jpg" src="data:image/gif;base64,R0lGOD">
<img src="/icon.png" width="24" height="24">
<img srcset="/small.jpg 400w, /large.jpg 1200w">
<p>Eat it hot, with lime, chilli and a little fish sauce, and drink the last of the broth from the bowl.</p>
<img src="/footer-ad.jpg">
</article></body></html>''';

Uint8List jpeg(int n) =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, ...List.filled(n, 1)]);

void main() {
  final copy = extractReadingCopy(
    page,
    url: 'https://food.example.vn/pho',
    savedAt: '2026-11-09T08:00:00Z',
  )!;

  test('pictures keep their place; icons, inline images and the tail go', () {
    final pics = copy.blocks.where((b) => b.isPicture).toList();
    expect(pics.map((b) => b.url), [
      'https://food.example.vn/bowl.jpg',
      'https://cdn.example.com/lazy.jpg',
      'https://food.example.vn/large.jpg',
    ]);
    expect(pics.first.text, 'A bowl of phở');
    expect(copy.blocks.last.isPicture, isFalse);
    expect(copy.words, greaterThan(40), reason: 'pictures add no words');
  });

  test('kept pictures round-trip inside the copy (format 2)', () {
    final slots = copy.pictureSlots;
    final kept = copy.withPictures({slots[0]: jpeg(10), slots[2]: jpeg(20)});
    final json = kept.toJson();
    expect(json['v'], ReadingCopy.version);
    final back = ReadingCopy.fromJson(json);
    expect(back.blocks[slots[0]].picture, jpeg(10));
    expect(back.blocks[slots[1]].picture, isNull);
    expect(back.pictureBytes, 36, reason: 'two JPEGs: 13 and 23 bytes');
    expect(back.chars, copy.chars);
  });

  test('a picture that is not a JPEG, or too many bytes, is refused', () {
    final slot = copy.pictureSlots.first;
    expect(
      () => copy.withPictures({
        slot: Uint8List.fromList([1, 2, 3, 4]),
      }),
      throwsFormatException,
    );
    expect(
      () => copy.withPictures({
        for (final s in copy.pictureSlots)
          s: jpeg(ReadingBlock.maxPictureBytes),
      }),
      throwsFormatException,
    );
  });

  test('an older copy without pictures still reads', () {
    final old = ReadingCopy.fromJson({
      'url': 'https://a.example/x',
      'title': 'x',
      'savedAt': '2026-11-01T00:00:00Z',
      'blocks': [
        {'k': 'p', 't': 'Just text, as copies were before pictures.'},
      ],
    });
    expect(old.pictureSlots, isEmpty);
    expect(old.toJson().containsKey('v'), isFalse);
  });
}
