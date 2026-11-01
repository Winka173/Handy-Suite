/// Bounded CSV parser extracted from the existing statement reader.
List<List<String>> csvParse(String text, {String delimiter = ','}) {
  if (text.length > 30000000 || ![',', ';', '\t'].contains(delimiter))
    throw const FormatException('CSV limit or delimiter');
  if (text.startsWith('\ufeff')) text = text.substring(1);
  final result = <List<String>>[], row = <String>[];
  var value = StringBuffer(), quoted = false, closed = false;
  void finishCell() {
    row.add(value.toString());
    value = StringBuffer();
    closed = false;
    if (row.length > 256) throw const FormatException('Too many columns');
  }

  void finishRow() {
    finishCell();
    if (row.any((e) => e.isNotEmpty)) result.add(List.of(row));
    row.clear();
    if (result.length > 100001) throw const FormatException('Too many rows');
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          value.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        value.write(c);
      }
      continue;
    }
    if (c == '"' && value.isEmpty && !closed) {
      quoted = true;
      continue;
    }
    if (c == delimiter) {
      finishCell();
      continue;
    }
    if (c == '\r' || c == '\n') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      finishRow();
      continue;
    }
    if (closed) throw const FormatException('Invalid quoted CSV field');
    value.write(c);
  }
  if (quoted) throw const FormatException('Unterminated quoted field');
  if (value.isNotEmpty || row.isNotEmpty || closed) finishRow();
  if (result.isEmpty) throw const FormatException('Empty statement');
  return result;
}
