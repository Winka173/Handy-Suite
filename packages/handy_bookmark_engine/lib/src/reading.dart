import 'dart:convert';
import 'dart:typed_data';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

String _text(Map<String, dynamic> j, String k, {bool optional = false}) {
  final v = j[k];
  if (v == null && optional) return '';
  if (v is! String) throw FormatException('$k must be text');
  return v;
}

/// One piece of a reading copy: a heading, a paragraph, a quote, a list
/// item, preformatted text, or a picture of the article. Text is plain,
/// never markup.
///
/// A picture (`img`) keeps where it came from ([url]) and its description
/// as [text] (may be empty). Its [picture] is a cleaned JPEG, present only
/// once the copy was saved with its pictures; it lives inside the copy, so
/// deleting the copy deletes the picture too.
class ReadingBlock {
  static const kinds = {'h', 'p', 'quote', 'li', 'pre', 'img'};

  /// The most one picture may weigh once cleaned.
  static const maxPictureBytes = 1536 * 1024;
  final String kind, text, url;
  final Uint8List? picture;
  ReadingBlock(this.kind, this.text, {this.url = '', this.picture}) {
    if (!kinds.contains(kind))
      throw const FormatException('Unknown reading block');
    if (kind == 'img') {
      final u = Uri.tryParse(url);
      if (u == null ||
          !{'http', 'https'}.contains(u.scheme) ||
          url.length > 8192 ||
          text.length > 512)
        throw const FormatException('Invalid reading picture');
      final b = picture;
      if (b != null &&
          (b.length < 3 ||
              b.length > maxPictureBytes ||
              b[0] != 0xFF ||
              b[1] != 0xD8 ||
              b[2] != 0xFF))
        throw const FormatException('Reading pictures are JPEG');
    } else {
      if (text.isEmpty) throw const FormatException('Empty reading block');
      if (url.isNotEmpty || picture != null)
        throw const FormatException('Only pictures carry an address');
    }
  }
  bool get isPicture => kind == 'img';
  ReadingBlock withPicture(Uint8List? bytes) =>
      ReadingBlock(kind, text, url: url, picture: bytes);
  factory ReadingBlock.fromJson(Map<String, dynamic> j) {
    final kind = _text(j, 'k');
    if (kind != 'img') return ReadingBlock(kind, _text(j, 't'));
    final data = j['d'];
    if (data != null && data is! String)
      throw const FormatException('Picture data must be text');
    return ReadingBlock(
      kind,
      _text(j, 't', optional: true),
      url: _text(j, 'u'),
      picture: data == null ? null : base64Decode(data as String),
    );
  }
  Map<String, dynamic> toJson() => {
    'k': kind,
    't': text,
    if (isPicture) 'u': url,
    if (picture != null) 'd': base64Encode(picture!),
  };
}

/// A calm, offline text copy of a page, saved only on request.
class ReadingCopy {
  /// Text budget for one copy. Longer pages are cut at a block boundary and
  /// marked [truncated].
  static const maxChars = 200000;
  static const maxBlocks = 5000;

  /// Pictures one copy keeps: at most this many, this much in all.
  static const maxPictures = 20;
  static const maxPictureBytes = 10 * 1024 * 1024;

  /// Format of the stored copy: 2 added pictures.
  static const version = 2;
  final String url, title, savedAt;
  final String byline, siteName;
  final List<ReadingBlock> blocks;
  final bool truncated;
  ReadingCopy({
    required this.url,
    required this.title,
    required String savedAt,
    this.byline = '',
    this.siteName = '',
    required List<ReadingBlock> blocks,
    this.truncated = false,
  }) : savedAt = _date(savedAt),
       blocks = List.unmodifiable(blocks) {
    if (url.isEmpty || url.length > 8192)
      throw const FormatException('Invalid reading copy address');
    if (title.length > 2048 || byline.length > 512 || siteName.length > 512)
      throw const FormatException('Reading copy header too long');
    if (blocks.isEmpty) throw const FormatException('Reading copy is empty');
    if (blocks.length > maxBlocks || chars > maxChars)
      throw const FormatException('Reading copy exceeds its size budget');
    final pictures = blocks.where((b) => b.isPicture);
    if (pictures.length > maxPictures || pictureBytes > maxPictureBytes)
      throw const FormatException('Reading copy has too many pictures');
    if (blocks.every((b) => b.isPicture))
      throw const FormatException('Reading copy is empty');
  }

  /// What the kept pictures weigh.
  int get pictureBytes =>
      blocks.fold(0, (n, b) => n + (b.picture?.length ?? 0));

  /// The pictures' places, in order, for fetching them.
  List<int> get pictureSlots => [
    for (final (i, b) in blocks.indexed)
      if (b.isPicture) i,
  ];

  /// This copy with [pictures] (by block index) filled in. Pictures not
  /// given stay as they were; a null clears one.
  ReadingCopy withPictures(Map<int, Uint8List?> pictures) => ReadingCopy(
    url: url,
    title: title,
    savedAt: savedAt,
    byline: byline,
    siteName: siteName,
    truncated: truncated,
    blocks: [
      for (final (i, b) in blocks.indexed)
        pictures.containsKey(i) ? b.withPicture(pictures[i]) : b,
    ],
  );

  static String _date(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value))
      throw const FormatException('Timestamp must contain timezone');
    return parsed.toUtc().toIso8601String();
  }

  int get chars =>
      blocks.fold(0, (n, b) => b.isPicture ? n : n + b.text.length);

  /// Rough reading length: words separated by white space.
  int get words => blocks.fold(
    0,
    (n, b) => b.isPicture
        ? n
        : n + b.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
  );

  factory ReadingCopy.fromJson(Map<String, dynamic> j) {
    final raw = j['blocks'];
    if (raw is! List) throw const FormatException('Reading blocks missing');
    if (j['truncated'] != null && j['truncated'] is! bool)
      throw const FormatException('truncated must be boolean');
    return ReadingCopy(
      url: _text(j, 'url'),
      title: _text(j, 'title', optional: true),
      savedAt: _text(j, 'savedAt'),
      byline: _text(j, 'byline', optional: true),
      siteName: _text(j, 'siteName', optional: true),
      truncated: j['truncated'] == true,
      blocks: [
        for (final b in raw)
          b is Map
              ? ReadingBlock.fromJson(Map<String, dynamic>.from(b))
              : throw const FormatException('Invalid reading block'),
      ],
    );
  }
  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'savedAt': savedAt,
    if (byline.isNotEmpty) 'byline': byline,
    if (siteName.isNotEmpty) 'siteName': siteName,
    if (truncated) 'truncated': true,
    if (blocks.any((b) => b.isPicture)) 'v': version,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };
}

const _drop = {
  'script', 'style', 'noscript', 'template', 'iframe', 'object', 'embed', //
  'svg', 'canvas', 'math', 'form', 'button', 'input', 'select', 'textarea',
  'nav', 'header', 'footer', 'aside', 'video',
  'audio', 'source', 'track', 'map', 'link', 'meta', 'dialog', 'menu',
};
const _inline = {
  'a', 'span', 'em', 'strong', 'b', 'i', 'u', 'code', 'small', 'sup', //
  'sub', 'mark', 'abbr', 'time', 'cite', 'q', 's', 'del', 'ins', 'font',
  'label', 'kbd', 'var', 'samp', 'bdi', 'bdo', 'data', 'wbr', 'tt',
};
final _unlikely = RegExp(
  r'comment|sidebar|share|social|related|promo|advert|sponsor|banner|'
  r'newsletter|subscribe|cookie|consent|breadcrumb|menu|footer|masthead|'
  r'popup|modal|outbrain|taboola|disqus|toolbar|signup|login|pagination',
  caseSensitive: false,
);
final _maybe = RegExp(
  r'article|content|post|entry|story|main|body|text',
  caseSensitive: false,
);

String _clean(String s) => s
    .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Reads the main text of an HTML page: title, byline, and the paragraphs
/// of the part that looks like the article, and where its pictures stand
/// (their addresses only; the bytes are fetched when the copy is kept).
/// Scripts, styles, navigation, forms, icons and tiny images are left out.
/// Returns null when the page has too little readable text to keep.
ReadingCopy? extractReadingCopy(
  String source, {
  required String url,
  required String savedAt,
  String fallbackTitle = '',
}) {
  final doc = html.parse(source);
  String? meta(String key) {
    for (final m in doc.querySelectorAll('meta')) {
      final k = (m.attributes['property'] ?? m.attributes['name'])
          ?.toLowerCase();
      final v = m.attributes['content'];
      if (k == key && v != null && _clean(v).isNotEmpty) return _clean(v);
    }
    return null;
  }

  final siteName = meta('og:site_name') ?? '';
  var byline = meta('author') ?? meta('article:author') ?? '';
  if (byline.startsWith('http')) byline = '';
  if (byline.isEmpty) {
    for (final e in doc.querySelectorAll(
      '[rel="author"], [itemprop="author"], .byline, .author',
    )) {
      final t = _clean(e.text);
      if (t.isNotEmpty && t.length <= 100) {
        byline = t;
        break;
      }
    }
  }
  byline = byline.replaceFirst(
    RegExp(r'^(by|bởi)\s+', caseSensitive: false),
    '',
  );
  final h1 = doc.querySelector('h1');
  var title =
      meta('og:title') ??
      (h1 == null ? null : _clean(h1.text)) ??
      _clean(doc.querySelector('title')?.text ?? '');
  if (title.isEmpty) title = fallbackTitle;
  if (title.length > 2048) title = title.substring(0, 2048);

  final body = doc.body;
  if (body == null) return null;
  // Strip what is never reading matter.
  for (final e in body.querySelectorAll('*').toList()) {
    if (e.parent == null) continue;
    final tag = e.localName ?? '';
    final hidden =
        e.attributes.containsKey('hidden') ||
        e.attributes['aria-hidden'] == 'true' ||
        (e.attributes['style'] ?? '')
            .replaceAll(' ', '')
            .contains('display:none');
    final label = '${e.className} ${e.id}';
    final junk =
        !{'article', 'main', 'body', 'p', 'h1', 'h2', 'h3'}.contains(tag) &&
        _unlikely.hasMatch(label) &&
        !_maybe.hasMatch(label);
    if (_drop.contains(tag) || hidden || junk) e.remove();
  }

  final root = _bestRoot(body);
  final blocks = <ReadingBlock>[];
  var chars = 0;
  var truncated = false;
  void add(String kind, String raw) {
    if (truncated) return;
    final text = kind == 'pre'
        ? raw.replaceAll(RegExp(r'^\n+|\s+$'), '')
        : _clean(raw);
    if (text.length < 2) return;
    if (blocks.isEmpty &&
        kind == 'h' &&
        text.toLowerCase() == title.toLowerCase())
      return;
    if (chars + text.length > ReadingCopy.maxChars ||
        blocks.length >= ReadingCopy.maxBlocks) {
      truncated = true;
      return;
    }
    chars += text.length;
    blocks.add(ReadingBlock(kind, text));
  }

  final seen = <String>{};
  void image(Element e) {
    if (truncated ||
        seen.length >= ReadingCopy.maxPictures ||
        blocks.length >= ReadingCopy.maxBlocks)
      return;
    final source = _pictureSource(e, url);
    if (source == null || !seen.add(source)) return;
    var alt = _clean(e.attributes['alt'] ?? '');
    if (alt.length > 512) alt = alt.substring(0, 512);
    blocks.add(ReadingBlock('img', alt, url: source));
  }

  _flatten(root, 'p', add, image);
  if (chars < 140) return null;
  // Pictures after the last words are page furniture, not the article.
  while (blocks.isNotEmpty && blocks.last.isPicture) {
    blocks.removeLast();
  }
  return ReadingCopy(
    url: url,
    title: title,
    savedAt: savedAt,
    byline: byline.length > 512 ? byline.substring(0, 512) : byline,
    siteName: siteName.length > 512 ? siteName.substring(0, 512) : siteName,
    blocks: blocks,
    truncated: truncated,
  );
}

double _linkDensity(Element e) {
  final all = e.text.length;
  if (all == 0) return 1;
  final links = e
      .querySelectorAll('a')
      .fold<int>(0, (n, a) => n + a.text.length);
  return links / all;
}

/// The element that holds most of the prose, by a readability-style score:
/// paragraphs add to their parent (and half to the grandparent), weighted
/// by length and commas, discounted by how much of the text is links.
Element _bestRoot(Element body) {
  final articles = body
      .querySelectorAll('article, main, [role="main"]')
      .where((e) => _clean(e.text).length > 500)
      .toList();
  if (articles.length == 1) return articles.single;
  final scores = <Element, double>{};
  for (final p in body.querySelectorAll('p, pre, blockquote, td')) {
    final text = _clean(p.text);
    if (text.length < 25) continue;
    final score =
        1 + ','.allMatches(text).length + (text.length / 100).clamp(0, 3);
    final parent = p.parent;
    if (parent == null) continue;
    scores[parent] = (scores[parent] ?? 0) + score;
    final grand = parent.parent;
    if (grand != null) scores[grand] = (scores[grand] ?? 0) + score / 2;
  }
  Element? best;
  var top = 0.0;
  scores.forEach((e, s) {
    final label = '${e.className} ${e.id}';
    final weighted =
        s * (1 - _linkDensity(e)) + (_maybe.hasMatch(label) ? 5 : 0);
    if (weighted > top) {
      top = weighted;
      best = e;
    }
  });
  // A wrapper often holds the article's siblings (intro, sub-heads).
  final chosen = best;
  if (chosen != null &&
      chosen.parent != null &&
      chosen.parent != body &&
      (scores[chosen.parent] ?? 0) >= top * .8) {
    return chosen.parent!;
  }
  return chosen ?? body;
}

const _blocks = {
  'p': 'p',
  'h1': 'h',
  'h2': 'h',
  'h3': 'h',
  'h4': 'h',
  'h5': 'h',
  'h6': 'h',
  'li': 'li',
  'dt': 'p',
  'dd': 'p',
  'blockquote': 'quote',
  'figcaption': 'p',
  'caption': 'p',
};

/// Walks [e] in document order, turning runs of inline text into blocks of
/// [kind] and nested block elements into their own blocks.
void _flatten(
  Element e,
  String kind,
  void Function(String kind, String text) add,
  void Function(Element img) image,
) {
  final buffer = StringBuffer();
  void flush() {
    if (buffer.isNotEmpty) add(kind, buffer.toString());
    buffer.clear();
  }

  void walk(Node n) {
    if (n is Text) {
      buffer.write(n.text);
      return;
    }
    if (n is! Element) return;
    final tag = n.localName ?? '';
    if (tag == 'img') {
      flush();
      image(n);
    } else if (tag == 'br') {
      buffer.write(' ');
    } else if (_inline.contains(tag)) {
      n.nodes.forEach(walk);
    } else if (tag == 'pre') {
      flush();
      add('pre', n.text);
    } else if (tag == 'tr') {
      flush();
      add(
        'p',
        n.children
            .where((c) => c.localName == 'td' || c.localName == 'th')
            .map((c) => _clean(c.text))
            .where((t) => t.isNotEmpty)
            .join(' · '),
      );
    } else if (_blocks.containsKey(tag)) {
      flush();
      final own = _blocks[tag]!;
      // A short paragraph that is mostly links is navigation, not prose.
      if (own == 'p' && _clean(n.text).length < 120 && _linkDensity(n) > .8)
        return;
      _flatten(n, own, add, image);
    } else {
      flush();
      n.nodes.forEach(walk);
      flush();
    }
  }

  e.nodes.forEach(walk);
  flush();
}

/// Where an article picture comes from: the largest of its sources that is
/// an ordinary web address (lazy-loading pages keep it in data-src), never
/// an inline or tiny image. Null when there is none worth keeping.
String? _pictureSource(Element e, String page) {
  int? size(String key) => int.tryParse(
    (e.attributes[key] ?? '').replaceAll(RegExp(r'px$'), '').trim(),
  );
  final w = size('width'), h = size('height');
  if ((w != null && w < 120) || (h != null && h < 120)) return null;
  String? largest(String? set) {
    if (set == null || set.trim().isEmpty) return null;
    String? best;
    var top = -1.0;
    for (final part in set.split(',')) {
      final bits = part.trim().split(RegExp(r'\s+'));
      if (bits.isEmpty || bits.first.isEmpty) continue;
      final d = bits.length > 1 ? bits[1] : '1x';
      final n = double.tryParse(d.substring(0, d.length - 1)) ?? 1;
      if (n > top) {
        top = n;
        best = bits.first;
      }
    }
    return best;
  }

  final candidates = [
    e.attributes['data-src'],
    e.attributes['data-lazy-src'],
    e.attributes['data-original'],
    largest(e.attributes['data-srcset'] ?? e.attributes['srcset']),
    e.attributes['src'],
  ];
  final base = Uri.tryParse(page);
  for (final c in candidates) {
    final raw = c?.trim() ?? '';
    if (raw.isEmpty || raw.startsWith('data:')) continue;
    final u = base?.resolve(raw) ?? Uri.tryParse(raw);
    if (u == null || !{'http', 'https'}.contains(u.scheme)) continue;
    final path = u.path.toLowerCase();
    if (path.endsWith('.svg') || path.endsWith('.gif')) continue;
    final s = u.toString();
    if (s.length > 8192) continue;
    return s;
  }
  return null;
}
