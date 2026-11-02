import 'dart:convert';

class UrlCandidate {
  final String originalUrl,
      normalizedUrl,
      canonicalUrl,
      platform,
      contentType,
      sourceDomain;
  final List<String> warnings;
  const UrlCandidate({
    required this.originalUrl,
    required this.normalizedUrl,
    required this.canonicalUrl,
    required this.platform,
    required this.contentType,
    required this.sourceDomain,
    required this.warnings,
  });
}

class UrlTools {
  static const maxUrlLength = 8192, maxInputBytes = 262144;
  static const _tracking = {
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'utm_id',
    'utm_source_platform',
    'utm_creative_format',
    'utm_marketing_tactic',
    'fbclid',
    'gclid',
    'dclid',
    'msclkid',
    'mc_cid',
    'mc_eid',
    'igshid',
  };
  static List<UrlCandidate> extract(String text) {
    if (utf8.encode(text).length > maxInputBytes)
      throw const FormatException('Shared text exceeds 256 KiB');
    final result = <UrlCandidate>[];
    for (final m in RegExp(
      r'''https?://[^\s<>"\x00-\x1f]+''',
      caseSensitive: false,
    ).allMatches(text)) {
      var url = m.group(0)!;
      if (m.start > 0 && text[m.start - 1] == "'" && url.endsWith("'"))
        url = url.substring(0, url.length - 1);
      while (url.isNotEmpty &&
          '.,;:!?\u3002\uff0c\u201d\u2019'.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
      }
      for (final pair in [('(', ')'), ('[', ']'), ('{', '}')]) {
        while (url.endsWith(pair.$2) &&
            pair.$2.allMatches(url).length > pair.$1.allMatches(url).length) {
          url = url.substring(0, url.length - 1);
        }
      }
      try {
        result.add(normalize(url));
      } on FormatException {
        /* Invalid candidates are omitted. */
      }
    }
    return List.unmodifiable(result);
  }

  static UrlCandidate normalize(String input) {
    final original = input.trim();
    if (original.isEmpty ||
        original.length > maxUrlLength ||
        RegExp(r'[\x00-\x20\x7f\\]').hasMatch(original))
      throw const FormatException('Invalid URL or URL exceeds 8192 characters');
    final Uri uri;
    try {
      uri = Uri.parse(original);
    } on FormatException {
      throw const FormatException('Invalid URL');
    }
    if (!{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        !uri.hasAuthority)
      throw const FormatException(
        'Only absolute HTTP and HTTPS URLs are supported',
      );
    final host = Uri.decodeComponent(uri.host).toLowerCase();
    if (RegExp(r'[\s/%\\]').hasMatch(host) ||
        host.startsWith('.') ||
        host.endsWith('..'))
      throw const FormatException('Invalid hostname');
    final query = uri.query
        .split('&')
        .where((part) {
          final key = part.split('=').first;
          try {
            return !_tracking.contains(
              Uri.decodeQueryComponent(key).toLowerCase(),
            );
          } on FormatException {
            throw const FormatException('Invalid query encoding');
          }
        })
        .join('&');
    // Keep every non-tracking parameter in its original order, including repeats.
    var normalized = uri.replace(query: query).toString();
    if (query.isEmpty)
      normalized = normalized.replaceFirst(RegExp(r'\?(?=#|$)'), '');
    if (uri.hasQuery && uri.query.isEmpty) normalized = uri.toString();
    var canonical = normalized;
    final clean = Uri.parse(normalized);
    final bare = host.startsWith('www.') ? host.substring(4) : host;
    var platform = 'web', type = 'link';
    if ({
      'youtube.com',
      'm.youtube.com',
      'music.youtube.com',
      'youtu.be',
    }.contains(bare)) {
      platform = 'youtube';
      type = 'video';
      String? video;
      var remaining = clean.query;
      if (bare == 'youtu.be' && clean.pathSegments.length == 1)
        video = clean.pathSegments.first;
      if (bare != 'youtu.be' &&
          clean.pathSegments.length == 2 &&
          {'shorts', 'embed', 'live'}.contains(clean.pathSegments.first))
        video = clean.pathSegments[1];
      if (video != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(video)) {
        canonical = clean
            .replace(
              host: 'www.youtube.com',
              path: '/watch',
              query: 'v=$video${remaining.isEmpty ? '' : '&$remaining'}',
            )
            .toString();
      } else if (clean.path == '/watch' &&
          clean.queryParametersAll['v']?.length == 1 &&
          RegExp(
            r'^[A-Za-z0-9_-]{11}$',
          ).hasMatch(clean.queryParameters['v'] ?? '')) {
        canonical = clean.replace(host: 'www.youtube.com').toString();
      }
    } else if ({
      'x.com',
      'twitter.com',
      'mobile.twitter.com',
      'm.twitter.com',
    }.contains(bare)) {
      platform = 'x';
      type = RegExp(r'^/[^/]+/status/\d+/?$').hasMatch(clean.path)
          ? 'post'
          : 'profile';
      canonical = clean.replace(host: 'x.com').toString();
    } else if (bare == 'instagram.com') {
      platform = 'instagram';
      type = clean.path.startsWith('/reel/')
          ? 'video'
          : clean.path.startsWith('/p/')
          ? 'post'
          : 'profile';
    } else if (bare == 'tiktok.com' ||
        bare == 'vm.tiktok.com' ||
        bare == 'vt.tiktok.com') {
      platform = 'tiktok';
      type = 'video';
    } else if (bare == 'facebook.com' ||
        bare == 'm.facebook.com' ||
        bare == 'fb.watch') {
      platform = 'facebook';
      type = 'post';
    } else if (bare == 'reddit.com' ||
        bare == 'old.reddit.com' ||
        bare == 'redd.it') {
      platform = 'reddit';
      type = 'post';
    } else if (bare == 'github.com') {
      platform = 'github';
      type = 'repository';
    } else if (bare == 'linkedin.com') {
      platform = 'linkedin';
      type = 'post';
    } else if (bare == 'pinterest.com' || bare == 'pin.it') {
      platform = 'pinterest';
      type = 'image';
    } else if (bare == 'vimeo.com') {
      platform = 'vimeo';
      type = 'video';
    }
    bool domain(String value) => bare == value || bare.endsWith('.$value');
    if (platform == 'youtube') {
      if (clean.path == '/playlist')
        type = 'playlist';
      else if (clean.path.startsWith('/channel/') ||
          clean.path.startsWith('/@') ||
          clean.path.startsWith('/c/'))
        type = 'profile';
    }
    if (platform == 'github') {
      if (clean.pathSegments.contains('issues'))
        type = 'issue';
      else if (clean.pathSegments.contains('pull'))
        type = 'pull-request';
    }
    if (domain('threads.net') || domain('threads.com')) {
      platform = 'threads';
      type = clean.path.contains('/post/') ? 'post' : 'profile';
    }
    if (domain('spotify.com') || domain('spotify.link')) {
      platform = 'spotify';
      type = 'audio';
    }
    if (domain('soundcloud.com') || domain('on.soundcloud.com')) {
      platform = 'soundcloud';
      type = 'audio';
    }
    if (domain('podcasts.apple.com') ||
        domain('pca.st') ||
        domain('podcasts.google.com')) {
      platform = 'podcast';
      type = 'audio';
    }
    for (final entry in {
      'shopee': [
        'shopee.vn',
        'shopee.com',
        'shopee.sg',
        'shopee.co.th',
        'shopee.com.my',
        'shopee.ph',
        'shope.ee',
        'shopee.co.id',
        'shopee.com.br',
      ],
      'lazada': [
        'lazada.vn',
        'lazada.sg',
        'lazada.co.th',
        'lazada.com.my',
        'lazada.com.ph',
        'lazada.co.id',
      ],
      'amazon': [
        'amazon.com',
        'amazon.co.uk',
        'amazon.de',
        'amazon.fr',
        'amazon.co.jp',
        'amzn.to',
        'amazon.ca',
        'amazon.com.au',
        'amazon.in',
      ],
      'ebay': ['ebay.com', 'ebay.co.uk', 'ebay.de'],
      'aliexpress': ['aliexpress.com', 'aliexpress.us'],
      'taobao': ['taobao.com', 'tmall.com', 'm.tb.cn'],
    }.entries) {
      if (entry.value.any(domain)) {
        platform = entry.key;
        type = 'shopping';
        break;
      }
    }
    if (domain('stackoverflow.com')) {
      platform = 'stackoverflow';
      type = 'question';
    }
    if (domain('maps.google.com') ||
        domain('maps.app.goo.gl') ||
        domain('maps.apple.com') ||
        bare == 'goo.gl' && clean.path.startsWith('/maps') ||
        domain('google.com') && clean.path.startsWith('/maps')) {
      platform = 'maps';
      type = 'place';
    }
    if (platform == 'facebook' &&
        (clean.path.contains('/reel') ||
            clean.path.contains('/video') ||
            bare == 'fb.watch'))
      type = 'video';
    if (platform == 'tiktok' &&
        clean.path.startsWith('/@') &&
        !clean.path.contains('/video/'))
      type = 'profile';
    final path = clean.path.toLowerCase();
    if (path.endsWith('.pdf')) type = 'document';
    if (RegExp(r'\.(png|jpe?g|gif|webp|avif|svg)$').hasMatch(path))
      type = 'image';
    if (RegExp(r'\.(mp3|m4a|wav|ogg|flac)$').hasMatch(path)) type = 'audio';
    if (RegExp(r'\.(mp4|webm|mov)$').hasMatch(path)) type = 'video';
    final warnings = <String>[];
    if (uri.userInfo.isNotEmpty)
      warnings.add('URL contains credentials; verify the actual host');
    if (uri.scheme == 'http')
      warnings.add('Connection is not encrypted (HTTP)');
    if (host.contains('xn--') || host.runes.any((r) => r > 127))
      warnings.add('Internationalized hostname; verify spelling');
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host == '::1' ||
        host.startsWith('127.') ||
        host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host))
      warnings.add('Local or private network address');
    if (RegExp(r'\.(exe|msi|apk|bat|cmd|scr|ps1)$').hasMatch(path))
      warnings.add('Link points to an executable file');
    if (uri.hasPort && !{80, 443}.contains(uri.port))
      warnings.add('Unusual network port');
    return UrlCandidate(
      originalUrl: original,
      normalizedUrl: normalized,
      canonicalUrl: canonical,
      platform: platform,
      contentType: type,
      sourceDomain: host,
      warnings: List.unmodifiable(warnings),
    );
  }
}
