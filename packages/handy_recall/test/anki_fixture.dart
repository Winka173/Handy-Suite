// Small Anki packages built on the host with real SQLite, for the importer.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:sqlite3/sqlite3.dart';

/// Collection creation time: 2023-11-14 22:13:20 UTC.
const crt = 1700000000;
const spanish = 1700000000000;

/// Builds a database file with [build] and returns its bytes.
Uint8List sqliteFile(void Function(Database db) build) {
  final dir = Directory.systemTemp.createTempSync('recall-anki');
  final path = '${dir.path}/c.db';
  // Built in memory, then written whole: closing a file database on Windows
  // can leave it locked until its statements are finalized.
  final db = sqlite3.openInMemory();
  try {
    db.createCollation(
      name: 'unicase',
      function: (a, b) => a!.toLowerCase().compareTo(b!.toLowerCase()),
    );
    build(db);
    db.execute('VACUUM INTO ?', [path]);
    return File(path).readAsBytesSync();
  } finally {
    db.close();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // A temp folder left behind is harmless.
    }
  }
}

Uint8List png() {
  final bitmap = image.Image(width: 4, height: 3);
  image.fill(bitmap, color: image.ColorRgb8(200, 120, 40));
  return image.encodePng(bitmap);
}

/// A PNG-signed file over the 500 KB picture limit.
Uint8List bigPng() => Uint8List(600000)..setAll(0, png().sublist(0, 16));
final gif = Uint8List.fromList(ascii.encode('GIF89a') + List.filled(20, 0));

Uint8List zip(Map<String, List<int>> files, {bool stored = false}) {
  final archive = Archive();
  for (final MapEntry(:key, :value) in files.entries) {
    final f = ArchiveFile(key, value.length, value);
    if (stored) f.compression = CompressionType.none;
    archive.addFile(f);
  }
  return ZipEncoder().encodeBytes(archive);
}

/// The notes every fixture holds, as field lists per note type.
const basicId = 1001, reversedId = 1002, clozeId = 1003, optionalId = 1004;
final notes = <(int id, int type, List<String> fields)>[
  (1, basicId, ['<b>Hola</b>&nbsp;mundo', 'Hello<br>world [sound:hola.mp3]']),
  (2, reversedId, ['犬', 'dog <img src="dog.png">']),
  (
    3,
    clozeId,
    ['{{c1::Paris}} is the capital of {{c2::France::country}}', 'Europe'],
  ),
  (4, optionalId, ['uno', 'one', '']),
  (5, optionalId, ['dos', 'two', 'y']),
  (6, basicId, ['', '<img src="missing.png">']),
  (7, clozeId, ['{{c1::image-occlusion:rect:left=.1:top=.2}}', '']),
  (8, basicId, ['Big <img src="big.png"><img src="anim.gif">', 'picture']),
  (9, basicId, ['<script>alert(1)</script><div>Line</div><div>two</div>', 'x']),
];

/// (card id, note, ord, type, queue, due, ivl, factor, reps, lapses)
final cards = <List<int>>[
  [101, 1, 0, 2, 2, 10, 12, 2300, 5, 1],
  [201, 2, 0, 0, 0, 1, 0, 0, 0, 0],
  [202, 2, 1, 0, 0, 2, 0, 0, 0, 0],
  [301, 3, 0, 1, 1, crt + 60, 0, 2500, 1, 0],
  [302, 3, 1, 0, 0, 3, 0, 0, 0, 0],
  [303, 3, 2, 0, 0, 4, 0, 0, 0, 0], // c3 is not in the text: skipped
  [401, 4, 0, 0, -1, 5, 0, 0, 0, 0], // suspended
  [501, 5, 0, 0, 0, 6, 0, 0, 0, 0],
  [502, 5, 1, 0, 0, 7, 0, 0, 0, 0],
  [601, 6, 0, 0, 0, 8, 0, 0, 0, 0], // missing picture, no text: skipped
  [701, 7, 0, 0, 0, 9, 0, 0, 0, 0], // Anki image occlusion: skipped
  [801, 8, 0, 0, 0, 10, 0, 0, 0, 0],
  [901, 9, 0, 0, 0, 11, 0, 0, 0, 0],
];

final _types = <int, (String, bool, List<String>, List<(String, String)>)>{
  basicId: (
    'Basic',
    false,
    ['Front', 'Back'],
    [('{{Front}}', '{{FrontSide}}<hr id=answer>{{Back}}')],
  ),
  reversedId: (
    'Basic (and reversed card)',
    false,
    ['Front', 'Back'],
    [
      ('{{Front}}', '{{FrontSide}}<hr id=answer>{{Back}}'),
      ('{{Back}}', '{{FrontSide}}<hr id=answer>{{Front}}'),
    ],
  ),
  clozeId: (
    'Cloze',
    true,
    ['Text', 'Back Extra'],
    [('{{cloze:Text}}', '{{cloze:Text}}<br>\n{{Back Extra}}')],
  ),
  optionalId: (
    'Basic (optional reversed card)',
    false,
    ['Front', 'Back', 'Add Reverse'],
    [
      ('{{Front}}', '{{FrontSide}}<hr id=answer>{{Back}}'),
      (
        '{{#Add Reverse}}{{Back}}{{/Add Reverse}}',
        '{{FrontSide}}<hr id=answer>{{Front}}',
      ),
    ],
  ),
};

const _notesSql = '''
CREATE TABLE notes (id integer primary key, guid text not null, mid integer not null, mod integer not null, usn integer not null, tags text not null, flds text not null, sfld integer not null, csum integer not null, flags integer not null, data text not null);
CREATE TABLE cards (id integer primary key, nid integer not null, did integer not null, ord integer not null, mod integer not null, usn integer not null, type integer not null, queue integer not null, due integer not null, ivl integer not null, factor integer not null, reps integer not null, lapses integer not null, left integer not null, odue integer not null, odid integer not null, flags integer not null, data text not null);
''';
const _colSql =
    'CREATE TABLE col (id integer primary key, crt integer not null, mod integer not null, scm integer not null, ver integer not null, dty integer not null, usn integer not null, ls integer not null, conf text not null, models text not null, decks text not null, dconf text not null, tags text not null);';

void _fill(Database db) {
  for (final (id, mid, fields) in notes) {
    db.execute("INSERT INTO notes VALUES (?,?,?,0,0,'',?,0,0,0,'')", [
      id,
      'g$id',
      mid,
      fields.join('\u001f'),
    ]);
  }
  for (final c in cards) {
    db.execute(
      "INSERT INTO cards VALUES (?,?,?,?,0,0,?,?,?,?,?,?,?,0,0,0,0,'')",
      [c[0], c[1], spanish, c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9]],
    );
  }
}

/// A legacy package: `collection.anki21` (schema 11, JSON note types) and a
/// JSON media map, as "Support older Anki versions" writes it.
Uint8List legacyPackage({
  String name = 'collection.anki21',
  bool stored = false,
}) {
  final models = {
    for (final MapEntry(key: id, value: (n, cloze, fields, tmpls))
        in _types.entries)
      '$id': {
        'id': id,
        'name': n,
        'type': cloze ? 1 : 0,
        'flds': [
          for (final (i, f) in fields.indexed) {'name': f, 'ord': i},
        ],
        'tmpls': [
          for (final (i, (q, a)) in tmpls.indexed)
            {'name': 'Card ${i + 1}', 'ord': i, 'qfmt': q, 'afmt': a},
        ],
      },
  };
  final decks = {
    '1': {'id': 1, 'name': 'Default'},
    '$spanish': {'id': spanish, 'name': 'Spanish::Basics'},
  };
  final db = sqliteFile((db) {
    db.execute(_colSql);
    db.execute(_notesSql);
    db.execute("INSERT INTO col VALUES (1,?,0,0,11,0,0,0,'{}',?,?,'{}','{}')", [
      crt,
      jsonEncode(models),
      jsonEncode(decks),
    ]);
    _fill(db);
  });
  return zip({
    name: db,
    'media': utf8.encode(
      jsonEncode({'0': 'dog.png', '1': 'big.png', '2': 'anim.gif'}),
    ),
    '0': png(),
    '1': bigPng(),
    '2': gif,
  }, stored: stored);
}

/// Protobuf, enough for the fixtures.
List<int> _varint(int v) {
  final out = <int>[];
  while (v >= 0x80) {
    out.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  return out..add(v);
}

List<int> pbInt(int field, int v) => [..._varint(field << 3), ..._varint(v)];
List<int> pbBytes(int field, List<int> v) => [
  ..._varint(field << 3 | 2),
  ..._varint(v.length),
  ...v,
];
List<int> pbText(int field, String v) => pbBytes(field, utf8.encode(v));

Uint8List zstd(List<int> data) => ZstdEncoder().encodeBytes(data);

/// A package as Anki 2.1.50+ writes it by default: `collection.anki21b`
/// (zstd, schema 18 with protobuf note types), a protobuf media list, zstd
/// media files and a `meta` saying so, beside a dummy `collection.anki2`.
Uint8List modernPackage({bool badChecksum = false}) {
  final db = sqliteFile((db) {
    db.execute(_colSql);
    db.execute(_notesSql);
    db.execute('''
CREATE TABLE notetypes (id integer NOT NULL PRIMARY KEY, name text NOT NULL COLLATE unicase, mtime_secs integer NOT NULL, usn integer NOT NULL, config blob NOT NULL);
CREATE TABLE fields (ntid integer NOT NULL, ord integer NOT NULL, name text NOT NULL COLLATE unicase, config blob NOT NULL, PRIMARY KEY (ntid, ord)) without rowid;
CREATE TABLE templates (ntid integer NOT NULL, ord integer NOT NULL, name text NOT NULL COLLATE unicase, mtime_secs integer NOT NULL, usn integer NOT NULL, config blob NOT NULL, PRIMARY KEY (ntid, ord)) without rowid;
CREATE TABLE decks (id integer PRIMARY KEY NOT NULL, name text NOT NULL COLLATE unicase, mtime_secs integer NOT NULL, usn integer NOT NULL, common blob NOT NULL, kind blob NOT NULL);
''');
    db.execute("INSERT INTO col VALUES (1,?,0,0,18,0,0,0,'','','','','')", [
      crt,
    ]);
    for (final MapEntry(key: id, value: (n, cloze, fields, tmpls))
        in _types.entries) {
      db.execute('INSERT INTO notetypes VALUES (?,?,0,0,?)', [
        id,
        n,
        Uint8List.fromList([...pbInt(1, cloze ? 1 : 0), ...pbText(3, 'css')]),
      ]);
      for (final (i, f) in fields.indexed) {
        db.execute('INSERT INTO fields VALUES (?,?,?,?)', [
          id,
          i,
          f,
          Uint8List.fromList(pbText(3, 'Arial')),
        ]);
      }
      for (final (i, (q, a)) in tmpls.indexed) {
        db.execute('INSERT INTO templates VALUES (?,?,?,0,0,?)', [
          id,
          i,
          'Card ${i + 1}',
          Uint8List.fromList([...pbText(1, q), ...pbText(2, a)]),
        ]);
      }
    }
    for (final (id, name) in [
      (1, 'Default'),
      (spanish, 'Spanish\u001fBasics'),
    ]) {
      db.execute('INSERT INTO decks VALUES (?,?,0,0,?,?)', [
        id,
        name,
        Uint8List(0),
        Uint8List(0),
      ]);
    }
    _fill(db);
  });
  final dog = png();
  final digest = sha1.convert(dog).bytes;
  final entries = [
    pbBytes(1, [
      ...pbText(1, 'dog.png'),
      ...pbInt(2, dog.length),
      ...pbBytes(3, badChecksum ? List.filled(20, 0) : digest),
    ]),
    pbBytes(1, [...pbText(1, 'big.png'), ...pbInt(2, 600000)]),
    pbBytes(1, [...pbText(1, 'anim.gif'), ...pbInt(2, gif.length)]),
  ];
  return zip({
    'collection.anki2': sqliteFile((db) {
      db.execute(_colSql);
      db.execute(_notesSql);
    }),
    'collection.anki21b': zstd(db),
    'media': zstd(entries.expand((e) => e).toList()),
    'meta': pbInt(1, 3),
    '0': zstd(dog),
    '1': zstd(bigPng()),
    '2': zstd(gif),
  });
}
