part of '../handy_recall.dart';

String exportCardsCsv(List<RecallCard> cards) {
  if (cards.length > recallCardLimit)
    throw const FormatException('Too many CSV cards');
  String cell(String text) => '"${text.replaceAll('"', '""')}"';
  // One row per note: a reverse card or another cloze of the same note would
  // only repeat the row, and importing the row makes them again.
  final seen = <String>{};
  final source = [
    'front,back',
    for (final c in cards)
      if (seen.add(noteOf(c)))
        '${cell(RecallCard.fromJson(c.toJson()).front)},${cell(c.back)}',
  ].join('\r\n');
  _backupSize(source);
  return source;
}

/// Cards for every row of a front,back CSV. A front with clozes makes one
/// card per cloze number; otherwise one card, and with [reverse] its reverse
/// card too. Ids are `prefix_row`, its siblings `prefix_row_variant`.
List<RecallCard> importCardsCsv(
  String source,
  String deckId,
  String idPrefix, {
  String? now,
  bool reverse = false,
}) {
  _backupSize(source);
  _id(deckId);
  _id(idPrefix);
  final at = _instant(now ?? _now());
  if (source.startsWith('\ufeff')) source = source.substring(1);
  final rows = <List<String>>[];
  var row = <String>[], field = StringBuffer(), quoted = false, closed = false;
  void pushField() {
    row.add(field.toString());
    field = StringBuffer();
    closed = false;
  }

  void pushRow() {
    pushField();
    if (!(row.length == 1 && row.first.isEmpty)) rows.add(row);
    row = [];
    if (rows.length > recallCardLimit + 1)
      throw const FormatException('Too many CSV cards');
  }

  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    if (quoted) {
      if (ch == '"' && i + 1 < source.length && source[i + 1] == '"') {
        field.write('"');
        i++;
      } else if (ch == '"') {
        quoted = false;
        closed = true;
      } else {
        field.write(ch);
      }
    } else if (ch == ',') {
      pushField();
    } else if (ch == '\r' || ch == '\n') {
      if (ch == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
      pushRow();
    } else if (closed) {
      throw const FormatException('Unexpected text after closing CSV quote');
    } else if (ch == '"') {
      if (field.isNotEmpty)
        throw const FormatException('Unexpected quote inside CSV field');
      quoted = true;
    } else {
      field.write(ch);
    }
    if (field.length > recallTextLimit)
      throw const FormatException('CSV card text too long');
    if (row.length > 2)
      throw const FormatException('CSV requires front and back columns');
  }
  if (quoted) throw const FormatException('Unclosed CSV quote');
  if (field.isNotEmpty || row.isNotEmpty || closed) pushRow();
  if (rows.isEmpty) throw const FormatException('CSV header required');
  final header = rows.removeAt(0);
  if (header.length != 2 ||
      header[0].trim().toLowerCase() != 'front' ||
      header[1].trim().toLowerCase() != 'back')
    throw const FormatException('CSV header must be front,back');
  final cards = <RecallCard>[];
  for (var i = 0; i < rows.length; i++) {
    final cells = rows[i];
    if (cells.length != 2)
      throw const FormatException('CSV requires front and back columns');
    final id = '${idPrefix}_${i + 1}';
    final variants = noteVariants(cells[0], reverse: reverse);
    for (final (n, v) in variants.indexed) {
      cards.add(
        createCard(
          id: n == 0 ? id : '${id}_$v',
          deckId: deckId,
          front: cells[0],
          back: cells[1],
          now: at,
          note: variants.length > 1 ? id : '',
          cloze: v.startsWith('c') ? int.parse(v.substring(1)) : 0,
          reversed: v == 'r',
        ),
      );
    }
    if (cards.length > recallCardLimit)
      throw const FormatException('Too many CSV cards');
  }
  return cards;
}
