/// A passage the person marked in an offline or live reading copy, with
/// an optional note. It is anchored three ways, so a re-read of the page
/// still finds it: the block, the offsets in that block, and the quoted
/// text itself.
class Highlight {
  static const colors = ['yellow', 'green', 'blue', 'pink', 'orange'];
  static const maxQuote = 2000, maxNote = 4000, maxPerItem = 500;

  final String id, quote, color, note, createdAt;
  final int block, start, end;
  const Highlight({
    required this.id,
    required this.block,
    required this.start,
    required this.end,
    required this.quote,
    this.color = 'yellow',
    this.note = '',
    required this.createdAt,
  });

  /// A highlight read from storage or a backup; null when it is not one.
  static Highlight? tryJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], quote = raw['quote'], at = raw['createdAt'];
    final block = raw['block'], start = raw['start'], end = raw['end'];
    if (id is! String || id.isEmpty || id.length > 64) return null;
    if (quote is! String || quote.trim().isEmpty || quote.length > maxQuote)
      return null;
    if (block is! int || start is! int || end is! int) return null;
    if (block < 0 || start < 0 || end <= start) return null;
    if (at is! String || DateTime.tryParse(at) == null) return null;
    final note = raw['note'];
    final color = raw['color'];
    return Highlight(
      id: id,
      block: block,
      start: start,
      end: end,
      quote: quote,
      color: colors.contains(color) ? color as String : colors.first,
      note: note is String
          ? (note.length > maxNote ? note.substring(0, maxNote) : note)
          : '',
      createdAt: at,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'block': block,
    'start': start,
    'end': end,
    'quote': quote,
    'color': color,
    if (note.isNotEmpty) 'note': note,
    'createdAt': createdAt,
  };

  Highlight copyWith({String? color, String? note}) => Highlight(
    id: id,
    block: block,
    start: start,
    end: end,
    quote: quote,
    color: color ?? this.color,
    note: note ?? this.note,
    createdAt: createdAt,
  );
}

/// Where [h] sits in [blocks] now, as (block, start, end): its own place
/// when the text there is unchanged, else the quote in its block, else the
/// quote anywhere. Null when the text no longer holds it (the highlight is
/// kept and listed, but cannot be shown in place).
(int, int, int)? anchorHighlight(Highlight h, List<String> blocks) {
  if (h.block < blocks.length) {
    final t = blocks[h.block];
    if (h.end <= t.length && t.substring(h.start, h.end) == h.quote)
      return (h.block, h.start, h.end);
    final i = t.indexOf(h.quote);
    if (i >= 0) return (h.block, i, i + h.quote.length);
  }
  for (var b = 0; b < blocks.length; b++) {
    final i = blocks[b].indexOf(h.quote);
    if (i >= 0) return (b, i, i + h.quote.length);
  }
  return null;
}

/// Finds [quote] (a selection) in [blocks], preferring the occurrence
/// nearest to [near] (the block on screen). A selection across blocks is
/// cut to its first line. Null when the text does not hold it.
(int, int, int)? locateQuote(String quote, List<String> blocks, int near) {
  final q = quote
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  if (q.isEmpty) return null;
  (int, int, int)? best;
  var distance = 1 << 30;
  for (var b = 0; b < blocks.length; b++) {
    final i = blocks[b].indexOf(q);
    if (i < 0) continue;
    final d = (b - near).abs();
    if (d < distance) {
      distance = d;
      best = (b, i, i + q.length);
    }
  }
  return best;
}

/// The highlights worth carrying for [items], from a preference or a
/// backup: invalid entries and unknown items are dropped, never an error.
Map<String, List<Highlight>> readHighlights(
  Object? raw,
  Iterable<String> items,
) {
  if (raw is! Map) return const {};
  final known = items.toSet();
  final out = <String, List<Highlight>>{};
  for (final e in raw.entries) {
    if (e.key is! String || !known.contains(e.key) || e.value is! List)
      continue;
    final list = [
      for (final h in (e.value as List).take(Highlight.maxPerItem))
        ?Highlight.tryJson(h),
    ];
    if (list.isNotEmpty) out[e.key as String] = list;
  }
  return out;
}

/// The person's highlights of one item as plain text (Markdown quotes),
/// for copying or sharing.
String highlightsAsText(String title, String url, List<Highlight> list) {
  final b = StringBuffer('# $title\n$url\n');
  for (final h in list) {
    b.write('\n> ${h.quote.replaceAll('\n', '\n> ')}\n');
    if (h.note.isNotEmpty) b.write('\n${h.note}\n');
  }
  return b.toString();
}
