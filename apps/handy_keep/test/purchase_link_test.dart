import 'package:flutter_test/flutter_test.dart';
import 'package:handy_keep/inventory/purchase_link.dart';

void main() {
  test('a purchase from Spend pre-fills only what checks out', () {
    final p = PurchaseLink.parse(
      'handy-keep://new?name=M%C3%A1y%20xay%20sinh%20t%E1%BB%91&price=1290000&currency=VND&date=2026-11-02',
    )!;
    expect(p.name, 'Máy xay sinh tố');
    expect(p.price, '1290000');
    expect(p.currency, 'VND');
    expect(p.date, '2026-11-02');
    final odd = PurchaseLink.parse(
      'handy-keep://new?name=x&price=1e9&currency=XYZ&date=02/11/2026',
    )!;
    expect([odd.price, odd.currency, odd.date], ['', '', '']);
    expect(PurchaseLink.parse('handy-keep://item/abc'), isNull);
    expect(PurchaseLink.parse('https://new?name=x'), isNull);
    final long = PurchaseLink.parse('handy-keep://new?name=${'a' * 300}')!;
    expect(long.name.length, 120);
  });
}
