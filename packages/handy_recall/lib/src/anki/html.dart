part of '../../anki.dart';

/// One Anki field made safe: plain text, the pictures it named, and how
/// many sounds or videos it held (Recall plays none of them).
class _Clean {
  final String text;
  final List<String> images;
  final int sounds;
  const _Clean(this.text, this.images, this.sounds);
}

final _soundTag = RegExp(r'\[sound:[^\]]*\]');
final _dropBlock = RegExp(
  r'<(script|style|head|title|object|iframe|svg|math)\b[^>]*>.*?</\1\s*>',
  caseSensitive: false,
  dotAll: true,
);
final _comment = RegExp(r'<!--.*?-->', dotAll: true);
final _imgTag = RegExp(r'<img\b[^>]*>', caseSensitive: false);
final _srcAttr = RegExp(
  r'''\bsrc\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',
  caseSensitive: false,
);
final _mediaTag = RegExp(r'<(audio|video)\b', caseSensitive: false);
final _lineBreak = RegExp(r'<br\s*/?>', caseSensitive: false);
final _blockEnd = RegExp(
  r'</(div|p|li|tr|h[1-6]|blockquote|pre|ul|ol|table|dt|dd)\s*>',
  caseSensitive: false,
);
final _blockStart = RegExp(
  r'<(div|p|h[1-6]|blockquote|pre|tr|ul|ol|table)\b[^>]*>',
  caseSensitive: false,
);
final _listItem = RegExp(r'<li\b[^>]*>', caseSensitive: false);
final _cell = RegExp(r'</t[dh]\s*>', caseSensitive: false);
final _anyTag = RegExp(r'<[^>]*>');
final _entity = RegExp(r'&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z]{2,8});');
const _named = {
  'nbsp': ' ',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'ndash': '–',
  'mdash': '—',
  'hellip': '…',
  'laquo': '«',
  'raquo': '»',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
  'middot': '·',
  'bull': '•',
  'times': '×',
  'divide': '÷',
  'deg': '°',
  'copy': '©',
  'reg': '®',
  'shy': '',
  'zwj': '‍',
  'zwnj': '‌',
  'larr': '←',
  'rarr': '→',
  'uarr': '↑',
  'darr': '↓',
  'harr': '↔',
  'plusmn': '±',
  'micro': 'µ',
  'para': '¶',
  'sect': '§',
  'euro': '€',
  'pound': '£',
  'yen': '¥',
  'cent': '¢',
};

String _decodeEntities(String s) => s.replaceAllMapped(_entity, (m) {
  final e = m[1]!;
  if (e.startsWith('#')) {
    final code = e.length > 1 && (e[1] == 'x' || e[1] == 'X')
        ? int.tryParse(e.substring(2), radix: 16)
        : int.tryParse(e.substring(1));
    if (code == null ||
        code == 0 ||
        code > 0x10ffff ||
        (code >= 0xd800 && code <= 0xdfff))
      return '';
    return String.fromCharCode(code);
  }
  return _named[e.toLowerCase()] ?? m[0]!;
});

/// Turns a field's HTML into the plain text Recall shows. Markup, scripts
/// and styles go; line breaks and list items stay as lines; pictures are
/// listed by file name; sounds and videos are counted and removed.
_Clean _clean(String html) {
  var sounds = 0;
  final images = <String>[];
  var s = html.replaceAllMapped(_soundTag, (_) {
    sounds++;
    return '';
  });
  s = s.replaceAll(_comment, '').replaceAll(_dropBlock, '');
  s = s.replaceAllMapped(_imgTag, (m) {
    final src = _srcAttr.firstMatch(m[0]!);
    final name = src == null ? '' : (src[1] ?? src[2] ?? src[3] ?? '');
    if (name.isNotEmpty) images.add(_decodeEntities(name));
    return ' ';
  });
  sounds += _mediaTag.allMatches(s).length;
  // A block's edges mark one line break however many of them meet
  // (`</div><div>`); a <br> is a line break of its own.
  const block = '';
  s = s
      .replaceAll(block, '')
      .replaceAll(_lineBreak, '\n')
      .replaceAll(_blockEnd, block)
      .replaceAll(_blockStart, block)
      .replaceAll(_listItem, '$block• ')
      .replaceAll(_cell, ' ')
      .replaceAll(_anyTag, '')
      .replaceAll(RegExp('(?:[ \\t]*$block[ \\t]*)+'), '\n');
  s = _decodeEntities(s)
      .replaceAll(' ', ' ')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      // Controls other than line breaks and tabs are never meant as text.
      .replaceAll(RegExp(r'[\u0000-\u0008\u000b-\u001f\u007f]'), '');
  final lines = s
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .toList();
  s = lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return _Clean(s, images, sounds);
}
