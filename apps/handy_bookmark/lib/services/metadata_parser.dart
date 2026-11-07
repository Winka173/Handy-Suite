import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'metadata_policy.dart';
import 'metadata_types.dart';

/// Parses inert HTML only. Never executes scripts or follows document base URLs.
MetadataResult parseMetadataHtml(List<int> bytes, Uri source) {
  if (bytes.length > metadataHeadMaxBytes) {
    return const MetadataResult(
      status: 'failed',
      errorCode: 'responseTooLarge',
    );
  }
  final document = html.parse(utf8.decode(bytes, allowMalformed: true));
  final values = <String, String>{};
  for (final element in document.querySelectorAll('meta')) {
    final key = (element.attributes['property'] ?? element.attributes['name'])
        ?.toLowerCase();
    final value = element.attributes['content']?.trim();
    if (key != null && value != null && value.isNotEmpty) {
      values.putIfAbsent(key, () => value);
    }
  }
  String? clean(String? value, [int limit = 2048]) {
    if (value == null) return null;
    final text = value
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isEmpty ? null : text.substring(0, text.length.clamp(0, limit));
  }

  String? link(String? value) => value == null
      ? null
      : publicMetadataUri(value.trim(), base: source)?.toString();
  String? canonical;
  for (final element in document.querySelectorAll('link[rel]')) {
    if (element.attributes['rel']!
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .contains('canonical')) {
      canonical = link(element.attributes['href']);
      if (canonical != null) break;
    }
  }
  final title = clean(
    values['og:title'] ??
        values['twitter:title'] ??
        document.querySelector('title')?.text,
    512,
  );
  final description = clean(
    values['og:description'] ??
        values['twitter:description'] ??
        values['description'],
  );
  final page = MetadataResult(
    title: title,
    description: description,
    siteName: clean(values['og:site_name'], 256),
    author: clean(values['author'] ?? values['article:author'], 512),
    canonicalUrl: canonical ?? link(values['og:url']),
    thumbnailUrl: link(
      values['og:image'] ??
          values['twitter:image'] ??
          values['twitter:image:src'],
    ),
    contentType: clean(values['og:type'], 128) ?? 'website',
    status: title != null && description != null ? 'complete' : 'partial',
  );
  final host = source.host.toLowerCase();
  bool on(String domain) => host == domain || host.endsWith('.$domain');
  if (on('tiktok.com')) {
    return _tiktok(document, page, clean, link) ?? page;
  }
  if (on('x.com') ||
      on('twitter.com') ||
      on('threads.net') ||
      on('threads.com')) {
    return _postText(page, clean);
  }
  return page;
}

/// TikTok sends its page meta for the app, not the video: the video's
/// caption, author and cover are in the page's data block (read as JSON,
/// never run). Null when that block is missing or not a video.
MetadataResult? _tiktok(
  dynamic document,
  MetadataResult page,
  String? Function(String?, [int]) clean,
  String? Function(String?) link,
) {
  final script = document.querySelector(
    'script#__UNIVERSAL_DATA_FOR_REHYDRATION__',
  );
  if (script == null) return null;
  try {
    final data = jsonDecode(script.text);
    final detail = (data as Map)['__DEFAULT_SCOPE__']?['webapp.video-detail'];
    if (detail is! Map || detail['statusCode'] != 0) return null;
    final item = detail['itemInfo']?['itemStruct'];
    if (item is! Map) return null;
    final author = item['author'] is Map ? item['author'] as Map : const {};
    final video = item['video'] is Map ? item['video'] as Map : const {};
    final share = detail['shareMeta'] is Map
        ? detail['shareMeta'] as Map
        : const {};
    String? text(Object? v) => v is String ? clean(v) : null;
    final caption = text(item['desc']);
    final name = text(author['nickname']);
    final handle = text(author['uniqueId']);
    final cover = link(text(video['cover']) ?? text(video['originCover']));
    final title = clean(caption ?? text(share['title']), 512);
    if (title == null && cover == null) return null;
    return MetadataResult(
      title: title ?? page.title,
      description: caption ?? page.description,
      siteName: 'TikTok',
      author: name != null && handle != null
          ? '$name (@$handle)'
          : name ?? handle,
      canonicalUrl: page.canonicalUrl,
      thumbnailUrl: cover ?? page.thumbnailUrl,
      contentType: 'video',
      status: title != null && cover != null ? 'complete' : 'partial',
    );
  } catch (_) {
    return null;
  }
}

/// X and Threads title a post "Name (@handle) on X"; the post itself is in
/// the description, which is what the person saved.
MetadataResult _postText(
  MetadataResult page,
  String? Function(String?, [int]) clean,
) {
  final title = page.title;
  final text = page.description;
  if (title == null || text == null) return page;
  final match = RegExp(r'^(.*?)\s+on\s+(X|Twitter|Threads)$').firstMatch(title);
  if (match == null) return page;
  final post = text.replaceAll(RegExp(r'^[\u201c"]|[\u201d"]$'), '').trim();
  if (post.isEmpty) return page;
  return MetadataResult(
    title: clean(post, 512),
    description: page.description,
    siteName: page.siteName ?? match.group(2),
    author: page.author ?? clean(match.group(1), 512),
    canonicalUrl: page.canonicalUrl,
    thumbnailUrl: page.thumbnailUrl,
    contentType: page.contentType,
    status: page.status,
  );
}

/// Reddit's official oEmbed answer (title and author of a post; it gives no
/// picture). Its post pages answer apps with a bot challenge instead.
MetadataResult parseRedditOEmbed(List<int> bytes) {
  try {
    final data = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    if (data is! Map) throw const FormatException();
    String? text(Object? v) {
      if (v is! String) return null;
      final t = v.replaceAll(RegExp(r'\s+'), ' ').trim();
      return t.isEmpty ? null : t.substring(0, t.length.clamp(0, 512));
    }

    final title = text(data['title']);
    final author = text(data['author_name']);
    return MetadataResult(
      title: title,
      siteName: 'Reddit',
      author: author == null ? null : 'u/$author',
      contentType: 'article',
      status: title == null ? 'failed' : 'partial',
      errorCode: title == null ? 'noTitle' : null,
    );
  } catch (_) {
    return const MetadataResult(status: 'failed', errorCode: 'invalidResponse');
  }
}
