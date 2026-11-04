import 'dart:convert';
import 'api.dart';

/// One send, as the opt-in history keeps it: the request's own URL template
/// passed through [sanitizeRequest] (no user info, query values, fragment or
/// environment values), the method, and what came back. Never a header, a
/// body or a secret.
class SentRequest {
  final String at, requestId, name, method, url;

  /// The HTTP status, or null when nothing came back (no connection,
  /// cancelled).
  final int? status;
  final int elapsedMs, bytes;
  const SentRequest({
    required this.at,
    required this.requestId,
    required this.name,
    required this.method,
    required this.url,
    this.status,
    this.elapsedMs = 0,
    this.bytes = 0,
  });

  Map<String, Object?> toJson() => {
    'at': at,
    'requestId': requestId,
    'name': name,
    'method': method,
    'url': url,
    if (status != null) 'status': status,
    'elapsedMs': elapsedMs,
    'bytes': bytes,
  };
}

/// The history: off until the person turns it on, at most [sendHistoryLimit]
/// sends, newest first. Turning it off empties it.
class SendHistory {
  final bool on;
  final List<SentRequest> items;
  SendHistory({this.on = false, Iterable<SentRequest> items = const []})
    : items = List.unmodifiable(items);

  Map<String, Object?> toJson() => {
    'version': sendHistoryVersion,
    'on': on,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

const sendHistoryVersion = 1, sendHistoryLimit = 50;

/// Records [r] as sent with its answer. Nothing is kept while off.
SendHistory recordSend(
  SendHistory h,
  ApiRequest r, {
  required DateTime at,
  int? status,
  int elapsedMs = 0,
  int bytes = 0,
}) {
  if (!h.on) return h;
  final safe = sanitizeRequest(r);
  return SendHistory(
    on: true,
    items: [
      SentRequest(
        at: at.toUtc().toIso8601String(),
        requestId: safe.id,
        name: safe.name,
        method: safe.method,
        url: safe.url,
        status: status,
        elapsedMs: elapsedMs,
        bytes: bytes,
      ),
      ...h.items,
    ].take(sendHistoryLimit),
  );
}

SendHistory switchSendHistory(SendHistory h, bool on) =>
    on ? SendHistory(on: true, items: h.items) : SendHistory();

/// Reads a stored history; anything malformed fails whole, so the caller
/// can start empty instead of showing half of it.
SendHistory parseSendHistory(String text) {
  final j = jsonDecode(text);
  if (j is! Map || j['version'] != sendHistoryVersion)
    throw const FormatException('Unknown history / Lịch sử không hợp lệ');
  final items = j['items'];
  if (j['on'] is! bool || items is! List || items.length > sendHistoryLimit)
    throw const FormatException('Unknown history / Lịch sử không hợp lệ');
  String text_(Map m, String k) => m[k] is String
      ? m[k] as String
      : throw const FormatException('Unknown history / Lịch sử không hợp lệ');
  int int_(Map m, String k) => m[k] is int && (m[k] as int) >= 0
      ? m[k] as int
      : throw const FormatException('Unknown history / Lịch sử không hợp lệ');
  final out = <SentRequest>[];
  for (final i in items) {
    if (i is! Map)
      throw const FormatException('Unknown history / Lịch sử không hợp lệ');
    final status = i['status'];
    if (status != null && (status is! int || status < 100 || status > 999))
      throw const FormatException('Unknown history / Lịch sử không hợp lệ');
    DateTime.parse(text_(i, 'at'));
    out.add(
      SentRequest(
        at: text_(i, 'at'),
        requestId: text_(i, 'requestId'),
        name: text_(i, 'name'),
        method: text_(i, 'method'),
        url: text_(i, 'url'),
        status: status as int?,
        elapsedMs: int_(i, 'elapsedMs'),
        bytes: int_(i, 'bytes'),
      ),
    );
  }
  return SendHistory(on: j['on'] as bool, items: out);
}

String exportSendHistory(SendHistory h) => jsonEncode(h.toJson());
