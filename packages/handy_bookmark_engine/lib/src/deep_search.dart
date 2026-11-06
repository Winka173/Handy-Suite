import 'highlights.dart';
import 'search.dart';

/// Where a deep match was found, for the chip beside it.
enum DeepSource { article, highlight, picture }

/// One item found by words inside it rather than by its title, address,
/// note or tags, with a short passage around the words.
class DeepHit {
  final String id;
  final DeepSource source;
  final String snippet;
  const DeepHit(this.id, this.source, this.snippet);
}

/// Items whose offline article, highlights (quotes and notes) or picture
/// text hold every word of [query] (case and accents ignored), skipping
/// [exclude] (those the ordinary search already found). Highlights are
/// checked first, then pictures, then articles: the most personal source
/// is the one shown. Nothing is invented: a hit always quotes real text.
List<DeepHit> deepSearch(
  String query, {
  Map<String, String> articles = const {},
  Map<String, List<Highlight>> highlights = const {},
  Map<String, String> pictureText = const {},
  Set<String> exclude = const {},
  int limit = 50,
}) {
  final words = foldSearch(
    query,
  ).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final out = <DeepHit>[];
  final seen = {...exclude};

  String? passage(String text) {
    final folded = foldSearch(text);
    if (!words.every(folded.contains)) return null;
    return _snippet(text, folded.indexOf(words.first), words.first.length);
  }

  for (final e in highlights.entries) {
    if (seen.contains(e.key)) continue;
    for (final h in e.value) {
      final s = passage('${h.quote}\n${h.note}');
      if (s == null) continue;
      out.add(DeepHit(e.key, DeepSource.highlight, s));
      seen.add(e.key);
      break;
    }
    if (out.length >= limit) return out;
  }
  for (final (map, source) in [
    (pictureText, DeepSource.picture),
    (articles, DeepSource.article),
  ]) {
    for (final e in map.entries) {
      if (seen.contains(e.key)) continue;
      final s = passage(e.value);
      if (s == null) continue;
      out.add(DeepHit(e.key, source, s));
      seen.add(e.key);
      if (out.length >= limit) return out;
    }
  }
  return out;
}

/// About 120 characters of [text] around [at], on whole words.
String _snippet(String text, int at, int length) {
  final start = (at - 50).clamp(0, text.length);
  final end = (at + length + 70).clamp(0, text.length);
  var s = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (start > 0) {
    final space = s.indexOf(' ');
    if (space > 0 && space < 20) s = s.substring(space + 1);
    s = '…$s';
  }
  if (end < text.length) {
    final space = s.lastIndexOf(' ');
    if (space > s.length - 20) s = s.substring(0, space);
    s = '$s…';
  }
  return s;
}
