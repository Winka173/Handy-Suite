part of '../handy_recall.dart';

String exportCardsCsv(List<RecallCard> cards) {
  if (cards.length > recallCardLimit)
    throw const FormatException('Too many CSV cards');
  String cell(String text) => '"${text.replaceAll('"', '""')}"';
  final source = [
    'front,back',
    ...cards.map((c) {
      final valid = RecallCard.fromJson(c.toJson());
      return '${cell(valid.front)},${cell(valid.back)}';
    }),
  ].join('\r\n');
  _backupSize(source);
  return source;
}

List<RecallCard> importCardsCsv(
  String source,
  String deckId,
  String idPrefix, {
  String? now,
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
  return List.generate(rows.length, (i) {
    final cells = rows[i];
    if (cells.length != 2)
      throw const FormatException('CSV requires front and back columns');
    return createCard(
      id: '${idPrefix}_${i + 1}',
      deckId: deckId,
      front: cells[0],
      back: cells[1],
      now: at,
    );
  });
}
