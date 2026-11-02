import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/services/metadata_native.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

const page =
    '<html><head><title>Kept</title></head><body><article><p>'
    'A long enough paragraph, with commas, to count as prose for the '
    'reader: it keeps going for a while so the extractor is satisfied.'
    '</p><p>And a second one, also long enough, so the copy is not empty '
    'and the reading view has something calm to show.</p></article>'
    '<script>EVIL()</script></body></html>';

void main() {
  late HttpServer server;
  late PlatformMetadataClient client;
  final methods = <String>[];
  setUp(() async {
    methods.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      methods.add('${r.method} ${r.uri.path}');
      final res = r.response;
      void go(int code, String to) {
        res.statusCode = code;
        res.headers.set(HttpHeaders.locationHeader, to);
      }

      switch (r.uri.path) {
        case '/head-refused':
          res.statusCode = r.method == 'HEAD' ? 405 : 200;
        case '/old':
          go(301, 'http://public.example.com/older');
        case '/older':
          go(308, '/new');
        case '/temp':
          go(302, '/new');
        case '/new':
          res.headers.contentType = ContentType.html;
          if (r.method != 'HEAD') res.write(page);
        case '/latin':
          res.headers.contentType = ContentType(
            'text',
            'html',
            charset: 'iso-8859-1',
          );
          res.add([...'<p>caf'.codeUnits, 0xE9, ...'</p>'.codeUnits]);
        case '/private':
          go(301, 'http://127.0.0.1/secret');
        case '/big':
          res.headers.contentType = ContentType.html;
          res.add(List.filled(readingMaxBytesForTest + 10, 32));
        case '/image':
          res.headers.contentType = ContentType('image', 'png');
          res.add([1, 2, 3]);
        default:
          res.statusCode = 404;
      }
      await res.close();
    });
    client = PlatformMetadataClient(
      lookup: (host) async => [InternetAddress('93.184.216.34')],
      connect: (address, port) =>
          Socket.startConnect(InternetAddress.loopbackIPv4, server.port),
      hostSpacing: Duration.zero,
    );
  });
  tearDown(() async {
    client.dispose();
    await server.close(force: true);
  });

  String at(String path) => 'http://public.example.com$path';

  test('HEAD first; GET only when HEAD is refused; no bodies', () async {
    expect((await client.probe(at('/new'))).status, 200);
    expect(methods, ['HEAD /new']);
    methods.clear();
    final p = await client.probe(at('/head-refused'));
    expect(p.status, 200);
    expect(methods, ['HEAD /head-refused', 'GET /head-refused']);
    expect((await client.probe(at('/nothing'))).status, 404);
  });

  test('permanent redirects are reported; temporary ones are not', () async {
    final moved = await client.probe(at('/old'));
    expect((moved.status, moved.permanentUrl), (200, at('/new')));
    expect(
      classifyLinkProbe(at('/old'), moved, '2026-11-02T00:00:00Z').status,
      'moved',
    );
    final temp = await client.probe(at('/temp'));
    expect((temp.status, temp.permanentUrl), (200, null));
  });

  test('redirects to private addresses are refused, not followed', () async {
    final p = await client.probe(at('/private'));
    expect((p.status, p.error), (null, 'unsafeRedirect'));
    expect(methods.where((m) => m.contains('secret')), isEmpty);
    final unsafe = PlatformMetadataClient(
      lookup: (host) async => [InternetAddress.loopbackIPv4],
      hostSpacing: Duration.zero,
    );
    expect((await unsafe.probe(at('/new'))).error, 'unsafeAddress');
    expect((await unsafe.fetchPage(at('/new'))).errorCode, 'unsafeAddress');
    unsafe.dispose();
  });

  test('pages: HTML only, bounded, charset respected', () async {
    final ok = await client.fetchPage(at('/old'));
    expect(ok.html, contains('Kept'));
    expect(ok.uri.toString(), at('/new'));
    expect((await client.fetchPage(at('/latin'))).html, contains('café'));
    expect(
      (await client.fetchPage(at('/image'))).errorCode,
      'unsupportedContentType',
    );
    expect((await client.fetchPage(at('/big'))).errorCode, 'responseTooLarge');
    expect((await client.fetchPage(at('/nothing'))).errorCode, 'httpStatus');
  });
}

/// The reading page limit (3 MB), restated so the test stays readable.
const readingMaxBytesForTest = 3 * 1024 * 1024;
