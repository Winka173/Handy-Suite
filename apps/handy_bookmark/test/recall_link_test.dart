import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/links/recall_link.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

void main() {
  test('a link becomes a pre-filled card for Recall', () {
    final b = Bookmark(
      id: 'b',
      originalUrl: 'https://example.org/a?x=1',
      normalizedUrl: 'https://example.org/a?x=1',
      title: 'Bài viết hay',
      note: 'Đọc lại phần 2',
      savedAt: '2026-11-02T00:00:00Z',
      updatedAt: '2026-11-02T00:00:00Z',
    );
    final uri = recallLink(b);
    expect(uri.scheme, 'handy-recall');
    expect(uri.host, 'new');
    expect(uri.queryParameters['front'], 'Bài viết hay');
    expect(
      uri.queryParameters['back'],
      'https://example.org/a?x=1\nĐọc lại phần 2',
    );
  });
}
