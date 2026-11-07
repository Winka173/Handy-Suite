import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_bookmark/services/metadata_client.dart';
import 'package:handy_bookmark/services/metadata_parser.dart';
import 'package:handy_bookmark/services/metadata_stub.dart' as web;

void main() {
  final source = Uri.parse('https://public.org/article/read');
  test('parses actual HTML with OG, card, standard metadata precedence', () {
    final result = parseMetadataHtml(
      utf8.encode('''
      <title>Standard &amp; safe</title>
      <meta name="description" content="Standard description">
      <meta name="twitter:title" content="Card title">
      <meta property="og:title" content="OG &amp; title">
      <meta property="og:site_name" content="Site">
      <meta name="author" content="Author">
      <meta property="og:image" content="../thumb.jpg">
      <link rel="alternate canonical" href="/original">
      <script>document.title='Executed'</script>
    '''),
      source,
    );
    expect(result.title, 'OG & title');
    expect(result.description, 'Standard description');
    expect(result.siteName, 'Site');
    expect(result.author, 'Author');
    expect(result.thumbnailUrl, 'https://public.org/thumb.jpg');
    expect(result.canonicalUrl, 'https://public.org/original');
    expect(result.status, 'complete');
  });
  test(
    'hostile document base and unsafe canonical/image targets are ignored',
    () {
      for (final target in [
        'javascript:alert(1)',
        'http://127.0.0.1/',
        'http://[::1]/',
        'http://2130706433/',
        'https://user:pass@public.org/',
        'data:image/png,abc',
        '//internal.local/image',
      ]) {
        final result = parseMetadataHtml(
          utf8.encode('''
        <base href="http://127.0.0.1/">
        <link rel="canonical" href="$target">
        <meta property="og:image" content="$target">
      '''),
          source,
        );
        expect(result.canonicalUrl, isNull, reason: target);
        expect(result.thumbnailUrl, isNull, reason: target);
      }
      final result = parseMetadataHtml(
        utf8.encode('''
      <base href="http://127.0.0.1/">
      <meta property="og:image" content="relative.jpg">
    '''),
        source,
      );
      expect(result.thumbnailUrl, 'https://public.org/article/relative.jpg');
    },
  );
  test('HTML hard byte cap permits boundary and rejects one byte more', () {
    expect(
      parseMetadataHtml(List.filled(metadataHeadMaxBytes, 32), source).status,
      'partial',
    );
    expect(
      parseMetadataHtml(
        List.filled(metadataHeadMaxBytes + 1, 32),
        source,
      ).errorCode,
      'responseTooLarge',
    );
    expect(metadataTimeout, const Duration(seconds: 8));
    expect(metadataMaxRedirects, 3);
    expect(metadataMaxThumbnailBytes, 1024 * 1024);
    expect(metadataMaxImagePixels, 2000000);
  });
  test(
    'pre-cancelled native operations return safely without network',
    () async {
      final client = MetadataClient();
      addTearDown(client.dispose);
      final cancellation = CancellationToken()..cancel();
      expect(
        (await client.fetch(
          'https://public.org',
          cancellation: cancellation,
        )).errorCode,
        'cancelled',
      );
      expect(
        (await client.fetchThumbnail(
          'https://public.org/a.jpg',
          cancellation: cancellation,
        )).errorCode,
        'cancelled',
      );
      expect((await client.fetch('http://127.0.0.1/')).errorCode, 'unsafeUrl');
    },
  );
  test(
    'browser adapter truthfully reports SSRF capability without fetching',
    () async {
      final client = web.PlatformMetadataClient();
      expect((await client.fetch('https://public.org')).status, 'unavailable');
      expect(
        (await client.fetch('https://public.org')).errorCode,
        'browserNetworkPolicy',
      );
      expect(
        (await client.fetchThumbnail('https://public.org/a.jpg')).available,
        isFalse,
      );
      client.dispose();
    },
  );
}
