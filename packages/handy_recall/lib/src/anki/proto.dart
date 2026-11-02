part of '../../anki.dart';

/// The fields of one protobuf message: field number to its values, each an
/// int (varint and fixed widths) or a Uint8List (length-delimited). Enough
/// for the few Anki messages read here; unknown fields are skipped.
Map<int, List<Object>> _proto(Uint8List b) {
  final fields = <int, List<Object>>{};
  var at = 0;
  int varint() {
    var v = 0, scale = 1;
    for (var i = 0; i < 10; i++) {
      final byte = b[at++];
      v += (byte & 0x7f) * scale;
      if (byte < 0x80) return v;
      scale *= 128;
    }
    throw const FormatException('Bad protobuf varint');
  }

  int fixed(int n) {
    var v = 0;
    for (var i = n - 1; i >= 0; i--) {
      v = v * 256 + b[at + i];
    }
    at += n;
    return v;
  }

  try {
    while (at < b.length) {
      final key = varint(), number = key ~/ 8, wire = key % 8;
      final Object value = switch (wire) {
        0 => varint(),
        1 => fixed(8),
        5 => fixed(4),
        2 => () {
          final n = varint();
          if (n < 0 || at + n > b.length)
            throw const FormatException('Bad protobuf length');
          final v = Uint8List.sublistView(b, at, at + n);
          at += n;
          return v;
        }(),
        _ => throw const FormatException('Bad protobuf wire type'),
      };
      (fields[number] ??= []).add(value);
    }
  } on RangeError {
    throw const FormatException('Truncated protobuf');
  }
  return fields;
}

String _protoString(Map<int, List<Object>> m, int field) {
  final v = m[field]?.first;
  return v is Uint8List ? utf8.decode(v, allowMalformed: true) : '';
}

int _protoInt(Map<int, List<Object>> m, int field) {
  final v = m[field]?.first;
  return v is int ? v : 0;
}
