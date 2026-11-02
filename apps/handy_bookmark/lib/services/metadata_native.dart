import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:handy_core/handy_core.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart'
    show LinkProbe;
import 'metadata_client.dart';
import 'metadata_parser.dart';
import 'metadata_policy.dart';

class _MetadataFailure implements Exception {
  const _MetadataFailure(this.code);
  final String code;
}

class _Response {
  const _Response(
    this.bytes,
    this.uri,
    this.mime,
    this.status, {
    this.charset,
    this.permanentUrl,
  });
  final Uint8List bytes;
  final Uri uri;
  final String mime;
  final int status;
  final String? charset, permanentUrl;
}

typedef AddressLookup = Future<List<InternetAddress>> Function(String host);
typedef SocketConnect =
    Future<ConnectionTask<Socket>> Function(InternetAddress address, int port);

class PlatformMetadataClient implements MetadataClient {
  /// [lookup] and [connect] exist for tests that serve pages locally; the
  /// public-address check still applies to whatever [lookup] returns.
  PlatformMetadataClient({
    @visibleForTesting AddressLookup? lookup,
    @visibleForTesting SocketConnect? connect,
    @visibleForTesting this.hostSpacing = const Duration(seconds: 2),
  }) : _lookup = lookup ?? InternetAddress.lookup,
       _connect = connect ?? Socket.startConnect;
  final AddressLookup _lookup;
  final SocketConnect _connect;

  /// Requests to one host start at least this far apart.
  final Duration hostSpacing;
  final _clients = <HttpClient>{};
  final _lastHost = <String, DateTime>{};
  int _active = 0;
  bool _disposed = false;

  @override
  bool get available => true;

  @override
  Future<MetadataResult> fetch(
    String url, {
    CancellationToken? cancellation,
  }) async {
    try {
      final response = await _exchange(
        url,
        accept: 'text/html,application/xhtml+xml',
        maxBytes: metadataMaxHtmlBytes,
        mimes: const {'text/html', 'application/xhtml+xml'},
        cancellation: cancellation,
      );
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
      final response = await _exchange(
        url,
        accept: 'image/png,image/jpeg,image/webp',
        maxBytes: metadataMaxThumbnailBytes,
        mimes: const {'image/png', 'image/jpeg', 'image/webp'},
        cancellation: cancellation,
      );
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

  @override
  Future<PageResult> fetchPage(
    String url, {
    CancellationToken? cancellation,
  }) async {
    try {
      final r = await _exchange(
        url,
        accept: 'text/html,application/xhtml+xml',
        maxBytes: readingMaxHtmlBytes,
        mimes: const {'text/html', 'application/xhtml+xml'},
        timeout: readingTimeout,
        cancellation: cancellation,
      );
      cancellation?.check();
      final latin = {
        'iso-8859-1',
        'latin1',
        'windows-1252',
        'us-ascii',
      }.contains(r.charset?.toLowerCase());
      return PageResult(
        html: latin
            ? latin1.decode(r.bytes)
            : utf8.decode(r.bytes, allowMalformed: true),
        uri: r.uri,
      );
    } catch (error) {
      return PageResult(errorCode: _errorCode(error));
    }
  }

  @override
  Future<LinkProbe> probe(String url, {CancellationToken? cancellation}) async {
    // One probe may ask the same host twice (HEAD, then GET).
    final hosts = <String>{};
    Future<_Response> ask(String method) => _exchange(
      url,
      method: method,
      accept: '*/*',
      maxBytes: 0,
      anyStatus: true,
      maxRedirects: linkCheckMaxRedirects,
      visitedHosts: hosts,
      cancellation: cancellation,
    );
    try {
      _Response? head;
      try {
        head = await ask('HEAD');
      } on _MetadataFailure catch (e) {
        if (e.code.startsWith('unsafe') || e.code == 'disposed') rethrow;
      } on TimeoutException {
        // Some servers ignore HEAD; GET decides.
      } on SocketException {
        // As above.
      } on HttpException {
        // As above.
      }
      cancellation?.check();
      final ok = head != null && head.status >= 200 && head.status < 300;
      final r = ok ? head : await ask('GET');
      return LinkProbe(status: r.status, permanentUrl: r.permanentUrl);
    } catch (error) {
      if (error is Cancelled) rethrow;
      return LinkProbe(error: _errorCode(error));
    }
  }

  String _errorCode(Object error) => switch (error) {
    _MetadataFailure(:final code) => code,
    Cancelled() => 'cancelled',
    TimeoutException() => 'timeout',
    _ => 'networkUnavailable',
  };

  /// One request through the safe policy: public addresses only, resolved
  /// and pinned on every hop, redirects re-checked, bounded bytes and time,
  /// cancellable. [maxBytes] 0 reads no body; [anyStatus] returns non-200
  /// answers instead of failing (link checks).
  Future<_Response> _exchange(
    String input, {
    String method = 'GET',
    required String accept,
    required int maxBytes,
    Set<String>? mimes,
    bool anyStatus = false,
    int maxRedirects = metadataMaxRedirects,
    Duration timeout = metadataTimeout,
    Set<String>? visitedHosts,
    CancellationToken? cancellation,
  }) async {
    cancellation?.check();
    if (_disposed) throw const _MetadataFailure('disposed');
    var uri = publicMetadataUri(input);
    if (uri == null) throw const _MetadataFailure('unsafeUrl');
    if (_active >= 2) throw const _MetadataFailure('busy');
    _active++;
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = Duration.zero
      ..maxConnectionsPerHost = 1
      ..findProxy = ((_) => 'DIRECT')
      ..autoUncompress = true;
    _clients.add(client);
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      client.close(force: true);
    });
    final cancelTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (cancellation?.isCancelled == true) client.close(force: true);
    });
    try {
      return await (() async {
        final hosts = visitedHosts ?? <String>{};
        var permanent = true;
        String? permanentUrl;
        for (var redirects = 0; redirects <= maxRedirects; redirects++) {
          cancellation?.check();
          final target = uri!;
          final now = DateTime.now();
          final last = _lastHost[target.host];
          if (!hosts.contains(target.host) &&
              last != null &&
              now.difference(last) < hostSpacing) {
            throw const _MetadataFailure('rateLimited');
          }
          if (_lastHost.length >= 128) _lastHost.remove(_lastHost.keys.first);
          _lastHost[target.host] = now;
          hosts.add(target.host);
          final addresses = await _lookup(target.host);
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
            return _connect(addresses.first, requested.port);
          };
          final request = await client.openUrl(method, target);
          request.followRedirects = false;
          request.persistentConnection = false;
          request.headers.set(HttpHeaders.acceptHeader, accept);
          request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
          final response = await request.close();
          cancellation?.check();
          if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
            if (redirects == maxRedirects) {
              throw const _MetadataFailure('tooManyRedirects');
            }
            final location = response.headers.value(HttpHeaders.locationHeader);
            uri = location == null
                ? null
                : publicMetadataUri(location, base: target);
            if (uri == null) throw const _MetadataFailure('unsafeRedirect');
            if (permanent && [301, 308].contains(response.statusCode)) {
              permanentUrl = uri.toString();
            } else {
              permanent = false;
            }
            // Do not consume arbitrary redirect bodies. Abort this connection.
            final socket = await response.detachSocket();
            socket.destroy();
            continue;
          }
          final mime =
              response.headers.contentType?.mimeType.toLowerCase() ?? '';
          if (maxBytes == 0 || (anyStatus && response.statusCode != 200)) {
            // A probe needs the answer, not the page.
            final socket = await response.detachSocket();
            socket.destroy();
            return _Response(
              Uint8List(0),
              target,
              mime,
              response.statusCode,
              permanentUrl: permanentUrl,
            );
          }
          if (response.statusCode != 200) {
            throw const _MetadataFailure('httpStatus');
          }
          if (mimes != null && !mimes.contains(mime)) {
            throw const _MetadataFailure('unsupportedContentType');
          }
          if (response.contentLength > maxBytes) {
            throw const _MetadataFailure('responseTooLarge');
          }
          final builder = BytesBuilder(copy: false);
          await for (final chunk in response) {
            cancellation?.check();
            if (builder.length + chunk.length > maxBytes) {
              throw const _MetadataFailure('responseTooLarge');
            }
            builder.add(chunk);
          }
          return _Response(
            builder.takeBytes(),
            target,
            mime,
            response.statusCode,
            charset: response.headers.contentType?.charset,
            permanentUrl: permanentUrl,
          );
        }
        throw const _MetadataFailure('tooManyRedirects');
      })().timeout(timeout);
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
