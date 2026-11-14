import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

void main() {
  (String, String) kind(String url) {
    final u = UrlTools.normalize(url);
    return (u.platform, u.contentType);
  }

  String canon(String url) => UrlTools.normalize(url).canonicalUrl;

  test('YouTube Music is music, kept apart from the video page', () {
    expect(kind('https://music.youtube.com/watch?v=dQw4w9WgXcQ&si=abc'), (
      'youtube_music',
      'audio',
    ));
    expect(kind('https://music.youtube.com/playlist?list=PL1'), (
      'youtube_music',
      'playlist',
    ));
    expect(
      canon('https://music.youtube.com/watch?v=dQw4w9WgXcQ&si=abc'),
      isNot(canon('https://www.youtube.com/watch?v=dQw4w9WgXcQ')),
    );
  });

  test('a Short or video shared twice is the same link (si, feature)', () {
    expect(
      canon('https://youtube.com/shorts/8xkEICotpOM?si=FinalTest03'),
      canon('https://www.youtube.com/shorts/8xkEICotpOM'),
    );
    expect(
      canon('https://youtu.be/dQw4w9WgXcQ?si=x&feature=shared'),
      canon('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
    );
    // A real parameter stays: a start time is part of what was saved.
    expect(canon('https://youtu.be/dQw4w9WgXcQ?t=42&si=x'), contains('t=42'));
  });

  test('share ids of each app are dropped for duplicates, the rest kept', () {
    for (final (a, b) in [
      (
        'https://www.instagram.com/reel/C1/?igsh=MWQ1ZGUxMzBkMA==',
        'https://www.instagram.com/reel/C1/',
      ),
      (
        'https://www.tiktok.com/@a/video/1?_r=1&_t=8x&is_from_webapp=1&sender_device=pc',
        'https://www.tiktok.com/@a/video/1',
      ),
      (
        'https://www.facebook.com/share/r/abc/?mibextid=wwXIfr',
        'https://www.facebook.com/share/r/abc/',
      ),
      ('https://x.com/X/status/1?s=21&t=ab', 'https://x.com/X/status/1'),
      (
        'https://www.reddit.com/r/FlutterDev/comments/1/x/?share_id=Z',
        'https://www.reddit.com/r/FlutterDev/comments/1/x/',
      ),
      (
        'https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC?si=abc',
        'https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC',
      ),
      (
        'https://www.lazada.vn/products/i1.html?spm=a2o4n&laz_trackid=2',
        'https://www.lazada.vn/products/i1.html',
      ),
      (
        'https://shopee.vn/product/1/2?sp_atk=x&xptdk=y',
        'https://shopee.vn/product/1/2',
      ),
    ]) {
      expect(canon(a), canon(b), reason: a);
    }
    // Only on its own platform: a site with its own "s" keeps it.
    expect(canon('https://example.com/search?s=21'), contains('s=21'));
  });

  test('food and places: ShopeeFood, Foody, Grab', () {
    expect(kind('https://shopeefood.vn/ha-noi/pho-thin-lo-duc'), (
      'shopeefood',
      'place',
    ));
    expect(kind('https://www.foody.vn/ha-noi/pho-thin-lo-duc'), (
      'foody',
      'place',
    ));
    expect(kind('https://food.grab.com/vn/vi/restaurant/pho-thin-delivery/1'), (
      'grab',
      'place',
    ));
    expect(kind('https://r.grab.com/g/6-20261114-abc'), ('grab', 'place'));
    expect(kind('https://www.grab.com/vn/'), ('grab', 'link'));
  });

  test('shopping: Tiki, Lazada short links, Shopee', () {
    expect(kind('https://tiki.vn/sach-abc-p123.html'), ('tiki', 'shopping'));
    expect(kind('https://ti.ki/abc'), ('tiki', 'shopping'));
    expect(kind('https://s.lazada.vn/s.abc'), ('lazada', 'shopping'));
    expect(kind('https://shopee.vn/product/1/2'), ('shopee', 'shopping'));
  });

  test('Pinterest in every country, pins are pictures', () {
    expect(kind('https://pin.it/2abcDEF'), ('pinterest', 'image'));
    expect(kind('https://vn.pinterest.com/pin/123/'), ('pinterest', 'image'));
    expect(kind('https://www.pinterest.co.uk/pin/123/'), (
      'pinterest',
      'image',
    ));
    expect(kind('https://www.pinterest.com/someone/'), (
      'pinterest',
      'profile',
    ));
    expect(
      kind('https://notpinterest.com/pin/1'),
      isNot(('pinterest', 'image')),
    );
  });

  test('Spotify: tracks and episodes are audio, albums and playlists are '
      'lists, artists are profiles', () {
    expect(kind('https://open.spotify.com/track/1'), ('spotify', 'audio'));
    expect(kind('https://open.spotify.com/intl-vi/track/1'), (
      'spotify',
      'audio',
    ));
    expect(kind('https://open.spotify.com/episode/1'), ('spotify', 'audio'));
    expect(kind('https://open.spotify.com/album/1'), ('spotify', 'playlist'));
    expect(kind('https://open.spotify.com/playlist/1'), (
      'spotify',
      'playlist',
    ));
    expect(kind('https://open.spotify.com/artist/1'), ('spotify', 'profile'));
    expect(kind('https://spotify.link/abc'), ('spotify', 'audio'));
  });
}
