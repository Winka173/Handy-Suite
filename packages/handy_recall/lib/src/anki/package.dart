part of '../../anki.dart';

/// Largest package accepted, and largest collection inside it once
/// decompressed. Pictures are bounded separately below.
const ankiPackageMaxBytes = 100 * 1024 * 1024,
    ankiCollectionMaxBytes = 128 * 1024 * 1024,
    ankiEntryLimit = 60000;

/// At most this many pictures, and this many bytes of them, come in with one
/// import, so the library stays well inside its 16 MB backup.
const ankiImageLimit = 300, ankiImageBudget = 6000000;

/// How the package was written: `collection.anki2` (Anki 2.0),
/// `collection.anki21` (2.1, "Support older Anki versions"), or
/// `collection.anki21b` (2.1.50 and later: zstd and protobuf).
enum AnkiFormat { anki2, anki21, anki21b }

class AnkiDeck {
  final int id;
  final String name;
  final int cards;
  const AnkiDeck(this.id, this.name, this.cards);
}

enum AnkiKind { basic, reversed, cloze }

/// One card ready to come in, before it has a Recall id.
class AnkiCard {
  final int ankiId, noteId, deck;
  final String front, back;
  final RecallImage? image;
  final int cloze;
  final AnkiKind kind;

  /// Shares a Recall note with other cards of its Anki note (reverse card,
  /// other cloze numbers).
  final bool linked;

  /// Recall schedule fields from Anki's, empty for a card never reviewed.
  final Map<String, Object?> schedule;
  const AnkiCard({
    required this.ankiId,
    required this.noteId,
    required this.deck,
    required this.front,
    required this.back,
    required this.image,
    required this.cloze,
    required this.kind,
    required this.linked,
    required this.schedule,
  });
  bool get reversed => kind == AnkiKind.reversed;
}

/// What a package holds, read and checked in full before anything is
/// written: the preview, and [addTo] to build the library it would make.
class AnkiImport {
  final AnkiFormat format;
  final List<AnkiDeck> decks;
  final List<AnkiCard> cards;
  final int notes;

  /// Cards left out: empty once cleaned, an unknown note type, an Anki image
  /// occlusion, or a cloze number missing from the text.
  final int skipped;

  /// Pictures kept (PNG or JPEG up to 500 KB, within the import budget) and
  /// left out (other formats, too large, damaged, missing, over budget, or
  /// a second picture on the same side).
  final int imagesKept, imagesDropped;

  /// Sounds and videos removed (Recall plays none).
  final int sounds;

  /// Cards Anki had suspended, and cards still in learning steps.
  final int suspended, learning;
  const AnkiImport({
    required this.format,
    required this.decks,
    required this.cards,
    required this.notes,
    required this.skipped,
    required this.imagesKept,
    required this.imagesDropped,
    required this.sounds,
    required this.suspended,
    required this.learning,
  });

  int count(AnkiKind kind) => cards.where((c) => c.kind == kind).length;

  /// Cards with review history in Anki, which [addTo] can keep.
  int get withHistory => cards.where((c) => c.schedule.isNotEmpty).length;

  /// [state] with every deck and card of this package added as new decks.
  /// With [keepSchedule], reviewed cards keep Anki's interval, ease, review
  /// count, lapses and due day; otherwise every card starts new. Throws
  /// before anything changes if the library would pass its limits.
  RecallState addTo(
    RecallState state, {
    required bool keepSchedule,
    required String idPrefix,
    String? now,
  }) {
    final at = now ?? DateTime.now().toUtc().toIso8601String();
    final deckIds = <int, String>{};
    final decks = [...state.decks.map((d) => d.toJson())];
    for (final (i, d) in this.decks.indexed) {
      deckIds[d.id] = '${idPrefix}_d$i';
      decks.add(RecallDeck(id: deckIds[d.id]!, name: d.name).toJson());
    }
    final cards = [...state.cards.map((c) => c.toJson())];
    for (final c in this.cards) {
      var card = createCard(
        id: '${idPrefix}_${c.ankiId}',
        deckId: deckIds[c.deck]!,
        front: c.front,
        back: c.back,
        image: c.image,
        now: at,
        note: c.linked ? '${idPrefix}_n${c.noteId}' : '',
        cloze: c.cloze,
        reversed: c.reversed,
      );
      if (keepSchedule && c.schedule.isNotEmpty) {
        card = card.copyWith(c.schedule);
      }
      cards.add(card.toJson());
    }
    final next = validateRecallState({
      'version': recallSchemaVersion,
      'decks': decks,
      'cards': cards,
    });
    // The same check a save makes, so a library too large fails here.
    exportRecallBackup(next);
    return next;
  }
}

const _notAnki =
    'This is not an Anki package (.apkg or .colpkg) / Đây không phải gói Anki (.apkg hoặc .colpkg)';
const _damaged = 'This Anki package is damaged / Gói Anki này bị hỏng';
const _reexport =
    'This newer Anki package could not be read. In Anki, export it again with "Support older Anki versions" ticked / '
    'Không đọc được gói Anki định dạng mới này. Trong Anki, hãy xuất lại và đánh dấu "Support older Anki versions"';

/// Reads a whole Anki package and checks it; nothing is written. Throws a
/// [FormatException] in "English / Tiếng Việt" saying what is wrong.
AnkiImport readAnkiPackage(Uint8List bytes, {String? now}) {
  final at = DateTime.parse(now ?? DateTime.now().toUtc().toIso8601String());
  if (bytes.length > ankiPackageMaxBytes)
    throw const FormatException(
      'This Anki package is larger than 100 MB / Gói Anki lớn hơn 100 MB',
    );
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException(_notAnki);
  }
  if (zip.length > ankiEntryLimit) throw const FormatException(_damaged);
  final files = <String, ArchiveFile>{};
  for (final f in zip) {
    final name = f.name;
    if (name.startsWith('/') ||
        name.contains('\\') ||
        name.contains(':') ||
        name.split('/').any((part) => part == '..'))
      throw const FormatException(
        'This package has unsafe file names / Gói có tên file không an toàn',
      );
    if (f.isFile) files[name] = f;
  }
  return _Reader(files, at).read();
}

class _NoteType {
  final bool cloze;
  final List<String> fields;
  final Map<int, (String, String)> templates;
  const _NoteType(this.cloze, this.fields, this.templates);
  int field(String name) {
    final lower = name.toLowerCase();
    return fields.indexWhere((f) => f.toLowerCase() == lower);
  }
}

class _Media {
  final String member;
  final int size;
  final List<int>? sha1;
  const _Media(this.member, this.size, this.sha1);
}

class _Reader {
  final Map<String, ArchiveFile> files;
  final DateTime now;
  _Reader(this.files, this.now);

  late AnkiFormat format;
  late SqliteFile db;
  final types = <int, _NoteType>{};
  final deckNames = <int, String>{};
  final media = <String, _Media>{};
  final pictures = <String, Uint8List?>{};
  int crt = 0, skipped = 0, kept = 0, dropped = 0, sounds = 0;
  int suspended = 0, learning = 0, budget = ankiImageBudget;

  Uint8List entry(String name, int max) {
    final f = files[name]!;
    if (f.size > max) throw const FormatException(_damaged);
    final Uint8List data;
    try {
      data = f.readBytes() ?? Uint8List(0);
    } catch (_) {
      throw const FormatException(_damaged);
    }
    if (data.length != f.size || (f.crc32 != null && getCrc32(data) != f.crc32))
      throw const FormatException(_damaged);
    return data;
  }

  static bool zstd(Uint8List b) =>
      b.length >= 4 &&
      b[0] == 0x28 &&
      b[1] == 0xb5 &&
      b[2] == 0x2f &&
      b[3] == 0xfd;

  Uint8List unzstd(Uint8List b, int max) => ZstdDecoder().decodeBytes(
    b,
    verify: true,
    throwOnError: true,
    maxOutputSize: max,
  );

  AnkiImport read() {
    var version = 0;
    if (files.containsKey('meta')) {
      try {
        var meta = entry('meta', 4096);
        if (zstd(meta)) meta = unzstd(meta, 4096);
        version = _protoInt(_proto(meta), 1);
      } on FormatException {
        rethrow;
      } catch (_) {
        throw const FormatException(_damaged);
      }
    }
    final Uint8List collection;
    if (files.containsKey('collection.anki21b')) {
      format = AnkiFormat.anki21b;
      try {
        collection = unzstd(
          entry('collection.anki21b', ankiCollectionMaxBytes),
          ankiCollectionMaxBytes,
        );
      } catch (_) {
        throw const FormatException(_reexport);
      }
    } else if (version >= 3) {
      throw const FormatException(_reexport);
    } else if (files.containsKey('collection.anki21')) {
      format = AnkiFormat.anki21;
      collection = entry('collection.anki21', ankiCollectionMaxBytes);
    } else if (files.containsKey('collection.anki2')) {
      format = AnkiFormat.anki2;
      collection = entry('collection.anki2', ankiCollectionMaxBytes);
    } else {
      throw const FormatException(_notAnki);
    }
    try {
      db = SqliteFile(collection);
      return _cards();
    } on FormatException catch (e) {
      // Our own messages pass through; a structural one means damage.
      if (e.message.contains(' / ')) rethrow;
      throw format == AnkiFormat.anki21b
          ? const FormatException(_reexport)
          : const FormatException(_damaged);
    } on RangeError {
      throw const FormatException(_damaged);
    } on TypeError {
      throw const FormatException(_damaged);
    }
  }

  AnkiImport _cards() {
    final col = db.rows('col').firstOrNull;
    if (col == null) throw const FormatException(_damaged);
    crt = col['crt'] is int ? col['crt'] as int : 0;
    if (db.has('notetypes')) {
      _modernTypes();
    } else {
      _legacyTypes(col);
    }
    _media();
    final notes = <int, Map<String, Object?>>{
      for (final n in db.rows('notes'))
        if (n['id'] is int) n['id'] as int: n,
    };
    final byNote = <int, List<Map<String, Object?>>>{};
    for (final c in db.rows('cards')) {
      if (c['nid'] is int && c['id'] is int) {
        (byNote[c['nid'] as int] ??= []).add(c);
      }
    }
    final out = <AnkiCard>[];
    var noteCount = 0;
    for (final nid in byNote.keys.toList()..sort()) {
      final rows = byNote[nid]!
        ..sort(
          (a, b) => (a['ord'] as int? ?? 0).compareTo(b['ord'] as int? ?? 0),
        );
      final note = notes[nid];
      final type = note == null ? null : types[note['mid']];
      final made = note == null || type == null
          ? const <AnkiCard>[]
          : _note(nid, note, type, rows);
      skipped += rows.length - made.length;
      if (made.isNotEmpty) noteCount++;
      out.addAll(made);
      if (out.length > recallCardLimit)
        throw const FormatException(
          'This package has more than 20,000 cards / Gói có hơn 20.000 thẻ',
        );
    }
    final counts = <int, int>{};
    for (final c in out) {
      counts[c.deck] = (counts[c.deck] ?? 0) + 1;
    }
    final decks = [
      for (final id in counts.keys) AnkiDeck(id, _deckName(id), counts[id]!),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (decks.length > recallDeckLimit)
      throw const FormatException(
        'This package has more than 500 decks / Gói có hơn 500 bộ thẻ',
      );
    return AnkiImport(
      format: format,
      decks: decks,
      cards: out,
      notes: noteCount,
      skipped: skipped,
      imagesKept: kept,
      imagesDropped: dropped,
      sounds: sounds,
      suspended: suspended,
      learning: learning,
    );
  }

  String _deckName(int id) {
    var name = (deckNames[id] ?? '')
        .replaceAll('\u001f', ' › ')
        .replaceAll('::', ' › ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.isEmpty) name = 'Anki';
    return name.length > 200 ? name.substring(0, 200).trim() : name;
  }

  void _legacyTypes(Map<String, Object?> col) {
    final models = jsonDecode(col['models'] as String? ?? '{}');
    final decks = jsonDecode(col['decks'] as String? ?? '{}');
    if (models is! Map || decks is! Map) throw const FormatException(_damaged);
    for (final m in models.values) {
      if (m is! Map || m['id'] == null) continue;
      final id = m['id'] is int ? m['id'] as int : int.tryParse('${m['id']}');
      if (id == null) continue;
      final fields = [...(m['flds'] as List? ?? const [])]
        ..sort(
          (a, b) =>
              ((a as Map)['ord'] as int).compareTo((b as Map)['ord'] as int),
        );
      types[id] = _NoteType(
        m['type'] == 1,
        [for (final f in fields) '${(f as Map)['name']}'],
        {
          for (final t in (m['tmpls'] as List? ?? const []))
            (t as Map)['ord'] as int: (
              '${t['qfmt'] ?? ''}',
              '${t['afmt'] ?? ''}',
            ),
        },
      );
    }
    for (final d in decks.values) {
      if (d is Map && d['id'] != null) {
        final id = d['id'] is int ? d['id'] as int : int.tryParse('${d['id']}');
        if (id != null) deckNames[id] = '${d['name'] ?? ''}';
      }
    }
  }

  void _modernTypes() {
    final fields = <int, Map<int, String>>{};
    for (final f in db.rows('fields')) {
      (fields[f['ntid'] as int] ??= {})[f['ord'] as int] = '${f['name']}';
    }
    final templates = <int, Map<int, (String, String)>>{};
    for (final t in db.rows('templates')) {
      final config = _proto(t['config'] as Uint8List);
      (templates[t['ntid'] as int] ??= {})[t['ord'] as int] = (
        _protoString(config, 1),
        _protoString(config, 2),
      );
    }
    for (final n in db.rows('notetypes')) {
      final id = n['id'] as int;
      final config = n['config'] is Uint8List
          ? _proto(n['config'] as Uint8List)
          : const <int, List<Object>>{};
      final f = fields[id] ?? const {};
      types[id] = _NoteType(_protoInt(config, 1) == 1, [
        for (final ord in f.keys.toList()..sort()) f[ord]!,
      ], templates[id] ?? const {});
    }
    for (final d in db.rows('decks')) {
      if (d['id'] is int) deckNames[d['id'] as int] = '${d['name'] ?? ''}';
    }
  }

  void _media() {
    if (!files.containsKey('media')) return;
    var raw = entry('media', 64 * 1024 * 1024);
    try {
      if (format == AnkiFormat.anki21b || zstd(raw)) {
        if (zstd(raw)) raw = unzstd(raw, 64 * 1024 * 1024);
        final list = _proto(raw)[1] ?? const [];
        for (final (i, e) in list.indexed) {
          final m = _proto(e as Uint8List);
          final name = _protoString(m, 1);
          final legacy = m[255]?.first;
          final sha = m[3]?.first;
          if (name.isEmpty) continue;
          media[name] = _Media(
            '${legacy is int ? legacy : i}',
            _protoInt(m, 2),
            sha is Uint8List && sha.length == 20 ? sha : null,
          );
        }
      } else {
        final map = jsonDecode(utf8.decode(raw));
        if (map is! Map) throw const FormatException(_damaged);
        for (final MapEntry(:key, :value) in map.entries) {
          if (value is String) media[value] = _Media('$key', -1, null);
        }
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(_damaged);
    }
  }

  /// The picture called [name], checked, or null if it cannot come in.
  Uint8List? _picture(String name) {
    if (pictures.containsKey(name)) return pictures[name];
    Uint8List? bytes;
    var m = media[name];
    if (m == null && name.contains('%')) {
      try {
        m = media[Uri.decodeComponent(name)];
      } catch (_) {}
    }
    if (m != null && files.containsKey(m.member)) {
      try {
        final f = files[m.member]!;
        // Compressed or not, nothing past the picture limit is inflated.
        if (f.size <= ankiPackageMaxBytes) {
          var data = entry(m.member, ankiPackageMaxBytes);
          if (zstd(data)) data = unzstd(data, recallImageMaxBytes + 1);
          final sizeOk = m.size < 0 || m.size == data.length;
          final shaOk =
              m.sha1 == null || _same(sha1.convert(data).bytes, m.sha1!);
          if (sizeOk && shaOk && data.length <= recallImageMaxBytes) {
            bytes = data;
          }
        }
      } catch (_) {
        bytes = null;
      }
    }
    return pictures[name] = bytes;
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// A Recall picture from the first of [names] that can come in, and the
  /// name it came from.
  (RecallImage, String)? _image(List<String> names, String side) {
    for (final name in names) {
      if (kept >= ankiImageLimit) return null;
      final b = _picture(name);
      if (b == null || b.length > budget) continue;
      final png = b.length > 8 && b[0] == 0x89 && b[1] == 0x50;
      final jpeg = b.length > 3 && b[0] == 0xff && b[1] == 0xd8;
      if (!png && !jpeg) continue;
      try {
        final image = RecallImage.fromJson({
          'dataUri':
              'data:image/${png ? 'png' : 'jpeg'};base64,${base64Encode(b)}',
          'masks': const [],
          'side': side,
        });
        budget -= b.length;
        kept++;
        return (image, name);
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  /// The fields a template shows, in order: plain `{{Name}}` and filtered
  /// `{{text:Name}}`; `{{FrontSide}}` as '@FrontSide'; with [answer],
  /// `{{type:Name}}` too. Conditionals, comments, TTS and special fields
  /// show no field of their own.
  static List<String> _refs(String template, {bool answer = false}) {
    final out = <String>[];
    for (final m in RegExp(r'\{\{([^{}]+)\}\}').allMatches(template)) {
      final tag = m[1]!.trim();
      if (tag.isEmpty || '#^/!'.contains(tag[0])) continue;
      if (tag == 'FrontSide') {
        out.add('@FrontSide');
        continue;
      }
      final parts = tag.split(':');
      final name = parts.last.trim();
      final filters = parts.sublist(0, parts.length - 1).map((f) => f.trim());
      if (filters.any((f) => f.startsWith('tts'))) continue;
      if (filters.contains('type') && !answer) continue;
      if (const {
        'Tags',
        'Deck',
        'Subdeck',
        'Card',
        'CardFlag',
        'Type',
        'CardID',
      }.contains(name))
        continue;
      if (!out.contains(name)) out.add(name);
    }
    return out;
  }

  List<AnkiCard> _note(
    int nid,
    Map<String, Object?> note,
    _NoteType type,
    List<Map<String, Object?>> rows,
  ) {
    final values = '${note['flds'] ?? ''}'.split('\u001f');
    // Anki's own image occlusion keeps shapes, not text, in its fields.
    if (values.any((v) => v.contains('image-occlusion:'))) return const [];
    final cleaned = <int, _Clean>{};
    _Clean field(int i) =>
        cleaned[i] ??= _clean(i >= 0 && i < values.length ? values[i] : '');
    ({String text, List<String> images}) join(Iterable<String> names) {
      final texts = <String>[], images = <String>[];
      for (final n in names) {
        final i = type.field(n);
        if (i < 0) continue;
        final c = field(i);
        if (c.text.isNotEmpty) texts.add(c.text);
        images.addAll(c.images);
      }
      return (text: texts.join('\n'), images: images);
    }

    final drafts = <_Draft>[];
    if (type.cloze) {
      final q = type.templates[0]?.$1 ?? '';
      final m = RegExp(r'\{\{[^{}]*cloze:([^{}]+)\}\}').firstMatch(q);
      final clozeName = m != null
          ? m[1]!.trim()
          : (type.fields.isEmpty ? '' : type.fields.first);
      final text = join([clozeName]);
      final extra = join(
        _refs(
          type.templates[0]?.$2 ?? '',
          answer: true,
        ).where((r) => r != '@FrontSide' && r != clozeName),
      );
      final numbers = clozeNumbers(text.text);
      for (final r in rows) {
        final n = (r['ord'] as int? ?? 0) + 1;
        if (!numbers.contains(n)) continue;
        drafts.add(
          _Draft(r, text.text, extra.text, text.images, extra.images, n),
        );
      }
    } else {
      for (final r in rows) {
        final t = type.templates[r['ord']];
        if (t == null) continue;
        final qNames = _refs(t.$1);
        final aNames = _refs(
          t.$2,
          answer: true,
        ).where((n) => n != '@FrontSide' && !qNames.contains(n));
        final q = join(qNames), a = join(aNames);
        drafts.add(_Draft(r, q.text, a.text, q.images, a.images, 0));
      }
      // A later card whose sides are the first card's swapped is its
      // reverse: kept as one note so editing one edits both.
      final base = drafts.firstOrNull;
      for (var i = 1; i < drafts.length; i++) {
        final d = drafts[i];
        if (d.front == base!.back &&
            d.back == base.front &&
            base.front != base.back) {
          drafts[i] = _Draft(
            d.row,
            base.front,
            base.back,
            base.frontImages,
            base.backImages,
            0,
            reversed: true,
          );
        }
      }
    }
    final clozes = drafts.where((d) => d.cloze > 0).length;
    final reverse = drafts.any((d) => d.reversed);
    final named = <String>{
      for (final d in drafts) ...[...d.frontImages, ...d.backImages],
    };
    final used = <String>{};
    final out = <AnkiCard>[];
    for (final (i, d) in drafts.indexed) {
      // One picture per card: the question side's first, else the answer's.
      final picked = d.frontImages.isNotEmpty
          ? _image(d.frontImages, 'front')
          : d.backImages.isNotEmpty
          ? _image(d.backImages, 'back')
          : null;
      if (picked != null) used.add(picked.$2);
      final image = picked?.$1;
      if ((d.front.isEmpty && image == null) ||
          (d.back.isEmpty && image == null && d.cloze == 0))
        continue;
      out.add(
        AnkiCard(
          ankiId: d.row['id'] as int,
          noteId: nid,
          deck: _deckOf(d.row),
          front: d.front,
          back: d.back,
          image: image,
          cloze: d.cloze,
          kind: d.cloze > 0
              ? AnkiKind.cloze
              : d.reversed
              ? AnkiKind.reversed
              : AnkiKind.basic,
          linked: d.cloze > 0 ? clozes > 1 : reverse && (i == 0 || d.reversed),
          schedule: _schedule(d.row),
        ),
      );
    }
    dropped += named.difference(used).length;
    for (var i = 0; i < values.length; i++) {
      sounds += field(i).sounds;
    }
    return out;
  }

  int _deckOf(Map<String, Object?> row) {
    final odid = row['odid'] as int? ?? 0;
    return odid != 0 ? odid : row['did'] as int? ?? 0;
  }

  String _iso(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
    t.millisecondsSinceEpoch,
    isUtc: true,
  ).toIso8601String();

  /// Recall's schedule for an Anki card. Review cards keep interval, ease,
  /// reviews, lapses and due day; cards in (re)learning steps keep their
  /// history and are due now, since Recall has no learning steps.
  Map<String, Object?> _schedule(Map<String, Object?> row) {
    int n(String k) => row[k] is int ? row[k] as int : 0;
    final type = n('type'), queue = n('queue'), reps = n('reps');
    if (queue == -1) suspended++;
    if (type == 1 || type == 3 || queue == 1 || queue == 3) learning++;
    if (type == 0 || reps <= 0) return const {};
    final factor = n('factor');
    final ease = factor <= 0 ? 2.5 : (factor / 1000).clamp(1.3, 3.5);
    final reviews = reps.clamp(1, 1000000);
    final lapses = n('lapses').clamp(0, reviews);
    final ivl = n('ivl');
    var interval = 0.0, due = now, last = now;
    if (type == 2 && ivl > 0 && queue != 1 && queue != 3) {
      interval = math.min(ivl, 36500).toDouble();
      final odid = n('odid'), odue = n('odue');
      final day = odid != 0 && odue != 0 ? odue : n('due');
      final at = DateTime.fromMillisecondsSinceEpoch(
        (crt + day * 86400) * 1000,
        isUtc: true,
      );
      if (crt > 0 && at.year >= 2000 && at.year <= 9999) due = at;
      last = due.subtract(Duration(minutes: (interval * 1440).round()));
      if (last.isAfter(now)) last = now;
    } else if (type == 3 && ivl > 0) {
      interval = math.min(ivl, 36500).toDouble();
    }
    return {
      'intervalDays': interval,
      'ease': ease,
      'reviewCount': reviews,
      'lapses': lapses,
      'dueAt': _iso(due),
      'lastReviewedAt': _iso(last),
    };
  }
}

class _Draft {
  final Map<String, Object?> row;
  final String front, back;
  final List<String> frontImages, backImages;
  final int cloze;
  final bool reversed;
  const _Draft(
    this.row,
    this.front,
    this.back,
    this.frontImages,
    this.backImages,
    this.cloze, {
    this.reversed = false,
  });
}
