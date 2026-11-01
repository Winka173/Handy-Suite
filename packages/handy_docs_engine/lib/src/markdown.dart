import 'dart:convert';
import 'package:markdown/markdown.dart' as md;

/// One bounded parse supplies safe exports. Raw HTML is treated as text;
/// exported images/links never acquire arbitrary active attributes.
class MarkdownDocument {
  final String source, html, text;
  const MarkdownDocument._(this.source, this.html, this.text);
}

MarkdownDocument parseMarkdownDocument(String source) {
  if (source.length > 100000 || utf8.encode(source).length > 100000) {
    throw const FormatException(
      'Markdown rendering limit: 100 KB UTF-8; source save/export supports 1 MB',
    );
  }
  var markers = 0, lines = 0;
  var brackets = 0, quotes = 0;
  var linePrefix = true;
  for (final rune in source.runes) {
    if (rune == 91 && ++brackets > 60)
      throw const FormatException('Markdown nesting limit exceeded');
    if (rune == 93 && brackets > 0) brackets--;
    if (rune == 10) {
      quotes = 0;
      linePrefix = true;
    }
    if (linePrefix && rune == 62 && ++quotes > 60)
      throw const FormatException('Markdown nesting limit exceeded');
    if (linePrefix && rune != 62 && rune != 32 && rune != 9 && rune != 10)
      linePrefix = false;
    if (rune == 10 && ++lines > 10000 ||
        {35, 42, 62, 91, 93, 95, 96, 124}.contains(rune) && ++markers > 10000) {
      throw const FormatException('Markdown structure limit exceeded');
    }
  }
  final nodes = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  ).parse(source.startsWith('\ufeff') ? source.substring(1) : source);
  const escape = HtmlEscape(HtmlEscapeMode.element);
  const attr = HtmlEscape(HtmlEscapeMode.attribute);
  const tags = {
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'pre',
    'code',
    'ul',
    'ol',
    'li',
    'strong',
    'em',
    'del',
    'table',
    'thead',
    'tbody',
    'tr',
    'th',
    'td',
    'br',
    'hr',
  };
  var count = 0;
  String render(md.Node node, int depth) {
    if (++count > 100000 || depth > 60)
      throw const FormatException('Markdown structure limit exceeded');
    if (node is md.Text) return escape.convert(node.text);
    if (node is! md.Element) return escape.convert(node.textContent);
    if (node.tag == 'img') return escape.convert(node.attributes['alt'] ?? '');
    if (node.tag == 'input')
      return node.attributes.containsKey('checked') ? '[x] ' : '[ ] ';
    final content = (node.children ?? [])
        .map((n) => render(n, depth + 1))
        .join();
    if (node.tag == 'a') {
      final href = node.attributes['href'] ?? '', uri = Uri.tryParse(href);
      if (uri == null ||
          !{'https', 'http', 'mailto'}.contains(uri.scheme.toLowerCase()) ||
          uri.userInfo.isNotEmpty ||
          href.runes.any((r) => r < 32 || r == 127))
        return content;
      return '<a href="${attr.convert(href)}" rel="noreferrer noopener">$content</a>';
    }
    if (!tags.contains(node.tag)) return content;
    if (node.tag == 'br' || node.tag == 'hr') return '<${node.tag}>';
    return '<${node.tag}>$content</${node.tag}>';
  }

  String plain(md.Node node) {
    if (node is md.Text) return node.text;
    if (node is! md.Element) return node.textContent;
    if (node.tag == 'img') return node.attributes['alt'] ?? '';
    if (node.tag == 'input')
      return node.attributes.containsKey('checked') ? '[x] ' : '[ ] ';
    if (node.tag == 'br') return '\n';
    final content = (node.children ?? []).map(plain).join();
    if ({'td', 'th'}.contains(node.tag)) return '$content\t';
    if ({
      'p',
      'li',
      'tr',
      'pre',
      'blockquote',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
    }.contains(node.tag))
      return '$content\n';
    return content;
  }

  final body = nodes.map((n) => render(n, 0)).join('\n');
  final text = nodes.map(plain).join('\n').trimRight();
  final html =
      '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'"><style>body{font-family:system-ui;margin:24px;line-height:1.65;overflow-wrap:anywhere}pre{white-space:pre-wrap}table{border-collapse:collapse}td,th{border:1px solid #888;padding:8px}</style></head><body>$body</body></html>';
  if (utf8.encode(html).length > 4000000 || utf8.encode(text).length > 1000000)
    throw const FormatException('Markdown output limit exceeded');
  return MarkdownDocument._(source, html, text);
}

String serializeMarkdownDraft(String source) {
  if (source.length > 1000000 || utf8.encode(source).length > 1000000)
    throw const FormatException('Document limit: 1 MB UTF-8');
  return jsonEncode({
    'format': 'handy-docs-markdown',
    'version': 1,
    'source': source,
  });
}

String parseMarkdownDraft(String raw) {
  if (raw.length > 6100000)
    throw const FormatException('Markdown draft too large');
  final value = jsonDecode(raw);
  if (value is! Map ||
      value['format'] != 'handy-docs-markdown' ||
      value['version'] != 1 ||
      value['source'] is! String ||
      value.keys.any((k) => !{'format', 'version', 'source'}.contains(k)))
    throw const FormatException('Unsupported Markdown draft');
  final source = value['source'] as String;
  serializeMarkdownDraft(source);
  return source;
}
