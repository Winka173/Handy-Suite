/// One place a search matched: the block and the span inside its text.
class TextMatch {
  final int block, start, end;
  const TextMatch(this.block, this.start, this.end);
  @override
  bool operator ==(Object other) =>
      other is TextMatch &&
      other.block == block &&
      other.start == start &&
      other.end == end;
  @override
  int get hashCode => Object.hash(block, start, end);
  @override
  String toString() => 'TextMatch($block, $start, $end)';
}

const _marked = {
  'a': 'àáảãạăằắẳẵặâầấẩẫậäåāą',
  'c': 'çćč',
  'd': 'đď',
  'e': 'èéẻẽẹêềếểễệëēęě',
  'i': 'ìíỉĩịîïī',
  'n': 'ñńň',
  'o': 'òóỏõọôồốổỗộơờớởỡợöøō',
  'r': 'ř',
  's': 'śšș',
  't': 'țť',
  'u': 'ùúủũụưừứửữựûüūů',
  'y': 'ỳýỷỹỵÿ',
  'z': 'źżž',
};
final _base = {
  for (final e in _marked.entries)
    for (final ch in e.value.split('')) ch: e.key,
};

/// Lower case without accents, one code unit for one code unit, so an
/// offset in the folded text is the same offset in the original. "Hà
/// Giang" is found by typing "ha giang".
String foldForFind(String s) {
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    final lower = ch.toLowerCase();
    final one = lower.length == 1 ? lower : ch;
    out.write(_base[one] ?? one);
  }
  return out.toString();
}

/// Searches one text's blocks, folded once so each keystroke only scans.
class TextFinder {
  TextFinder(List<String> blocks)
    : _folded = [for (final b in blocks) foldForFind(b)];
  final List<String> _folded;

  /// Every place [query] appears, in reading order, up to [limit]. Matches
  /// do not overlap. An empty or blank query finds nothing.
  List<TextMatch> search(String query, {int limit = 1000}) {
    if (query.trim().isEmpty) return const [];
    final q = foldForFind(query);
    final found = <TextMatch>[];
    for (var b = 0; b < _folded.length; b++) {
      final text = _folded[b];
      var from = 0;
      while (true) {
        final at = text.indexOf(q, from);
        if (at < 0) break;
        found.add(TextMatch(b, at, at + q.length));
        if (found.length >= limit) return found;
        from = at + q.length;
      }
    }
    return found;
  }
}
