part of '../handy_recall.dart';

/// How pasted text turns into cards: a question and its answer on each
/// line, or sentences whose marked words become blanks.
enum PasteMode { pairs, cloze }

/// The cards a paste makes, and how many lines or sentences it left out.
class PastedCards {
  final PasteMode mode;
  final List<(String front, String back)> cards;
  final int skipped;
  const PastedCards(this.mode, this.cards, this.skipped);
}

/// A line's question and answer split at the first tab, dash, colon or
/// equals sign with space around it ("Paris – France", "H2O: water").
final _pair = RegExp(r'^(.+?)(?:\t|\s+[–—=-]\s+|\s*:\s+)(.+)$');

/// Words marked to be remembered: **bold**, __bold__, [brackets], {braces}.
final _mark = RegExp(r'\*\*(.+?)\*\*|__(.+?)__|\[(.+?)\]|\{(?!\{)(.+?)\}');

/// Reads pasted notes as cards. Without a [mode], lines that mostly split
/// into question and answer are read as pairs, anything else as sentences
/// with marked words.
PastedCards cardsFromPaste(String text, {PasteMode? mode}) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim().replaceFirst(RegExp(r'^([-*•]|\d+[.)])\s+'), ''))
      .where((l) => l.isNotEmpty)
      .toList();
  mode ??=
      lines.isNotEmpty &&
          lines.where((l) => _pair.hasMatch(l) && !_mark.hasMatch(l)).length *
                  2 >
              lines.length
      ? PasteMode.pairs
      : PasteMode.cloze;
  final cards = <(String, String)>[];
  var skipped = 0;
  if (mode == PasteMode.pairs) {
    for (final l in lines) {
      final m = _pair.firstMatch(l);
      if (m == null) {
        skipped++;
      } else {
        cards.add((m[1]!.trim(), m[2]!.trim()));
      }
    }
  } else {
    // A sentence ends at . ! ? or ; followed by a space, or at a line end.
    final sentences = lines
        .expand((l) => l.split(RegExp(r'(?<=[.!?;])\s+')))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final s in sentences) {
      var n = 0;
      final front = s.replaceAllMapped(_mark, (m) {
        n++;
        final word = m[1] ?? m[2] ?? m[3] ?? m[4]!;
        return '{{c$n::$word}}';
      });
      if (n == 0) {
        skipped++;
      } else {
        cards.add((front, ''));
      }
    }
  }
  if (cards.length > recallCardLimit)
    throw const FormatException('Too many cards in one paste');
  return PastedCards(mode, cards, skipped);
}

/// [cards] as the CSV the card import reads, so a paste is checked and
/// added exactly as a file would be.
String pastedCsv(List<(String, String)> cards) {
  String cell(String s) => '"${s.replaceAll('"', '""')}"';
  return [
    'front,back',
    for (final c in cards) '${cell(c.$1)},${cell(c.$2)}',
  ].join('\n');
}
