/// A URL split into its parts, with query parameters decoded in order, and
/// rebuilt after the parameters change. Nothing is fetched.
library;

const maxQueryParameters = 1000;

class UrlParts {
  final Uri uri;
  final String scheme, user, host, path, fragment;
  final bool hasPassword;

  /// Port as written, or null when the URL relies on the scheme's default.
  final int? port;

  /// Decoded name/value pairs, duplicates and order kept.
  final List<(String, String)> query;
  const UrlParts._(
    this.uri, {
    required this.scheme,
    required this.user,
    required this.hasPassword,
    required this.host,
    required this.port,
    required this.path,
    required this.query,
    required this.fragment,
  });

  /// The URL with [query] in place of its parameters; every other part,
  /// including any credentials, is kept as written.
  String rebuild(List<(String, String)> query) {
    if (query.length > maxQueryParameters) {
      throw const FormatException(
        'At most $maxQueryParameters parameters / Tối đa $maxQueryParameters tham số',
      );
    }
    final b = StringBuffer('${uri.scheme}:');
    if (uri.hasAuthority) b.write('//${uri.authority}');
    b.write(uri.path);
    final pairs = [
      for (final (n, v) in query)
        if (n.isNotEmpty || v.isNotEmpty)
          '${Uri.encodeQueryComponent(n)}=${Uri.encodeQueryComponent(v)}',
    ];
    if (pairs.isNotEmpty) b.write('?${pairs.join('&')}');
    if (uri.hasFragment) b.write('#${uri.fragment}');
    return b.toString();
  }

  Map<String, dynamic> toJson() => {
    'scheme': scheme,
    if (user.isNotEmpty) 'user': user,
    if (hasPassword) 'password': '[hidden]',
    'host': host,
    'port': port,
    'path': path,
    'query': [
      for (final (n, v) in query) {'name': n, 'value': v},
    ],
    if (fragment.isNotEmpty) 'fragment': fragment,
  };
}

String _decode(String s, String what) {
  try {
    return Uri.decodeQueryComponent(s);
  } catch (_) {
    throw FormatException(
      'Invalid percent escape in the $what / Mã % không hợp lệ trong $what',
    );
  }
}

UrlParts parseUrl(String input) {
  final s = input.trim();
  if (s.isEmpty || s.length > 100000 || RegExp(r'\s').hasMatch(s)) {
    throw const FormatException(
      'Paste one URL without spaces, up to 100 KB / '
      'Dán một URL không có khoảng trắng, tối đa 100 KB',
    );
  }
  final Uri uri;
  try {
    uri = Uri.parse(s);
  } on FormatException catch (e) {
    throw FormatException('Not a valid URL: ${e.message} / URL không hợp lệ');
  }
  if (uri.scheme.isEmpty) {
    throw const FormatException(
      'Not an absolute URL: the scheme (https:) is missing / '
      'Không phải URL đầy đủ: thiếu scheme (https:)',
    );
  }
  final info = uri.userInfo;
  final colon = info.indexOf(':');
  final query = <(String, String)>[];
  if (uri.hasQuery && uri.query.isNotEmpty) {
    for (final part in uri.query.split('&')) {
      if (part.isEmpty) continue;
      final eq = part.indexOf('=');
      query.add(
        eq < 0
            ? (_decode(part, 'query'), '')
            : (
                _decode(part.substring(0, eq), 'query'),
                _decode(part.substring(eq + 1), 'query'),
              ),
      );
      if (query.length > maxQueryParameters) {
        throw const FormatException(
          'At most $maxQueryParameters parameters / Tối đa $maxQueryParameters tham số',
        );
      }
    }
  }
  String decoded(String v, String what) {
    try {
      return Uri.decodeComponent(v);
    } catch (_) {
      throw FormatException(
        'Invalid percent escape in the $what / Mã % không hợp lệ trong $what',
      );
    }
  }

  return UrlParts._(
    uri,
    scheme: uri.scheme,
    user: decoded(colon < 0 ? info : info.substring(0, colon), 'user'),
    hasPassword: colon >= 0,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: decoded(uri.path, 'path'),
    query: query,
    fragment: uri.hasFragment ? decoded(uri.fragment, 'fragment') : '',
  );
}

/// Port the scheme uses when none is written.
int? defaultPort(String scheme) => switch (scheme) {
  'http' || 'ws' => 80,
  'https' || 'wss' => 443,
  'ftp' => 21,
  _ => null,
};
