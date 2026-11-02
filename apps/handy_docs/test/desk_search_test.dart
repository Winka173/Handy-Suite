import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs/desk/desk_search.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';

ReaderDocument doc(String id, String name, String source) => ReaderDocument(
  id: id,
  name: name,
  kind: 'text',
  source: source,
  createdAt: '2026-11-01T00:00:00.000Z',
  lastOpenedAt: '2026-11-01T00:00:00.000Z',
);

void main() {
  test('kept files are searched without minding accents', () {
    final docs = [
      doc('a', 'Ghi chú.txt', 'Không có gì.'),
      doc('b', 'hop-dong.txt', 'Điều 1. Hợp đồng thuê nhà. Bên A ký hợp đồng.'),
      doc('c', 'thu.txt', 'Gửi kèm HỢP ĐỒNG mới.'),
    ];
    final hits = searchKept(docs, 'hop dong');
    expect(hits.map((h) => h.doc.id), ['b', 'c']);
    expect(hits.first.count, 2);
    expect(hits.first.match, 'Hợp đồng');
    expect(hits.first.before, 'Điều 1. ');
    expect(searchKept(docs, 'ghi chu').single.doc.id, 'a');
    expect(searchKept(docs, 'h'), isEmpty);
  });
}
