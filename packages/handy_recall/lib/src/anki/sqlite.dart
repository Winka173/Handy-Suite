part of '../../anki.dart';

/// A read-only reader for the SQLite file format, enough to scan whole
/// tables of an Anki collection on every platform, the web included, without
/// native SQLite. It follows https://www.sqlite.org/fileformat2.html: table
/// and index b-trees, overflow pages, records, and WITHOUT ROWID tables.
/// It never writes, never follows a page twice, and bounds every walk.
class SqliteFile {
  final Uint8List _b;
  late final int _pageSize, _usable, _pages, _encoding;
  late final Map<String, _Table> _tables;

  SqliteFile(this._b) {
    if (_b.length < 512 ||
        ascii.decode(_b.sublist(0, 15), allowInvalid: true) !=
            'SQLite format 3' ||
        _b[15] != 0)
      throw const FormatException('Not an SQLite database');
    var size = (_b[16] << 8) | _b[17];
    if (size == 1) size = 65536;
    if (size < 512 || size > 65536 || size & (size - 1) != 0)
      throw const FormatException('Invalid SQLite page size');
    _pageSize = size;
    _usable = size - _b[20];
    if (_usable < 480) throw const FormatException('Invalid SQLite page');
    _pages = _b.length ~/ size;
    final enc = _u32(56);
    _encoding = enc == 0 ? 1 : enc;
    if (_encoding < 1 || _encoding > 3)
      throw const FormatException('Unknown SQLite text encoding');
    _tables = {};
    for (final row in _scan(1, false)) {
      final values = row.$2;
      if (values.length < 5 || values[0] != 'table') continue;
      final name = values[1], root = values[3], sql = values[4];
      if (name is String && root is int && sql is String && root > 0) {
        _tables[name.toLowerCase()] = _Table.parse(root, sql);
      }
    }
  }

  bool has(String table) => _tables.containsKey(table.toLowerCase());

  /// Every row of [table], each a map from column name (lower case) to its
  /// value: int, double, String, Uint8List or null.
  Iterable<Map<String, Object?>> rows(String table) sync* {
    final t = _tables[table.toLowerCase()];
    if (t == null) throw FormatException('Missing table $table');
    for (final (rowid, values) in _scan(t.root, t.withoutRowid)) {
      final row = <String, Object?>{};
      for (var i = 0; i < t.columns.length; i++) {
        final at = t.recordIndex[i];
        row[t.columns[i]] = at < values.length ? values[at] : null;
      }
      if (t.rowidAlias >= 0 && row[t.columns[t.rowidAlias]] == null) {
        row[t.columns[t.rowidAlias]] = rowid;
      }
      yield row;
    }
  }

  int _u16(int at) => (_b[at] << 8) | _b[at + 1];
  int _u32(int at) =>
      _b[at] * 16777216 + (_b[at + 1] << 16 | _b[at + 2] << 8 | _b[at + 3]);

  int _pageStart(int page) {
    if (page < 1 || page > _pages)
      throw const FormatException('SQLite page out of range');
    return (page - 1) * _pageSize;
  }

  /// (value, bytes read) of the varint at [at].
  (int, int) _varint(int at) {
    var v = 0;
    for (var i = 0; i < 8; i++) {
      final byte = _b[at + i];
      v = v * 128 + (byte & 0x7f);
      if (byte < 0x80) return (v, i + 1);
    }
    return (v * 256 + _b[at + 8], 9);
  }

  /// Rows of the b-tree rooted at [root]: (rowid, record values). Index
  /// b-trees (WITHOUT ROWID tables) have no rowid and yield 0.
  Iterable<(int, List<Object?>)> _scan(int root, bool index) sync* {
    final seen = <int>{};
    final stack = <(int, int)>[(root, 0)];
    while (stack.isNotEmpty) {
      final (page, depth) = stack.removeLast();
      if (depth > 40 || !seen.add(page))
        throw const FormatException('SQLite b-tree loops');
      final start = _pageStart(page), head = page == 1 ? start + 100 : start;
      final type = _b[head];
      final cells = _u16(head + 3);
      final interior = type == 2 || type == 5;
      if (![2, 5, 10, 13].contains(type) ||
          (index && (type == 5 || type == 13)) ||
          (!index && (type == 2 || type == 10)))
        throw const FormatException('Unexpected SQLite page');
      final pointers = head + (interior ? 12 : 8);
      final children = <int>[];
      final found = <(int, List<Object?>)>[];
      for (var i = 0; i < cells; i++) {
        var at = start + _u16(pointers + 2 * i);
        if (at >= start + _pageSize)
          throw const FormatException('SQLite cell out of page');
        if (interior) {
          children.add(_u32(at));
          at += 4;
          if (!index) continue; // A table interior cell holds only a key.
        }
        final (size, n) = _varint(at);
        at += n;
        var rowid = 0;
        if (!index) {
          final (id, m) = _varint(at);
          rowid = id;
          at += m;
        }
        found.add((rowid, _record(_payload(at, size, index))));
      }
      if (interior) children.add(_u32(head + 8));
      // Children are walked in order; an index interior cell's own entry is
      // a real row too and is kept.
      yield* found;
      for (final c in children.reversed) {
        stack.add((c, depth + 1));
      }
    }
  }

  Uint8List _payload(int at, int size, bool index) {
    final u = _usable;
    final x = index ? ((u - 12) * 64 ~/ 255) - 23 : u - 35;
    final m = ((u - 12) * 32 ~/ 255) - 23;
    if (size < 0 || size > 1 << 30)
      throw const FormatException('SQLite payload too large');
    if (size <= x) return Uint8List.sublistView(_b, at, at + size);
    final k = m + ((size - m) % (u - 4));
    final local = k <= x ? k : m;
    final out = BytesBuilder(copy: false)
      ..add(Uint8List.sublistView(_b, at, at + local));
    var next = _u32(at + local), left = size - local, hops = 0;
    while (left > 0) {
      if (next == 0 || ++hops > _pages)
        throw const FormatException('Broken SQLite overflow chain');
      final start = _pageStart(next);
      final take = left < u - 4 ? left : u - 4;
      out.add(Uint8List.sublistView(_b, start + 4, start + 4 + take));
      left -= take;
      next = _u32(start);
    }
    return out.takeBytes();
  }

  List<Object?> _record(Uint8List r) {
    final d = ByteData.sublistView(r);
    int varint(int at, void Function(int) len) {
      var v = 0;
      for (var i = 0; i < 8; i++) {
        final byte = r[at + i];
        v = v * 128 + (byte & 0x7f);
        if (byte < 0x80) {
          len(i + 1);
          return v;
        }
      }
      len(9);
      return v * 256 + r[at + 8];
    }

    var n = 0;
    final headerSize = varint(0, (l) => n = l);
    if (headerSize > r.length) throw const FormatException('Bad record');
    final types = <int>[];
    var at = n;
    while (at < headerSize) {
      types.add(varint(at, (l) => n = l));
      at += n;
    }
    var body = headerSize;
    final values = <Object?>[];
    int unsigned(int from, int count) {
      var v = 0;
      for (var i = 0; i < count; i++) {
        v = v * 256 + r[from + i];
      }
      return v;
    }

    // Arithmetic, not shifts, so 48- and 64-bit values come out right under
    // dart2js as well (exact up to 2^53 there; Anki ids are well below).
    int signed(int bytes) {
      final high = bytes > 4 ? bytes - 4 : bytes;
      var v = unsigned(body, high);
      if (r[body] >= 0x80) v -= math.pow(2, 8 * high).toInt();
      return bytes > 4 ? v * 4294967296 + unsigned(body + high, 4) : v;
    }

    for (final t in types) {
      final len = switch (t) {
        0 || 8 || 9 => 0,
        1 => 1,
        2 => 2,
        3 => 3,
        4 => 4,
        5 => 6,
        6 || 7 => 8,
        >= 12 => (t - (t.isEven ? 12 : 13)) ~/ 2,
        _ => throw const FormatException('Bad record type'),
      };
      if (body + len > r.length) throw const FormatException('Bad record');
      values.add(switch (t) {
        0 => null,
        8 => 0,
        9 => 1,
        7 => d.getFloat64(body),
        >= 1 && <= 6 => signed(len),
        _ when t.isEven => Uint8List.fromList(r.sublist(body, body + len)),
        _ => _string(Uint8List.sublistView(r, body, body + len)),
      });
      body += len;
    }
    return values;
  }

  String _string(Uint8List bytes) {
    if (_encoding == 1) return utf8.decode(bytes, allowMalformed: true);
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(
        _encoding == 2
            ? bytes[i] | bytes[i + 1] << 8
            : bytes[i] << 8 | bytes[i + 1],
      );
    }
    return String.fromCharCodes(units);
  }
}

/// A table's columns from its CREATE TABLE statement.
class _Table {
  final int root;
  final bool withoutRowid;
  final List<String> columns;

  /// Where each declared column sits in the stored record.
  final List<int> recordIndex;

  /// The INTEGER PRIMARY KEY column, stored as the rowid, or -1.
  final int rowidAlias;
  _Table(
    this.root,
    this.withoutRowid,
    this.columns,
    this.recordIndex,
    this.rowidAlias,
  );

  factory _Table.parse(int root, String sql) {
    final open = sql.indexOf('('), close = sql.lastIndexOf(')');
    if (open < 0 || close < open) throw const FormatException('Bad table SQL');
    final tail = sql.substring(close + 1).toLowerCase();
    final withoutRowid = RegExp(r'without\s+rowid').hasMatch(tail);
    final parts = <String>[];
    var depth = 0, from = open + 1;
    String? quote;
    for (var i = open + 1; i < close; i++) {
      final ch = sql[i];
      if (quote != null) {
        if (ch == quote) quote = null;
      } else if (ch == '"' || ch == "'" || ch == '`') {
        quote = ch;
      } else if (ch == '[') {
        quote = ']';
      } else if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
      } else if (ch == ',' && depth == 0) {
        parts.add(sql.substring(from, i));
        from = i + 1;
      }
    }
    parts.add(sql.substring(from, close));
    final columns = <String>[], pk = <String>[];
    var alias = -1;
    final constraint = RegExp(
      r'^(constraint|primary|unique|check|foreign)\b',
      caseSensitive: false,
    );
    for (final raw in parts) {
      final def = raw.trim();
      if (def.isEmpty) continue;
      if (constraint.hasMatch(def)) {
        final m = RegExp(
          r'primary\s+key\s*\(([^)]*)\)',
          caseSensitive: false,
        ).firstMatch(def);
        if (m != null) {
          pk.addAll(m[1]!.split(',').map((c) => _unquote(c.trim())));
        }
        continue;
      }
      final words = def.split(RegExp(r'\s+'));
      final name = _unquote(words.first);
      columns.add(name);
      final lower = def.toLowerCase();
      if (RegExp(r'primary\s+key').hasMatch(lower)) {
        pk.add(name);
        if (words.length > 1 && words[1].toLowerCase() == 'integer') {
          alias = columns.length - 1;
        }
      }
    }
    // A WITHOUT ROWID table stores its key columns first, then the rest.
    final order = withoutRowid
        ? [
            for (final k in pk)
              if (columns.contains(k)) k,
            for (final c in columns)
              if (!pk.contains(c)) c,
          ]
        : columns;
    return _Table(root, withoutRowid, columns, [
      for (final c in columns) order.indexOf(c),
    ], withoutRowid ? -1 : alias);
  }

  static String _unquote(String s) {
    if (s.length >= 2 &&
        ((s.startsWith('"') && s.endsWith('"')) ||
            (s.startsWith('`') && s.endsWith('`')) ||
            (s.startsWith('[') && s.endsWith(']')) ||
            (s.startsWith("'") && s.endsWith("'")))) {
      s = s.substring(1, s.length - 1);
    }
    return s.toLowerCase();
  }
}
