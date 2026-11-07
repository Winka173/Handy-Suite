import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/services/metadata_parser.dart';

/// A TikTok video page as it reaches the app: generic page meta, and the
/// video in the page's data block further down (shape seen 2026-11-07).
String tiktokPage({int status = 0, String desc = 'Summer😊#Inverted '}) =>
    '''
<html><head><title>TikTok - Make Your Day</title>
<meta property="og:title" content="TikTok - Make Your Day"></head>
<body><script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">
${jsonEncode({
      '__DEFAULT_SCOPE__': {
        'webapp.video-detail': {
          'statusCode': status,
          'itemInfo': {
            'itemStruct': {
              'desc': desc,
              'author': {'uniqueId': 'looooooooch', 'nickname': 'leah halton'},
              'video': {'cover': 'https://p16-common-sign.tiktokcdn.com/cover.jpeg'},
            },
          },
          'shareMeta': {'title': 'leah halton on TikTok', 'desc': desc},
        },
      },
    })}
</script></body></html>''';

void main() {
  final video = Uri.parse(
    'https://www.tiktok.com/@looooooooch/video/7332342275151760642',
  );

  test('a TikTok video reads its caption, author and cover', () {
    final r = parseMetadataHtml(utf8.encode(tiktokPage()), video);
    expect(r.title, 'Summer😊#Inverted');
    expect(r.author, 'leah halton (@looooooooch)');
    expect(r.thumbnailUrl, 'https://p16-common-sign.tiktokcdn.com/cover.jpeg');
    expect(r.siteName, 'TikTok');
    expect(r.status, 'complete');
  });

  test('a TikTok video without a caption is named by its share title', () {
    final r = parseMetadataHtml(utf8.encode(tiktokPage(desc: '')), video);
    expect(r.title, 'leah halton on TikTok');
  });

  test('a TikTok page that says the video is gone keeps the page meta', () {
    final r = parseMetadataHtml(utf8.encode(tiktokPage(status: 10204)), video);
    expect(r.title, 'TikTok - Make Your Day');
    expect(r.thumbnailUrl, isNull);
  });

  test('a broken TikTok data block keeps the page meta', () {
    final page = tiktokPage().replaceFirst('"__DEFAULT_SCOPE__"', '{oops');
    final r = parseMetadataHtml(utf8.encode(page), video);
    expect(r.title, 'TikTok - Make Your Day');
  });

  test('an X or Threads post is titled by what it says', () {
    for (final (url, title) in [
      (
        'https://x.com/MrBeast/status/1055928398646784002',
        'MrBeast (@MrBeast) on X',
      ),
      (
        'https://www.threads.net/@mosseri/post/C0mMcrMLWKu',
        'Adam Mosseri (@mosseri) on Threads',
      ),
    ]) {
      final r = parseMetadataHtml(
        utf8.encode('''
        <meta property="og:title" content="$title">
        <meta property="og:description" content="“I bought a bunch of billboards”">
        <meta property="og:image" content="https://pbs.twimg.com/a.jpg">'''),
        Uri.parse(url),
      );
      expect(r.title, 'I bought a bunch of billboards', reason: url);
      expect(r.author, title.replaceFirst(RegExp(r' on \w+$'), ''));
      expect(r.thumbnailUrl, 'https://pbs.twimg.com/a.jpg');
    }
  });

  test('an X profile keeps its own title', () {
    final r = parseMetadataHtml(
      utf8.encode('''
      <meta property="og:title" content="Flutter">
      <meta property="og:description" content="Google's UI toolkit">'''),
      Uri.parse('https://x.com/FlutterDev'),
    );
    expect(r.title, 'Flutter');
  });

  test('a Reddit oEmbed answer gives the post title and author', () {
    final r = parseRedditOEmbed(
      utf8.encode(
        jsonEncode({
          'author_name': 'spez',
          'title': 'Addressing the community about changes to our API',
          'provider_name': 'reddit',
          'html': '<blockquote>…</blockquote>',
        }),
      ),
    );
    expect(r.title, 'Addressing the community about changes to our API');
    expect(r.author, 'u/spez');
    expect(r.siteName, 'Reddit');
    expect(parseRedditOEmbed(utf8.encode('{}')).title, isNull);
    expect(parseRedditOEmbed(utf8.encode('<html>')).status, 'failed');
  });
}
