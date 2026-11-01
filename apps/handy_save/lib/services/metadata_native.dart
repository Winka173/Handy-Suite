import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:handy_core/handy_core.dart';
import 'metadata_client.dart';
import 'metadata_parser.dart';
import 'metadata_policy.dart';

class _MetadataFailure implements Exception {
  const _MetadataFailure(this.code);
  final String code;
}

class _Response {
  const _Response(this.bytes, this.uri, this.mime);
  final Uint8List bytes;
  final Uri uri;
  final String mime;
}

class PlatformMetadataClient implements MetadataClient {
  final _clients = <HttpClient>{};
  final _lastHost = <String, DateTime>{};
  int _active = 0;
  bool _disposed = false;

  @override
  Future<MetadataResult> fetch(
    String url, {
    CancellationToken? cancellation,
  }) async {
    try {
      final response = await _get(url, false, cancellation);
      cancellation?.check();
      return parseMetadataHtml(response.bytes, response.uri);
    } catch (error) {
      return MetadataResult(status: 'failed', errorCode: _errorCode(error));
    }
  }

  @override
  Future<ThumbnailResult> fetchThumbnail(
    String url, {
    CancellationToken? cancellation,
  }) async {
    try {
      final response = await _get(url, true, cancellation);
      cancellation?.check();
      return sanitizeThumbnail(
        response.bytes,
        contentType: response.mime,
        cancellation: cancellation,
      );
    } catch (error) {
      return ThumbnailResult(errorCode: _errorCode(error));
    }
  }

  String _errorCode(Object error) => switch (error) {
    _MetadataFailure(:final code) => code,
    Cancelled() => 'cancelled',
    TimeoutException() => 'timeout',
    _ => 'networkUnavailable',
  };

  Future<_Response> _get(
    String input,
    bool thumbnail,
    CancellationToken? cancellation,
  ) async {
    cancellation?.check();
    if (_disposed) throw const _MetadataFailure('disposed');
    var uri = publicMetadataUri(input);
    if (uri == null) throw const _MetadataFailure('unsafeUrl');
    if (_active >= 2) throw const _MetadataFailure('busy');
    _active++;
    final client = HttpClient()
      ..connectionTimeout = metadataTimeout
      ..idleTimeout = Duration.zero
      ..maxConnectionsPerHost = 1
      ..findProxy = ((_) => 'DIRECT')
      ..autoUncompress = true;
    _clients.add(client);
    var timedOut = false;
    final timer = Timer(metadataTimeout, () {
      timedOut = true;
      client.close(force: true);
    });
    final cancelTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (cancellation?.isCancelled == true) client.close(force: true);
    });
    try {
      return await (() async {
        final visitedHosts = <String>{};
        for (
          var redirects = 0;
          redirects <= metadataMaxRedirects;
          redirects++
        ) {
          cancellation?.check();
          final target = uri!;
          final now = DateTime.now();
          final last = _lastHost[target.host];
          if (!visitedHosts.contains(target.host) &&
              last != null &&
              now.difference(last) < const Duration(seconds: 2)) {
            throw const _MetadataFailure('rateLimited');
          }
          if (_lastHost.length >= 128) _lastHost.remove(_lastHost.keys.first);
          _lastHost[target.host] = now;
          visitedHosts.add(target.host);
          final addresses = await InternetAddress.lookup(target.host);
          cancellation?.check();
          if (addresses.isEmpty ||
              addresses.any((a) => !isPublicMetadataAddress(a.address))) {
            throw const _MetadataFailure('unsafeAddress');
          }
          // HttpClient retains the original hostname for TLS verification and
          // Host, but its socket connects ONLY to the checked numeric address.
          // No second hostname lookup or environment proxy is involved.
          client.connectionFactory = (requested, proxyHost, proxyPort) {
            if (requested.host != target.host || proxyHost != null) {
              throw const _MetadataFailure('unsafeAddress');
            }
            return Socket.startConnect(addresses.first, requested.port);
          };
          final request = await client.getUrl(target);
          request.followRedirects = false;
          request.persistentConnection = false;
          request.headers.set(
            HttpHeaders.acceptHeader,
            thumbnail
                ? 'image/png,image/jpeg,image/webp'
                : 'text/html,application/xhtml+xml',
          );
          request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
          final response = await request.close();
          cancellation?.check();
          if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
            if (redirects == metadataMaxRedirects) {
              throw const _MetadataFailure('tooManyRedirects');
            }
            final location = response.headers.value(HttpHeaders.locationHeader);
            uri = location == null
                ? null
                : publicMetadataUri(location, base: target);
            if (uri == null) throw const _MetadataFailure('unsafeRedirect');
            // Do not consume arbitrary redirect bodies. Abort this connection.
            final socket = await response.detachSocket();
            socket.destroy();
            continue;
          }
          if (response.statusCode != 200) {
            throw const _MetadataFailure('httpStatus');
          }
          final mime =
              response.headers.contentType?.mimeType.toLowerCase() ?? '';
          if (!(thumbnail
                  ? ['image/png', 'image/jpeg', 'image/webp']
                  : ['text/html', 'application/xhtml+xml'])
              .contains(mime)) {
            throw const _MetadataFailure('unsupportedContentType');
          }
          final limit = thumbnail
              ? metadataMaxThumbnailBytes
              : metadataMaxHtmlBytes;
          if (response.contentLength > limit) {
            throw const _MetadataFailure('responseTooLarge');
          }
          final builder = BytesBuilder(copy: false);
          await for (final chunk in response) {
            cancellation?.check();
            if (builder.length + chunk.length > limit) {
              throw const _MetadataFailure('responseTooLarge');
            }
            builder.add(chunk);
          }
          return _Response(builder.takeBytes(), target, mime);
        }
        throw const _MetadataFailure('tooManyRedirects');
      })().timeout(metadataTimeout);
    } catch (error) {
      cancellation?.check();
      if (timedOut) throw TimeoutException('Metadata timeout');
      rethrow;
    } finally {
      timer.cancel();
      cancelTimer.cancel();
      client.close(force: true);
      _clients.remove(client);
      _active--;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final client in _clients) {
      client.close(force: true);
    }
  }
}
