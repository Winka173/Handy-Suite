import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart' show sharedPageTitle;
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

void main() {
  String? title(String text) =>
      sharedPageTitle(text, UrlTools.extract(text).single);

  test('a browser\'s "title + link" names a web page', () {
    expect(
      title(
        'Hà Nội – Wikipedia tiếng Việt https://vi.wikipedia.org/wiki/Ha_Noi',
      ),
      'Hà Nội – Wikipedia tiếng Việt',
    );
    expect(
      title('https://vnexpress.net/a.html\nGiá vàng hôm nay | VnExpress'),
      'Giá vàng hôm nay | VnExpress',
    );
    expect(title('Bài hay - https://example.com/x -'), 'Bài hay');
  });

  test('nothing worth a title, or a social app\'s words, give none', () {
    expect(title('https://example.com/x'), isNull);
    expect(title(' - https://example.com/x | '), isNull);
    expect(title('123 https://example.com/x'), isNull);
    expect(
      title("Check out TikTok's video! https://www.tiktok.com/@tiktok/video/1"),
      isNull,
    );
    expect(title('Xem nè https://www.facebook.com/share/r/abc/'), isNull);
  });
}
