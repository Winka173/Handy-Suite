// A small legacy Anki package, built on the host with real SQLite.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart';

/// Spanish › Basics: a reviewed basic card, a basic-and-reversed pair, a
/// two-blank cloze, and a sound that will be left out.
Uint8List apkg() {
  final dir = Directory.systemTemp.createTempSync('recall-apkg');
  final path = '${dir.path}/c.db';
  final db = sqlite3.openInMemory();
  try {
    db.execute(
      'CREATE TABLE col (id integer primary key, crt integer not null, mod integer not null, scm integer not null, ver integer not null, dty integer not null, usn integer not null, ls integer not null, conf text not null, models text not null, decks text not null, dconf text not null, tags text not null);'
      'CREATE TABLE notes (id integer primary key, guid text not null, mid integer not null, mod integer not null, usn integer not null, tags text not null, flds text not null, sfld integer not null, csum integer not null, flags integer not null, data text not null);'
      'CREATE TABLE cards (id integer primary key, nid integer not null, did integer not null, ord integer not null, mod integer not null, usn integer not null, type integer not null, queue integer not null, due integer not null, ivl integer not null, factor integer not null, reps integer not null, lapses integer not null, left integer not null, odue integer not null, odid integer not null, flags integer not null, data text not null);',
    );
    const basic = '{{FrontSide}}<hr id=answer>{{Back}}';
    final models = {
      '1': {
        'id': 1,
        'type': 0,
        'flds': [
          {'name': 'Front', 'ord': 0},
          {'name': 'Back', 'ord': 1},
        ],
        'tmpls': [
          {'ord': 0, 'qfmt': '{{Front}}', 'afmt': basic},
          {
            'ord': 1,
            'qfmt': '{{Back}}',
            'afmt': '{{FrontSide}}<hr id=answer>{{Front}}',
          },
        ],
      },
      '2': {
        'id': 2,
        'type': 1,
        'flds': [
          {'name': 'Text', 'ord': 0},
          {'name': 'Back Extra', 'ord': 1},
        ],
        'tmpls': [
          {'ord': 0, 'qfmt': '{{cloze:Text}}', 'afmt': '{{cloze:Text}}'},
        ],
      },
    };
    db.execute(
      "INSERT INTO col VALUES (1,1700000000,0,0,11,0,0,0,'{}',?,?,'{}','{}')",
      [
        jsonEncode(models),
        jsonEncode({
          '9': {'id': 9, 'name': 'Spanish::Basics'},
        }),
      ],
    );
    for (final (id, mid, flds) in [
      (1, 1, 'gato\u001fcat [sound:gato.mp3]'),
      (2, 1, 'perro\u001fdog'),
      (3, 2, '{{c1::Madrid}} is in {{c2::Spain::country}}\u001f'),
    ]) {
      db.execute("INSERT INTO notes VALUES (?,'g',?,0,0,'',?,0,0,0,'')", [
        id,
        mid,
        flds,
      ]);
    }
    // (id, note, ord, type, queue, due, ivl, factor, reps, lapses)
    for (final c in [
      [11, 1, 0, 2, 2, 1087, 20, 2500, 6, 0],
      [21, 2, 0, 0, 0, 1, 0, 0, 0, 0],
      [22, 2, 1, 0, 0, 2, 0, 0, 0, 0],
      [31, 3, 0, 0, 0, 3, 0, 0, 0, 0],
      [32, 3, 1, 0, 0, 4, 0, 0, 0, 0],
    ]) {
      db.execute(
        "INSERT INTO cards VALUES (?,?,9,?,0,0,?,?,?,?,?,?,?,0,0,0,0,'')",
        [c[0], c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9]],
      );
    }
    db.execute('VACUUM INTO ?', [path]);
    final collection = File(path).readAsBytesSync();
    final archive = Archive()
      ..addFile(ArchiveFile('collection.anki21', collection.length, collection))
      ..addFile(ArchiveFile('media', 2, utf8.encode('{}')));
    return ZipEncoder().encodeBytes(archive);
  } finally {
    db.close();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // A temp folder left behind is harmless.
    }
  }
}
