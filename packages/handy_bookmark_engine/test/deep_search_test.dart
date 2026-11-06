import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

void main() {
  final article =
      'Hà Giang đẹp quanh năm. Tháng 10 là mùa hoa tam giác mạch nở rộ '
      'ở Đồng Văn, khi trời hanh và nắng nhẹ suốt cả ngày dài.';
  const mark = Highlight(
    id: 'h',
    block: 0,
    start: 0,
    end: 9,
    quote: 'Đèo Mã Pì Lèng',
    note: 'Đi sớm trước 7 giờ',
    createdAt: '2026-11-06T10:00:00Z',
  );

  test('words inside an article, a highlight or a picture find the item, '
      'without accents, with the source and a real passage', () {
    final hits = deepSearch(
      'tam giac mach',
      articles: {'a': article, 'b': 'Phở bò Hà Nội'},
    );
    expect(hits.single.id, 'a');
    expect(hits.single.source, DeepSource.article);
    expect(hits.single.snippet, contains('tam giác mạch'));
    expect(
      deepSearch(
        '7 gio',
        highlights: {
          'h': [mark],
        },
      ).single.source,
      DeepSource.highlight,
    );
    expect(
      deepSearch('bảng giá', pictureText: {'p': 'BẢNG GIÁ 2026'}).single.source,
      DeepSource.picture,
    );
  });

  test('every word must be there; items already found and blank queries '
      'give nothing; one hit per item, the most personal source first', () {
    expect(deepSearch('hoa sen', articles: {'a': article}), isEmpty);
    expect(
      deepSearch('hoa', articles: {'a': article}, exclude: {'a'}),
      isEmpty,
    );
    expect(deepSearch('  ', articles: {'a': article}), isEmpty);
    final both = deepSearch(
      'đèo',
      articles: {'h': 'Qua đèo Mã Pì Lèng'},
      highlights: {
        'h': [mark],
      },
    );
    expect(both.single.source, DeepSource.highlight);
  });

  test('the passage is short and marks where it was cut', () {
    final long = '${'chữ ' * 60}phở cuốn${' chữ' * 60}';
    final s = deepSearch('pho cuon', articles: {'a': long}).single.snippet;
    expect(s.length, lessThan(140));
    expect(s, startsWith('…'));
    expect(s, endsWith('…'));
    expect(s, contains('phở cuốn'));
  });
}
