part of '../handy_recall.dart';

/// `{{c1::answer}}` or `{{c1::answer::hint}}`, as Anki writes them. Nested
/// clozes are not supported: the outer one ends at the first `}}`.
final _cloze = RegExp(r'\{\{c(\d{1,3})::(.*?)(?:::(.*?))?\}\}', dotAll: true);

/// The cloze numbers a text asks, each once, in ascending order.
List<int> clozeNumbers(String text) {
  final numbers = <int>{
    for (final m in _cloze.allMatches(text))
      if (int.parse(m[1]!) case final n when n > 0) n,
  };
  return numbers.toList()..sort();
}

enum ClozePart { text, blank, answer }

/// A run of a cloze card's text: plain, the blank being asked, or (once
/// revealed) the answer that filled it.
class ClozeSpan {
  final String text;
  final ClozePart part;
  const ClozeSpan(this.text, this.part);
  @override
  bool operator ==(Object other) =>
      other is ClozeSpan && other.text == text && other.part == part;
  @override
  int get hashCode => Object.hash(text, part);
  @override
  String toString() => '${part.name}:$text';
}

/// [text] as the card for cloze [number] shows it. Its own clozes become a
/// blank with the hint (`[hint]` or `[…]`) until [revealed], then their
/// answer; every other cloze shows its answer as plain text.
List<ClozeSpan> clozeSpans(String text, int number, {required bool revealed}) {
  final spans = <ClozeSpan>[];
  var at = 0;
  void plain(String s) {
    if (s.isEmpty) return;
    if (spans.isNotEmpty && spans.last.part == ClozePart.text) {
      spans.last = ClozeSpan(spans.last.text + s, ClozePart.text);
    } else {
      spans.add(ClozeSpan(s, ClozePart.text));
    }
  }

  for (final m in _cloze.allMatches(text)) {
    plain(text.substring(at, m.start));
    if (int.parse(m[1]!) != number) {
      plain(m[2]!);
    } else if (revealed) {
      spans.add(ClozeSpan(m[2]!, ClozePart.answer));
    } else {
      final hint = (m[3] ?? '').trim();
      spans.add(ClozeSpan(hint.isEmpty ? '[…]' : '[$hint]', ClozePart.blank));
    }
    at = m.end;
  }
  plain(text.substring(at));
  return spans;
}

/// [clozeSpans] as one string, for lists, search and reading aloud.
String clozeText(String text, int number, {required bool revealed}) =>
    clozeSpans(text, number, revealed: revealed).map((s) => s.text).join();

/// Wraps [start]..[end] of [text] in a new cloze: the next free number, or
/// the highest one already used when [same] (several blanks on one card).
/// An empty selection inserts an empty cloze. Returns the new text and where
/// the cursor goes: inside an empty cloze, after a filled one.
({String text, int cursor}) makeCloze(
  String text,
  int start,
  int end, {
  bool same = false,
}) {
  if (start > end) (start, end) = (end, start);
  start = start.clamp(0, text.length);
  end = end.clamp(0, text.length);
  final used = clozeNumbers(text);
  final n = used.isEmpty ? 1 : (same ? used.last : used.last + 1);
  final open = '{{c$n::';
  final inner = text.substring(start, end);
  final next = '${text.substring(0, start)}$open$inner}}${text.substring(end)}';
  return (
    text: next,
    cursor: inner.isEmpty
        ? start + open.length
        : start + open.length + inner.length + 2,
  );
}
