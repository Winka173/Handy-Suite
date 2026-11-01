import 'dart:convert';
import 'transforms.dart' show bounded;

Map<String, dynamic> _object(dynamic v) {
  if (v is! Map<String, dynamic>)
    throw const FormatException('Expected API object');
  return v;
}

String _text(dynamic v, [int max = 100000]) {
  if (v is! String || v.contains('\x00'))
    throw const FormatException('Invalid API text');
  return bounded(v, max);
}

final _identifier = RegExp(r'^[a-zA-Z0-9_-]{1,100}$');
final _variable = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]{0,99}$');

class ApiAuth {
  final String type, username, password, token, name, value, location;
  const ApiAuth.none()
    : type = 'none',
      username = '',
      password = '',
      token = '',
      name = '',
      value = '',
      location = 'header';
  const ApiAuth.basic({required this.username, required this.password})
    : type = 'basic',
      token = '',
      name = '',
      value = '',
      location = 'header';
  const ApiAuth.bearer(this.token)
    : type = 'bearer',
      username = '',
      password = '',
      name = '',
      value = '',
      location = 'header';
  const ApiAuth.apiKey({
    required this.name,
    required this.value,
    this.location = 'header',
  }) : type = 'api-key',
       username = '',
       password = '',
       token = '';
  Map<String, dynamic> toJson() => switch (type) {
    'basic' => {'type': type, 'username': username, 'password': password},
    'bearer' => {'type': type, 'token': token},
    'api-key' => {
      'type': type,
      'name': name,
      'value': value,
      'location': location,
    },
    _ => {'type': 'none'},
  };
  factory ApiAuth.fromJson(dynamic raw) {
    final a = _object(raw);
    return switch (a['type']) {
      'none' => const ApiAuth.none(),
      'basic' => ApiAuth.basic(
        username: _text(a['username'], 2000),
        password: _text(a['password'], 2000),
      ),
      'bearer' => ApiAuth.bearer(_text(a['token'], 8000)),
      'api-key' when ['header', 'query'].contains(a['location']) =>
        ApiAuth.apiKey(
          name: _text(a['name'], 100),
          value: _text(a['value'], 8000),
          location: a['location'],
        ),
      _ => throw const FormatException('Invalid authentication type'),
    };
  }
}

Map<String, String> validateHeaders(dynamic raw) {
  final input = _object(raw), result = <String, String>{}, seen = <String>{};
  if (input.length > 100) throw const FormatException('Header limit: 100');
  for (final e in input.entries) {
    if (!RegExp(
          r"^[!#$%&'*+.^_`|~0-9a-z-]{1,100}$",
          caseSensitive: false,
        ).hasMatch(e.key) ||
        RegExp(
          r'^(host|content-length|connection|transfer-encoding)$',
          caseSensitive: false,
        ).hasMatch(e.key) ||
        !seen.add(e.key.toLowerCase()))
      throw const FormatException('Invalid, duplicate or managed HTTP header');
    final value = _text(e.value, 8000);
    if (RegExp(r'[\r\n]').hasMatch(value))
      throw const FormatException('Header line breaks forbidden');
    result[e.key] = value;
  }
  return Map.unmodifiable(result);
}

class ApiRequest {
  final String id, name, url, method, body;
  final Map<String, String> headers;
  final ApiAuth auth;
  ApiRequest({
    required this.id,
    required this.name,
    required this.url,
    this.method = 'GET',
    this.body = '',
    Map<String, String> headers = const {},
    this.auth = const ApiAuth.none(),
  }) : headers = Map.unmodifiable(headers);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'method': method,
    'body': body,
    'headers': headers,
    'auth': auth.toJson(),
  };
  factory ApiRequest.fromJson(dynamic raw) {
    final r = _object(raw),
        id = _text(r['id'], 100),
        name = _text(r['name'], 200),
        method = _text(r['method'], 12).toUpperCase();
    if (!_identifier.hasMatch(id) ||
        name.trim().isEmpty ||
        !RegExp(r'^[A-Z]{3,12}$').hasMatch(method))
      throw const FormatException('Invalid request ID, name or method');
    return ApiRequest(
      id: id,
      name: name,
      url: _text(r['url'], 8000),
      method: method,
      body: _text(r['body']),
      headers: validateHeaders(r['headers']),
      auth: ApiAuth.fromJson(r['auth']),
    );
  }
  ApiRequest copyWith({
    String? id,
    String? name,
    String? url,
    String? method,
    String? body,
    Map<String, String>? headers,
    ApiAuth? auth,
  }) => ApiRequest(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url ?? this.url,
    method: method ?? this.method,
    body: body ?? this.body,
    headers: headers ?? this.headers,
    auth: auth ?? this.auth,
  );
}

ApiRequest validateRequest(ApiRequest r) => ApiRequest.fromJson(r.toJson());

class PreparedRequest {
  final String url, method, body;
  final Map<String, String> headers;
  PreparedRequest({
    required this.url,
    required this.method,
    required this.body,
    required Map<String, String> headers,
  }) : headers = Map.unmodifiable(headers);
}

ApiRequest resolveRequest(
  ApiRequest input, [
  Map<String, String> values = const {},
]) {
  String replace(String s) =>
      s.replaceAllMapped(RegExp(r'\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}'), (m) {
        final v = values[m[1]];
        if (v == null || v.isEmpty)
          throw FormatException('Environment variable required: ${m[1]}');
        return v;
      });
  final r = validateRequest(input), a = r.auth;
  final auth = switch (a.type) {
    'basic' => ApiAuth.basic(
      username: replace(a.username),
      password: replace(a.password),
    ),
    'bearer' => ApiAuth.bearer(replace(a.token)),
    'api-key' => ApiAuth.apiKey(
      name: replace(a.name),
      value: replace(a.value),
      location: a.location,
    ),
    _ => const ApiAuth.none(),
  };
  return validateRequest(
    r.copyWith(
      url: replace(r.url),
      body: replace(r.body),
      headers: {for (final e in r.headers.entries) e.key: replace(e.value)},
      auth: auth,
    ),
  );
}

PreparedRequest prepareRequest(
  ApiRequest input, [
  Map<String, String> values = const {},
]) {
  final r = resolveRequest(input, values),
      headers = Map<String, String>.of(r.headers),
      a = r.auth;
  Uri url;
  try {
    url = Uri.parse(r.url);
  } catch (_) {
    throw const FormatException('Invalid HTTPS URL');
  }
  if (url.scheme != 'https' ||
      url.host.isEmpty ||
      url.userInfo.isNotEmpty ||
      url.fragment.isNotEmpty)
    throw const FormatException(
      'HTTPS without embedded credentials or fragment required',
    );
  if (a.type != 'none' &&
      headers.keys.any((k) => k.toLowerCase() == 'authorization'))
    throw const FormatException(
      'Authentication conflicts with Authorization header',
    );
  if (a.type == 'basic') {
    if (a.username.contains(':'))
      throw const FormatException('Basic username cannot contain colon');
    headers['Authorization'] =
        'Basic ${base64.encode(utf8.encode('${a.username}:${a.password}'))}';
  }
  if (a.type == 'bearer') {
    if (a.token.trim().isEmpty)
      throw const FormatException('Bearer token required');
    headers['Authorization'] = 'Bearer ${a.token}';
  }
  if (a.type == 'api-key') {
    if (a.name.isEmpty || a.value.isEmpty)
      throw const FormatException('API key name and value required');
    if (a.location == 'query') {
      url = url.replace(
        queryParameters: {
          ...url.queryParametersAll,
          a.name: [a.value],
        },
      );
    } else {
      if (headers.keys.any((k) => k.toLowerCase() == a.name.toLowerCase()))
        throw const FormatException('API key conflicts with existing header');
      headers[a.name] = a.value;
    }
  }
  return PreparedRequest(
    url: url.toString(),
    method: r.method,
    body: r.body,
    headers: validateHeaders(headers),
  );
}

ApiRequest sanitizeRequest(ApiRequest input) {
  final r = validateRequest(input), a = r.auth;
  var url = r.url.split('?').first.split('#').first;
  try {
    final parsed = Uri.parse(r.url);
    if (parsed.hasAuthority)
      // Query values and the fragment go; a URL that had neither must not
      // gain an empty `?#` (which would break the request when reopened).
      url = parsed
          .removeFragment()
          .replace(
            userInfo: '',
            queryParameters: parsed.queryParameters.isEmpty
                ? null
                : {for (final k in parsed.queryParameters.keys) k: ''},
          )
          .toString();
  } catch (_) {
    /* Templates retain only path; query and fragment already stripped. */
  }
  // Arbitrary request payloads and header values are session-only, including content-type.
  // Templates in paths may contain only environment names, never exported environment values.
  final auth = switch (a.type) {
    'basic' => const ApiAuth.basic(username: '', password: ''),
    'bearer' => const ApiAuth.bearer(''),
    'api-key' => ApiAuth.apiKey(name: a.name, value: '', location: a.location),
    _ => const ApiAuth.none(),
  };
  return r.copyWith(
    url: url,
    body: '',
    headers: {for (final k in r.headers.keys) k: ''},
    auth: auth,
  );
}

class ApiEnvironment {
  final String id, name;
  final Map<String, String> values;
  ApiEnvironment({
    required this.id,
    required this.name,
    Map<String, String> values = const {},
  }) : values = Map.unmodifiable(values);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'values': values};
  factory ApiEnvironment.fromJson(dynamic raw) {
    final e = _object(raw),
        id = _text(e['id'], 100),
        name = _text(e['name'], 200),
        values = _object(e['values']);
    if (!_identifier.hasMatch(id) || name.trim().isEmpty || values.length > 100)
      throw const FormatException('Invalid environment or variable limit');
    final result = <String, String>{};
    for (final entry in values.entries) {
      if (!_variable.hasMatch(entry.key))
        throw const FormatException('Invalid variable name');
      result[entry.key] = _text(entry.value, 8000);
    }
    return ApiEnvironment(id: id, name: name, values: result);
  }
}

class ApiCollection {
  final String id, name;
  final List<String> requestIds;
  ApiCollection({
    required this.id,
    required this.name,
    List<String> requestIds = const [],
  }) : requestIds = List.unmodifiable(requestIds);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'requestIds': requestIds,
  };
  factory ApiCollection.fromJson(dynamic raw) {
    final c = _object(raw),
        id = _text(c['id'], 100),
        name = _text(c['name'], 200),
        ids = c['requestIds'];
    if (!_identifier.hasMatch(id) ||
        name.trim().isEmpty ||
        ids is! List ||
        ids.length > 100 ||
        ids.any((v) => v is! String || !_identifier.hasMatch(v)) ||
        ids.toSet().length != ids.length)
      throw const FormatException('Invalid request collection');
    return ApiCollection(
      id: id,
      name: name,
      requestIds: List<String>.from(ids),
    );
  }
}

class ApiWorkspace {
  final List<ApiRequest> requests;
  final List<ApiEnvironment> environments;
  final List<ApiCollection> collections;
  ApiWorkspace({
    List<ApiRequest> requests = const [],
    List<ApiEnvironment> environments = const [],
    List<ApiCollection>? collections,
  }) : requests = List.unmodifiable(requests),
       environments = List.unmodifiable(environments),
       collections = List.unmodifiable(
         collections ??
             [
               ApiCollection(
                 id: 'general',
                 name: 'General',
                 requestIds: requests.map((r) => r.id).toList(),
               ),
             ],
       );
  Map<String, dynamic> toJson() => {
    'version': 2,
    'requests': requests.map((r) => r.toJson()).toList(),
    'environments': environments.map((e) => e.toJson()).toList(),
    'collections': collections.map((c) => c.toJson()).toList(),
  };
}

ApiWorkspace emptyWorkspace() => ApiWorkspace();
ApiWorkspace parseWorkspace(String source) {
  final w = _object(jsonDecode(bounded(source, 2000000))),
      version = w['version'];
  if (![1, 2].contains(version) ||
      w['requests'] is! List ||
      w['environments'] is! List ||
      (w['requests'] as List).length > 100 ||
      (w['environments'] as List).length > 30)
    throw const FormatException('Invalid workspace or request limit');
  final requests = (w['requests'] as List).map(ApiRequest.fromJson).toList(),
      envs = (w['environments'] as List).map(ApiEnvironment.fromJson).toList();
  if (requests.map((r) => r.id).toSet().length != requests.length ||
      envs.map((e) => e.id).toSet().length != envs.length)
    throw const FormatException('Duplicate API IDs');
  List<ApiCollection>? collections;
  if (version == 2) {
    final raw = w['collections'];
    if (raw is! List || raw.isEmpty || raw.length > 30)
      throw const FormatException('Invalid collection count');
    collections = raw.map(ApiCollection.fromJson).toList();
    final ids = collections.map((c) => c.id).toSet(),
        members = [for (final c in collections) ...c.requestIds],
        known = requests.map((r) => r.id).toSet();
    if (ids.length != collections.length ||
        members.toSet().length != members.length ||
        members.length != requests.length ||
        members.any((id) => !known.contains(id)))
      throw const FormatException(
        'Duplicate, missing or dangling collection membership',
      );
  }
  return ApiWorkspace(
    requests: requests,
    environments: envs,
    collections: collections,
  );
}

ApiWorkspace _workspace(
  List<ApiRequest> requests,
  List<ApiEnvironment> environments,
  List<ApiCollection> collections,
) => parseWorkspace(
  jsonEncode(
    ApiWorkspace(
      requests: requests,
      environments: environments,
      collections: collections,
    ).toJson(),
  ),
);
String exportWorkspace(ApiWorkspace input) {
  final valid = parseWorkspace(jsonEncode(input.toJson()));
  return const JsonEncoder.withIndent('  ').convert(
    ApiWorkspace(
      requests: valid.requests.map(sanitizeRequest).toList(),
      environments: valid.environments
          .map(
            (e) => ApiEnvironment(
              id: e.id,
              name: e.name,
              values: {for (final k in e.values.keys) k: ''},
            ),
          )
          .toList(),
      collections: valid.collections,
    ).toJson(),
  );
}

ApiWorkspace saveRequest(
  ApiWorkspace workspace,
  ApiRequest request, {
  String? collectionId,
}) {
  final r = validateRequest(request),
      target =
          collectionId ??
          workspace.collections
              .where((c) => c.requestIds.contains(r.id))
              .firstOrNull
              ?.id ??
          workspace.collections.first.id;
  if (!workspace.collections.any((c) => c.id == target))
    throw const FormatException('Collection not found');
  return _workspace(
    [...workspace.requests.where((v) => v.id != r.id), r],
    workspace.environments,
    [
      for (final c in workspace.collections)
        ApiCollection(
          id: c.id,
          name: c.name,
          requestIds: [
            ...c.requestIds.where((id) => id != r.id),
            if (c.id == target) r.id,
          ],
        ),
    ],
  );
}

ApiWorkspace removeRequest(ApiWorkspace workspace, String id) => _workspace(
  workspace.requests.where((r) => r.id != id).toList(),
  workspace.environments,
  [
    for (final c in workspace.collections)
      ApiCollection(
        id: c.id,
        name: c.name,
        requestIds: c.requestIds.where((v) => v != id).toList(),
      ),
  ],
);
ApiWorkspace saveEnvironment(
  ApiWorkspace workspace,
  ApiEnvironment environment,
) {
  final e = ApiEnvironment.fromJson(environment.toJson());
  return _workspace(workspace.requests, [
    ...workspace.environments.where((v) => v.id != e.id),
    e,
  ], workspace.collections);
}

ApiWorkspace removeEnvironment(ApiWorkspace workspace, String id) => _workspace(
  workspace.requests,
  workspace.environments.where((e) => e.id != id).toList(),
  workspace.collections,
);
ApiWorkspace createCollection(ApiWorkspace workspace, String id, String name) {
  if (workspace.collections.any((c) => c.id == id))
    throw const FormatException('Collection ID exists');
  return _workspace(workspace.requests, workspace.environments, [
    ...workspace.collections,
    ApiCollection(id: id, name: name),
  ]);
}

ApiWorkspace renameCollection(ApiWorkspace workspace, String id, String name) {
  if (!workspace.collections.any((c) => c.id == id))
    throw const FormatException('Collection not found');
  return _workspace(workspace.requests, workspace.environments, [
    for (final c in workspace.collections)
      if (c.id == id)
        ApiCollection(id: c.id, name: name, requestIds: c.requestIds)
      else
        c,
  ]);
}

ApiWorkspace removeCollection(
  ApiWorkspace workspace,
  String id, {
  String? moveTo,
}) {
  final current = workspace.collections.where((c) => c.id == id).firstOrNull;
  if (current == null ||
      workspace.collections.length < 2 ||
      moveTo == id ||
      moveTo != null && !workspace.collections.any((c) => c.id == moveTo) ||
      current.requestIds.isNotEmpty && moveTo == null)
    throw const FormatException(
      'Choose another collection to preserve requests',
    );
  return _workspace(workspace.requests, workspace.environments, [
    for (final c in workspace.collections)
      if (c.id != id)
        ApiCollection(
          id: c.id,
          name: c.name,
          requestIds: [
            ...c.requestIds,
            if (c.id == moveTo) ...current.requestIds,
          ],
        ),
  ]);
}

List<String> _shellTokens(String source) {
  bounded(source, 150000);
  source = source.replaceAll(RegExp(r'\\\r?\n'), ' ');
  if (RegExp(r'[\r\n]').hasMatch(source))
    throw const FormatException('One cURL command only');
  final tokens = <String>[];
  var token = StringBuffer(), quote = '', active = false;
  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    if (quote.isNotEmpty) {
      if (ch == quote) {
        quote = '';
      } else if (ch == r'\' && quote == '"') {
        if (++i >= source.length)
          throw const FormatException('Incomplete escape');
        final next = source[i];
        if (!['"', r'\', r'$', r'`'].contains(next)) token.write(r'\');
        token.write(next);
      } else {
        if (quote == '"' && (ch == r'$' || ch == '`'))
          throw const FormatException('Shell expansion unsupported');
        token.write(ch);
      }
    } else if (ch == '"' || ch == "'") {
      quote = ch;
      active = true;
    } else if (RegExp(r'\s').hasMatch(ch)) {
      if (active) {
        tokens.add(token.toString());
        token = StringBuffer();
        active = false;
      }
    } else if (ch == r'\') {
      if (++i >= source.length)
        throw const FormatException('Incomplete escape');
      token.write(source[i]);
      active = true;
    } else {
      if (RegExp(r'[;&|<>`$]').hasMatch(ch))
        throw const FormatException('Shell operators forbidden');
      token.write(ch);
      active = true;
    }
  }
  if (quote.isNotEmpty) throw const FormatException('Unclosed cURL quote');
  if (active) tokens.add(token.toString());
  return tokens;
}

ApiRequest importCurl(String source) {
  final tokens = _shellTokens(source);
  if (tokens.isEmpty || tokens.removeAt(0) != 'curl')
    throw const FormatException('Command must begin with curl');
  var url = '', method = 'GET', body = '', explicit = false, hasData = false;
  final headers = <String, String>{};
  ApiAuth auth = const ApiAuth.none();
  String value() {
    if (tokens.isEmpty)
      throw const FormatException('Missing cURL option value');
    return tokens.removeAt(0);
  }

  while (tokens.isNotEmpty) {
    final arg = tokens.removeAt(0);
    if (['-X', '--request'].contains(arg)) {
      method = value().toUpperCase();
      explicit = true;
    } else if (['-H', '--header'].contains(arg)) {
      final h = value(), colon = h.indexOf(':');
      if (colon < 1) throw const FormatException('Header requires name:value');
      final name = h.substring(0, colon).trim();
      if (headers.keys.any((k) => k.toLowerCase() == name.toLowerCase()))
        throw const FormatException('Duplicate cURL header');
      headers[name] = h.substring(colon + 1).trim();
    } else if ([
      '-d',
      '--data',
      '--data-raw',
      '--data-binary',
      '--json',
    ].contains(arg)) {
      if (hasData)
        throw const FormatException('Multiple data fragments unsupported');
      hasData = true;
      body = value();
      if (body.startsWith('@'))
        throw const FormatException('File references unsupported');
      if (!explicit) method = 'POST';
      if (arg == '--json') headers['Content-Type'] = 'application/json';
    } else if (['-u', '--user'].contains(arg)) {
      final pair = value(), colon = pair.indexOf(':');
      auth = ApiAuth.basic(
        username: colon < 0 ? pair : pair.substring(0, colon),
        password: colon < 0 ? '' : pair.substring(colon + 1),
      );
    } else if (arg == '--url') {
      if (url.isNotEmpty)
        throw const FormatException('Exactly one URL supported');
      url = value();
    } else if (['-I', '--head'].contains(arg)) {
      method = 'HEAD';
      explicit = true;
    } else if (['-s', '--silent', '-S', '--show-error'].contains(arg)) {
      continue;
    } else if (arg.startsWith('-')) {
      throw const FormatException(
        'Unsupported cURL option; file IO and redirects disabled',
      );
    } else {
      if (url.isNotEmpty)
        throw const FormatException('Exactly one URL supported');
      url = arg;
    }
  }
  final r = validateRequest(
    ApiRequest(
      id: 'imported',
      name: 'Imported cURL',
      url: url,
      method: method,
      body: body,
      headers: headers,
      auth: auth,
    ),
  );
  prepareRequest(r);
  return r;
}

String exportCurl(ApiRequest input) {
  final r = sanitizeRequest(input);
  String quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
  return [
    'curl',
    '-X',
    r.method,
    quote(r.url),
    for (final e in r.headers.entries) ...['-H', quote('${e.key}: ${e.value}')],
  ].join(' ');
}
