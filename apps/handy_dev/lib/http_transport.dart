import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:handy_core/handy_core.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';

class ApiResponse {
  final int status;
  final int bytes;
  final String body;
  final int elapsedMs;
  const ApiResponse(this.status, this.bytes, this.body, this.elapsedMs);
}

class HttpTransport {
  final http.Client Function() clientFactory;
  http.Client? _client;
  bool _cancelled = false;
  HttpTransport({http.Client Function()? clientFactory})
    : clientFactory = clientFactory ?? http.Client.new;
  void cancel() {
    _cancelled = true;
    _client?.close();
  }

  Future<ApiResponse> send(
    PreparedRequest request, {
    Duration timeout = const Duration(seconds: 15),
    int maxBytes = 1000000,
  }) async {
    if (_client != null) throw StateError('A request is already running');
    if (Uri.parse(request.url).scheme != 'https')
      throw const FormatException('HTTPS is required');
    final client = clientFactory();
    _client = client;
    _cancelled = false;
    final watch = Stopwatch()..start();
    try {
      Future<ApiResponse> perform() async {
        final outgoing = http.Request(request.method, Uri.parse(request.url))
          ..headers.addAll(request.headers)
          ..followRedirects = false;
        if (!['GET', 'HEAD'].contains(request.method))
          outgoing.body = request.body;
        final response = await client.send(outgoing);
        if (response.contentLength != null &&
            response.contentLength! > maxBytes)
          throw const FormatException('Response exceeds 1 MB limit');
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (_cancelled) throw const Cancelled();
          if (bytes.length + chunk.length > maxBytes)
            throw const FormatException('Response exceeds 1 MB limit');
          bytes.addAll(chunk);
        }
        if (_cancelled) throw const Cancelled();
        return ApiResponse(
          response.statusCode,
          bytes.length,
          utf8.decode(bytes, allowMalformed: true),
          watch.elapsedMilliseconds,
        );
      }

      return await perform().timeout(timeout);
    } on Cancelled {
      rethrow;
    } on TimeoutException {
      throw TimeoutException(
        'Request timed out; no request details were logged.',
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      if (_cancelled) throw const Cancelled();
      throw StateError(
        'Request failed. Check TLS, connectivity, server policy, or browser CORS. Credentials were not logged.',
      );
    } finally {
      client.close();
      _client = null;
    }
  }
}
