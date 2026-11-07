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
  return MetadataResult(
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
}
