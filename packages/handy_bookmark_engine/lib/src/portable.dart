import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:handy_core/portable_zip.dart';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' show Element;
import 'duplicates.dart';
import 'models.dart';
import 'reading.dart';
import 'urls.dart';

enum SaveFormat { json, csv, html, txt, markdown, zip }

enum ImportStrategy { merge, replace }

String _key(Bookmark b) => sameItemKey(b);

/// A committed import: the next library, and the reading copies to store
/// under the bookmark ids they ended up with.
/// A picture's bytes in a backup: the original exactly as saved, and its
/// preview.
class PortablePicture {
  final Uint8List original, preview;
  const PortablePicture(this.original, this.preview);
}

class ImportResult {
  final SaveLibrary library;
  final Map<String, ReadingCopy> readingCopies;

  /// Pictures to store before the library, keyed by their id.
  final Map<String, PortablePicture> pictures;
  const ImportResult(
    this.library, [
    this.readingCopies = const {},
    this.pictures = const {},
  ]);
}

class ImportPreview {
  final SaveLibrary library;
  final int duplicateCount, invalidCount;
  final List<String> warnings;

  /// Offline reading copies carried by a full backup, keyed by the ids in
  /// [library]. Copies that failed validation are counted in [invalidCopies].
  final Map<String, ReadingCopy> readingCopies;
  final int invalidCopies;

  /// Pictures a ZIP backup carried, each checked against its content id.
  final Map<String, PortablePicture> pictures;

  /// Pictures that failed their check, and pictures items use that the file
  /// does not hold (an older or partial backup).
  final int invalidPictures, missingPictures;
  const ImportPreview({
    required this.library,
    required this.duplicateCount,
    required this.invalidCount,
    this.warnings = const [],
    this.readingCopies = const {},
    this.invalidCopies = 0,
    this.pictures = const {},
    this.invalidPictures = 0,
    this.missingPictures = 0,
  });

  ImportPreview withPictures(
    Map<String, PortablePicture> pictures, {
    int invalid = 0,
  }) {
    final used = {
      for (final b in [...library.bookmarks, ...library.trash])
        if (b.media != null) b.media!.id,
    };
    return ImportPreview(
      library: library,
      duplicateCount: duplicateCount,
      invalidCount: invalidCount,
      warnings: warnings,
      readingCopies: readingCopies,
      invalidCopies: invalidCopies,
      pictures: {
        for (final e in pictures.entries)
          if (used.contains(e.key)) e.key: e.value,
      },
      invalidPictures: invalid,
      missingPictures: used.where((id) => !pictures.containsKey(id)).length,
    );
  }

  int get validCount => library.bookmarks.length;

  /// The links a merge into [current] would add (not already saved, not
  /// repeated within the file), in file order.
  List<Bookmark> fresh(SaveLibrary current) {
    final known = current.bookmarks.map(_key).toSet();
    return [
      for (final b in library.bookmarks)
        if (known.add(_key(b))) b,
    ];
  }

  /// Creates a new immutable snapshot. No storage is mutated during preview or commit.
  SaveLibrary commit(
    SaveLibrary current, {
    ImportStrategy strategy = ImportStrategy.merge,
    bool cancelled = false,
  }) => apply(current, strategy: strategy, cancelled: cancelled).library;

  /// [commit], plus the reading copies re-keyed to the merged ids. Copies of
  /// links skipped as duplicates are left out.
  ImportResult apply(
    SaveLibrary current, {
    ImportStrategy strategy = ImportStrategy.merge,
    bool cancelled = false,
  }) {
    if (cancelled) return ImportResult(current);
    if (strategy == ImportStrategy.replace)
      return ImportResult(library, readingCopies, pictures);
    final added = <String, String>{};
    final collections = current.collections.toList(),
        bookmarks = current.bookmarks.toList(),
        smart = current.smartCollections.toList(),
        searches = current.savedSearches.toList();
    String available(String id, Set<String> used) {
      var next = id;
      var i = 1;
      while (used.contains(next)) {
        next = '${id}_import${i++}';
      }
      used.add(next);
      return next;
    }

    final collectionIds = current.collections.map((e) => e.id).toSet(),
        remap = <String, String>{};
    for (final c in library.collections) {
      remap[c.id] = available(c.id, collectionIds);
    }
    for (final c in library.collections) {
      collections.add(
        c.copyWith(
          id: remap[c.id],
          parentId: c.parentId == null ? null : remap[c.parentId],
        ),
      );
    }
    final urls = current.bookmarks.map(_key).toSet(),
        ids = current.bookmarks.map((b) => b.id).toSet();
    for (final b in library.bookmarks) {
      if (urls.add(_key(b))) {
        final id = available(b.id, ids);
        added[b.id] = id;
        bookmarks.add(
          b.copyWith(
            id: id,
            collectionId: b.collectionId == null ? null : remap[b.collectionId],
          ),
        );
      }
    }
    final smartIds = smart.map((e) => e.id).toSet();
    for (final s in library.smartCollections) {
      smart.add(
        s.copyWith(
          id: available(s.id, smartIds),
          rules: s.rules
              .map(
                (r) => r.field == 'collectionId' && remap.containsKey(r.value)
                    ? r.copyWith(value: remap[r.value])
                    : r,
              )
              .toList(),
        ),
      );
    }
    final searchIds = searches.map((e) => e.id).toSet();
    for (final s in library.savedSearches) {
      final q = Map<String, dynamic>.from(s.query);
      if (remap.containsKey(q['collectionId']))
        q['collectionId'] = remap[q['collectionId']];
      searches.add(s.copyWith(id: available(s.id, searchIds), query: q));
    }
    // Keep the current order; an imported order follows it.
    final order = library.manualOrder.isEmpty
        ? current.manualOrder
        : [
            ...current.fullManualOrder(),
            for (final id in library.manualOrder)
              if (added.containsKey(id)) added[id]!,
          ];
    final addedMedia = {
      for (final b in bookmarks)
        if (added.containsValue(b.id) && b.media != null) b.media!.id,
    };
    return ImportResult(
      SaveLibrary(
        tags: {...current.tags, ...library.tags}.toList(),
        bookmarks: bookmarks,
        collections: collections,
        smartCollections: smart,
        savedSearches: searches,
        manualOrder: order,
        // A merge adds; it never empties the person's Recently Deleted.
        trash: current.trash,
        tombstones: current.tombstones,
      ),
      {
        for (final e in readingCopies.entries)
          if (added.containsKey(e.key)) added[e.key]!: e.value,
      },
      {
        for (final e in pictures.entries)
          if (addedMedia.contains(e.key)) e.key: e.value,
      },
    );
  }
}

/// Bytes of an export and how much of the person's material fit its budget.
class PortableExport {
  final Uint8List bytes;
  final int readingIncluded, readingOmitted;

  /// Pictures written into a ZIP, left out for space, and used by items but
  /// not available to export (missing on this device).
  final int picturesIncluded, picturesOmitted, picturesMissing;
  final int omittedPictureBytes;
  const PortableExport(
    this.bytes,
    this.readingIncluded,
    this.readingOmitted, {
    this.picturesIncluded = 0,
    this.picturesOmitted = 0,
    this.picturesMissing = 0,
    this.omittedPictureBytes = 0,
  });

  /// Everything the library holds is in the file.
  bool get complete =>
      readingOmitted == 0 && picturesOmitted == 0 && picturesMissing == 0;
}

class SavePortable {
  /// The ZIP reader has the same 30 MB aggregate ceiling. No bookmark count cap.
  static const maxImportBytes = 30000000;

  /// A ZIP backup with pictures may grow to this; the library and reading
  /// copies inside it still keep the 30 MB budget.
  static const maxBackupBytes = 256 * 1024 * 1024;

  static final _picturePath = RegExp(
    r'^media/([0-9a-f]{64})(\.preview\.jpg|\.(jpg|png|webp))$',
  );
  static const _marker = 'HANDY_BOOKMARK_V1:';

  /// Exports [library]. Full backups (JSON, ZIP) also carry [readingCopies]
  /// as far as the 30 MB budget allows; see [exportWithReport].
  static Uint8List export(
    SaveLibrary library,
    SaveFormat format, {
    Map<String, ReadingCopy> readingCopies = const {},
    Map<String, PortablePicture> pictures = const {},
  }) => exportWithReport(
    library,
    format,
    readingCopies: readingCopies,
    pictures: pictures,
  ).bytes;

  /// Reading copies that fit next to the library inside [budget] bytes,
  /// newest first; a copy too large to fit is skipped, smaller ones still go.
  static Map<String, Map<String, dynamic>> _fitCopies(
    SaveLibrary library,
    Map<String, ReadingCopy> copies,
    int budget,
  ) {
    final ids = {for (final b in library.bookmarks) b.id};
    final entries = copies.entries.where((e) => ids.contains(e.key)).toList()
      ..sort((a, b) => b.value.savedAt.compareTo(a.value.savedAt));
    final chosen = <String, Map<String, dynamic>>{};
    var used = 0;
    for (final e in entries) {
      final json = e.value.toJson();
      final cost =
          utf8.encode(jsonEncode(json)).length +
          utf8.encode(jsonEncode(e.key)).length +
          2;
      if (used + cost > budget) continue;
      used += cost;
      chosen[e.key] = json;
    }
    return chosen;
  }

  static PortableExport exportWithReport(
    SaveLibrary library,
    SaveFormat format, {
    Map<String, ReadingCopy> readingCopies = const {},

    /// The bytes of the pictures items use (ZIP only).
    Map<String, PortablePicture> pictures = const {},
  }) {
    library.validate();
    final libraryJson = library.toJson();
    var json = jsonEncode(libraryJson);
    final payload = base64Url.encode(utf8.encode(json));
    final ids = {for (final b in library.bookmarks) b.id};
    final offered = readingCopies.keys.where(ids.contains).length;
    var copies = const <String, Map<String, dynamic>>{};
    if (offered > 0 &&
        (format == SaveFormat.json || format == SaveFormat.zip)) {
      final base = utf8.encode(json).length;
      copies = _fitCopies(
        library,
        readingCopies,
        (format == SaveFormat.zip ? maxImportBytes - 8192 : maxImportBytes) -
            base -
            64,
      );
      if (format == SaveFormat.json && copies.isNotEmpty)
        json = jsonEncode({...libraryJson, 'readingCopies': copies});
    }
    PortableExport report(Uint8List bytes) =>
        PortableExport(bytes, copies.length, offered - copies.length);
    String escape(String s) =>
        const HtmlEscape(HtmlEscapeMode.attribute).convert(s);
    final text = switch (format) {
      SaveFormat.json => json,
      SaveFormat.csv => _csvEncode([
        [
          'url',
          'title',
          'description',
          'tags',
          'note',
          'collection',
          'handy_bookmark_data',
        ],
        [
          '',
          '',
          '',
          '',
          '',
          '',
          jsonEncode({...library.toJson(), 'bookmarks': []}),
        ],
        for (final b in library.bookmarks)
          [
            b.originalUrl,
            b.title,
            b.description ?? '',
            b.tags.join(';'),
            b.note,
            b.collectionId ?? '',
            jsonEncode(b.toJson()),
          ],
      ]),
      SaveFormat.html =>
        '<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">\n<!-- $_marker$payload -->\n<TITLE>Handy Bookmark</TITLE>\n<H1>Handy Bookmark</H1>\n${_netscapeTree(library, escape)}',
      SaveFormat.txt =>
        '# $_marker$payload\n${library.bookmarks.where((b) => b.hasUrl).map((b) => b.originalUrl).join('\n')}\n',
      SaveFormat.markdown =>
        '<!-- $_marker$payload -->\n# Handy Bookmark\n\n${library.bookmarks.where((b) => b.hasUrl).map((b) => '- [${(b.title.isEmpty ? b.sourceDomain : b.title).replaceAll(']', '\\]').replaceAll('[', '\\[').replaceAll('\n', ' ')}](<${b.originalUrl.replaceAll('>', '%3E')}>)').join('\n')}\n',
      SaveFormat.zip => '',
    };
    if (format != SaveFormat.zip) {
      final bytes = Uint8List.fromList(utf8.encode(text));
      if (bytes.length > maxImportBytes)
        throw const FormatException('Export exceeds 30 MB portable limit');
      return report(bytes);
    }
    final files = <String, List<int>>{
      'library.json': utf8.encode(json),
      if (copies.isNotEmpty) 'reading.json': utf8.encode(jsonEncode(copies)),
    };
    final total = files.values.fold<int>(0, (n, f) => n + f.length);
    if (total > maxImportBytes - 4096)
      throw const FormatException('Export exceeds 30 MB ZIP expansion limit');
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'handy-save-zip',
        'version': 2,
        'files': {
          for (final f in files.entries)
            f.key: {
              'sha256': sha256.convert(f.value).toString(),
              'bytes': f.value.length,
            },
        },
      }),
    );
    // Pictures: those items (and Trash items) use, newest item first, until
    // the backup budget is reached. What does not fit is counted, never
    // dropped silently.
    final wanted = <MediaRef>[];
    final seen = <String>{};
    for (final b in [
      ...library.bookmarks,
      ...library.trash,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt))) {
      if (b.media != null && seen.add(b.media!.id)) wanted.add(b.media!);
    }
    final media = <String, Map<String, dynamic>>{};
    final mediaFiles = <String, List<int>>{};
    var mediaBytes = 0, omitted = 0, omittedBytes = 0, missing = 0;
    final room = maxBackupBytes - total - 64 * 1024;
    for (final ref in wanted) {
      final pic = pictures[ref.id];
      if (pic == null) {
        missing++;
        continue;
      }
      final cost = pic.original.length + pic.preview.length + 512;
      if (mediaBytes + cost > room) {
        omitted++;
        omittedBytes += pic.original.length;
        continue;
      }
      mediaBytes += cost;
      final original = 'media/${ref.id}.${ref.extension}';
      final preview = 'media/${ref.id}.preview.jpg';
      mediaFiles[original] = pic.original;
      mediaFiles[preview] = pic.preview;
      media[ref.id] = {
        'original': original,
        'bytes': pic.original.length,
        'preview': preview,
        'previewSha256': sha256.convert(pic.preview).toString(),
        'previewBytes': pic.preview.length,
      };
    }
    final withMedia = mediaFiles.isEmpty
        ? manifest
        : utf8.encode(
            jsonEncode({
              ...jsonDecode(utf8.decode(manifest)) as Map,
              'version': 3,
              'media': media,
            }),
          );
    final archive = Archive()
      ..addFile(ArchiveFile('manifest.json', withMedia.length, withMedia));
    for (final f in files.entries) {
      archive.addFile(ArchiveFile(f.key, f.value.length, f.value));
    }
    for (final f in mediaFiles.entries) {
      archive.addFile(ArchiveFile(f.key, f.value.length, f.value));
    }
    // Stored entries avoid compression-ratio rejections for large repetitive libraries.
    final encoded = ZipEncoder().encode(archive, level: 0);
    if (encoded.length > (mediaFiles.isEmpty ? maxImportBytes : maxBackupBytes))
      throw const FormatException('ZIP exceeds its portable limit');
    return PortableExport(
      Uint8List.fromList(encoded),
      copies.length,
      offered - copies.length,
      picturesIncluded: media.length,
      picturesOmitted: omitted,
      picturesMissing: missing,
      omittedPictureBytes: omittedBytes,
    );
  }

  static String _netscapeTree(
    SaveLibrary library,
    String Function(String) escape,
  ) {
    final byId = {for (final c in library.collections) c.id: c};
    final folders = <String?, List<SaveCollection>>{},
        links = <String?, List<Bookmark>>{};
    for (final c in library.collections) {
      (folders[c.parentId] ??= []).add(c);
    }
    for (final b in library.bookmarks) {
      (links[b.collectionId] ??= []).add(b);
    }
    for (final list in folders.values) {
      list.sort((a, b) => a.position.compareTo(b.position));
    }
    final out = StringBuffer(), stack = <(String?, bool)>[(null, false)];
    while (stack.isNotEmpty) {
      final (id, close) = stack.removeLast();
      if (close) {
        out.writeln('</DL><p>');
        continue;
      }
      if (id != null) {
        final c = byId[id]!;
        out.writeln('<DT><H3>${escape(c.name)}</H3>');
      }
      out.writeln('<DL><p>');
      for (final b in links[id] ?? <Bookmark>[]) {
        // A picture without an address has no link to list; the Handy
        // payload above still carries it.
        if (!b.hasUrl) continue;
        out.writeln(
          '<DT><A HREF="${escape(b.originalUrl)}" ADD_DATE="${DateTime.parse(b.savedAt).millisecondsSinceEpoch ~/ 1000}" TAGS="${escape(b.tags.join(','))}">${escape(b.title.isEmpty ? b.originalUrl : b.title)}</A>',
        );
        if (b.note.isNotEmpty) out.writeln('<DD>${escape(b.note)}');
      }
      stack.add((id, true));
      for (final c in (folders[id] ?? <SaveCollection>[]).reversed) {
        stack.add((c.id, false));
      }
    }
    return out.toString();
  }

  static ImportPreview preview(
    Uint8List bytes,
    SaveFormat format, {
    SaveLibrary? current,
  }) {
    if (bytes.length >
        (format == SaveFormat.zip ? maxBackupBytes : maxImportBytes))
      throw const FormatException('Import exceeds its byte limit');
    if (bytes.isEmpty) throw const FormatException('Import is empty');
    if (format == SaveFormat.zip) {
      final files = decodeBackupZip(
        bytes,
        isAllowedPath: (p) =>
            {'manifest.json', 'library.json', 'reading.json'}.contains(p) ||
            _picturePath.hasMatch(p),
        maxEntries: 3 + 2 * 20000,
        maxEntryBytes: maxImportBytes,
        maxTotalBytes: maxBackupBytes,
      );
      var textBytes = 0;
      for (final e in files.entries) {
        if (_picturePath.hasMatch(e.key)) {
          if (e.value.length > MediaRef.maxBytes)
            throw const FormatException('ZIP picture exceeds 25 MB');
        } else {
          textBytes += e.value.length;
        }
      }
      // The library and its reading copies keep their 30 MB budget.
      if (textBytes > maxImportBytes)
        throw const FormatException('ZIP library exceeds 30 MB');
      if (!files.containsKey('manifest.json') ||
          !files.containsKey('library.json'))
        throw const FormatException('Missing ZIP manifest or library');
      final manifest = _object(
        jsonDecode(utf8.decode(files['manifest.json']!)),
      );
      final version = manifest['version'];
      if (manifest['format'] != 'handy-save-zip' ||
          !{1, 2, 3}.contains(version))
        throw const FormatException('Unsupported ZIP manifest');
      final entries = _object(manifest['files']);
      final media = manifest['media'] == null
          ? <String, dynamic>{}
          : _object(manifest['media']);
      if (version != 3 && media.isNotEmpty)
        throw const FormatException('Unexpected ZIP pictures');
      final pictureFiles = files.keys.where(_picturePath.hasMatch).length;
      // Version 1 holds only the library; 2 may add reading copies; 3 may
      // add pictures (an original and a preview each).
      if (!entries.containsKey('library.json') ||
          (version == 1 && entries.length != 1) ||
          entries.keys.any((k) => k != 'library.json' && k != 'reading.json') ||
          files.length != entries.length + 1 + pictureFiles ||
          pictureFiles != media.length * 2)
        throw const FormatException('Unexpected ZIP manifest entries');
      for (final name in entries.keys) {
        final info = _object(entries[name]), data = files[name]!;
        if (info['bytes'] != data.length ||
            info['sha256'] != sha256.convert(data).toString())
          throw const FormatException('ZIP digest mismatch');
      }
      // Each picture must be exactly what its id names.
      final pictures = <String, PortablePicture>{};
      var invalidPictures = 0;
      for (final e in media.entries) {
        try {
          final info = _object(e.value);
          final original = files[info['original']];
          final preview = files[info['preview']];
          if (original == null ||
              preview == null ||
              original.length != info['bytes'] ||
              sha256.convert(original).toString() != e.key ||
              preview.length != info['previewBytes'] ||
              sha256.convert(preview).toString() != info['previewSha256'])
            throw const FormatException('Picture does not match its id');
          pictures[e.key] = PortablePicture(original, preview);
        } on FormatException {
          invalidPictures++;
        } on TypeError {
          invalidPictures++;
        }
      }
      return _jsonPreview(
        _object(jsonDecode(utf8.decode(files['library.json']!))),
        current,
        reading: files['reading.json'] == null
            ? null
            : jsonDecode(utf8.decode(files['reading.json']!)),
      ).withPictures(pictures, invalid: invalidPictures);
    }
    final text = utf8
        .decode(bytes, allowMalformed: false)
        .replaceFirst(RegExp('^\uFEFF'), '');
    if (format == SaveFormat.json)
      return _jsonPreview(
        _object(jsonDecode(text)),
        current,
      ).withPictures(const {});
    if (format == SaveFormat.csv)
      return _csvPreview(text, current).withPictures(const {});
    final embedded = RegExp('$_marker([A-Za-z0-9_=-]+)').firstMatch(text);
    if (embedded != null) {
      try {
        return _jsonPreview(
          _object(
            jsonDecode(utf8.decode(base64Url.decode(embedded.group(1)!))),
          ),
          current,
        ).withPictures(const {});
      } on FormatException {
        throw const FormatException('Corrupted Handy Bookmark metadata');
      }
    }
    if (text.contains(_marker))
      throw const FormatException('Corrupted Handy Bookmark metadata');
    return format == SaveFormat.html
        ? _htmlPreview(text, current)
        : _linksPreview(text, current, markdown: format == SaveFormat.markdown);
  }

  /// Name of the collection Pocket links are filed into.
  static const pocketCollection = 'Pocket';

  /// Reads a Pocket export. Pocket shut down in 2025; its last export was a
  /// CSV (`title,url,time_added,tags,status`, tags `|`-separated, status
  /// `unread` or `archive`); older ones were `ril_export.html` with an Unread
  /// and a Read Archive list. Archived items arrive archived and read,
  /// `time_added` becomes the saved date, tags stay tags, and every link is
  /// filed in a new "Pocket" collection. The preview runs through the same
  /// duplicate count and merge as every other import.
  static ImportPreview previewPocket(Uint8List bytes, {SaveLibrary? current}) {
    if (bytes.length > maxImportBytes)
      throw const FormatException('Import exceeds 30 MB byte limit');
    if (bytes.isEmpty) throw const FormatException('Import is empty');
    final text = utf8
        .decode(bytes, allowMalformed: false)
        .replaceFirst(RegExp('^﻿'), '');
    final items =
        <
          ({String url, String title, List<String> tags, String? at, bool done})
        >[];
    var invalid = 0;
    String? when(String raw) {
      final n = int.tryParse(raw.trim());
      if (n == null || n <= 0) return null;
      try {
        return DateTime.fromMillisecondsSinceEpoch(
          n > 100000000000 ? n : n * 1000,
          isUtc: true,
        ).toIso8601String();
      } on ArgumentError {
        return null;
      }
    }

    List<String> tagList(String raw, Pattern by) => {
      for (final t in raw.split(by))
        if (t.trim().isNotEmpty) t.trim(),
    }.toList();
    if (text.trimLeft().startsWith('<')) {
      final document = html.parse(text);
      var archived = false;
      // Headings and links in document order: a heading starts a list.
      for (final e in document.querySelectorAll('h1, h2, a')) {
        if (e.localName != 'a') {
          archived = e.text.toLowerCase().contains('archive');
          continue;
        }
        final href = e.attributes['href'];
        if (href == null || href.trim().isEmpty) {
          invalid++;
          continue;
        }
        items.add((
          url: href.trim(),
          title: e.text.trim(),
          tags: tagList(e.attributes['tags'] ?? '', ','),
          at: when(e.attributes['time_added'] ?? ''),
          done: archived,
        ));
      }
    } else {
      final rows = _csvDecode(text);
      if (rows.isEmpty) throw const FormatException('CSV is empty');
      final headers = rows.first.map((h) => h.trim().toLowerCase()).toList();
      final url = headers.indexOf('url');
      if (url < 0 ||
          !(headers.contains('time_added') || headers.contains('status')))
        throw const FormatException('This is not a Pocket export');
      for (final row in rows.skip(1)) {
        if (row.every((c) => c.trim().isEmpty)) continue;
        if (row.length != headers.length) {
          invalid++;
          continue;
        }
        String get(String key) {
          final i = headers.indexOf(key);
          return i < 0 ? '' : row[i];
        }

        items.add((
          url: row[url].trim(),
          title: get('title').trim(),
          tags: tagList(get('tags'), '|'),
          at: when(get('time_added')),
          done: get('status').trim().toLowerCase() == 'archive',
        ));
      }
    }
    if (items.isEmpty && invalid == 0)
      throw const FormatException('No Pocket links found');
    final bookmarks = <Bookmark>[];
    for (final item in items) {
      try {
        var title = item.title == item.url ? '' : item.title;
        if (title.length > 2048) title = title.substring(0, 2048);
        bookmarks.add(
          _bookmark(
            item.url,
            bookmarks.length,
            title: title,
            tags: item.tags,
            collectionId: 'pocket',
            savedAt: item.at,
          ).copyWith(isArchived: item.done, isRead: item.done),
        );
      } on FormatException {
        invalid++;
      }
    }
    return _preview(
      SaveLibrary(
        bookmarks: bookmarks,
        collections: [
          if (bookmarks.isNotEmpty)
            SaveCollection(id: 'pocket', name: pocketCollection),
        ],
      ),
      current,
      invalid,
    );
  }

  /// Reads a Raindrop.io export. Its CSV
  /// (`id,title,note,excerpt,url,folder,tags,created,cover,highlights,favorite`)
  /// keeps folders as collections (`Parent/Child` becomes a nested pair,
  /// Unsorted stays Not sorted), tags (comma-separated), the note, the
  /// excerpt as the description, highlights after the note, the created
  /// date and favourites. Covers are not fetched. Its HTML export is a
  /// browser bookmarks file and reads like one, folders included.
  static ImportPreview previewRaindrop(
    Uint8List bytes, {
    SaveLibrary? current,
  }) {
    if (bytes.length > maxImportBytes)
      throw const FormatException('Import exceeds 30 MB byte limit');
    if (bytes.isEmpty) throw const FormatException('Import is empty');
    final text = utf8
        .decode(bytes, allowMalformed: false)
        .replaceFirst(RegExp('^\uFEFF'), '');
    if (text.trimLeft().startsWith('<'))
      return preview(bytes, SaveFormat.html, current: current);
    final rows = _csvDecode(text);
    if (rows.isEmpty) throw const FormatException('CSV is empty');
    final headers = rows.first.map((h) => h.trim().toLowerCase()).toList();
    if (!headers.contains('url') ||
        !headers.contains('folder') ||
        !(headers.contains('excerpt') || headers.contains('highlights')))
      throw const FormatException('This is not a Raindrop export');
    final collections = <String, SaveCollection>{};
    String? folder(String raw) {
      final parts = [
        for (final p in raw.split('/'))
          if (p.trim().isNotEmpty) p.trim(),
      ];
      if (parts.isEmpty || (parts.length == 1 && parts.single == 'Unsorted'))
        return null;
      String? parent;
      for (var i = 0; i < parts.length; i++) {
        final path = parts.take(i + 1).join('/');
        final made = collections[path] ??= SaveCollection(
          id: 'raindrop_${collections.length}',
          name: parts[i].length > 512 ? parts[i].substring(0, 512) : parts[i],
          parentId: parent,
          position: collections.length,
        );
        parent = made.id;
      }
      return parent;
    }

    String? when(String raw) {
      final t = DateTime.tryParse(raw.trim());
      return t?.toUtc().toIso8601String();
    }

    var invalid = 0;
    final bookmarks = <Bookmark>[];
    for (final row in rows.skip(1)) {
      if (row.every((c) => c.trim().isEmpty)) continue;
      if (row.length != headers.length) {
        invalid++;
        continue;
      }
      String get(String key) {
        final i = headers.indexOf(key);
        return i < 0 ? '' : row[i].trim();
      }

      try {
        var title = get('title');
        if (title == get('url')) title = '';
        if (title.length > 2048) title = title.substring(0, 2048);
        final highlights = get('highlights');
        var note = [
          get('note'),
          if (highlights.isNotEmpty) highlights,
        ].where((s) => s.isNotEmpty).join('\n\n');
        if (note.length > 60000) note = note.substring(0, 60000);
        var excerpt = get('excerpt');
        if (excerpt.length > 4000) excerpt = excerpt.substring(0, 4000);
        final b = _bookmark(
          get('url'),
          bookmarks.length,
          title: title,
          note: note,
          tags: {
            for (final t in get('tags').split(','))
              if (t.trim().isNotEmpty) t.trim(),
          }.toList(),
          collectionId: folder(get('folder')),
          savedAt: when(get('created')),
        );
        bookmarks.add(
          b.copyWith(
            description: excerpt.isEmpty ? null : excerpt,
            isFavorite: get('favorite').toLowerCase() == 'true',
          ),
        );
      } on FormatException {
        invalid++;
      }
    }
    if (bookmarks.isEmpty && invalid == 0)
      throw const FormatException('No Raindrop links found');
    final used = {for (final b in bookmarks) b.collectionId};
    // A parent stays when any child holds a link.
    final keep = <String>{};
    for (final c in collections.values) {
      if (!used.contains(c.id)) continue;
      String? at = c.id;
      while (at != null && keep.add(at)) {
        at = collections.values.firstWhere((x) => x.id == at).parentId;
      }
    }
    return _preview(
      SaveLibrary(
        bookmarks: bookmarks,
        collections: [
          for (final c in collections.values)
            if (keep.contains(c.id)) c,
        ],
      ),
      current,
      invalid,
    );
  }

  static Map<String, dynamic> _object(dynamic value) {
    if (value is! Map) throw const FormatException('Expected JSON object');
    return Map<String, dynamic>.from(value);
  }

  static ImportPreview _jsonPreview(
    Map<String, dynamic> json,
    SaveLibrary? current, {
    Object? reading,
  }) {
    if (!{1, 2, SaveLibrary.version}.contains(json['version']) ||
        json['format'] != 'handy-save')
      throw const FormatException('Unsupported Handy Bookmark format');
    final values = json['bookmarks'];
    if (values is! List) throw const FormatException('Missing bookmarks array');
    var invalid = 0;
    final bookmarks = <Bookmark>[];
    for (final value in values) {
      try {
        bookmarks.add(Bookmark.fromJson(_object(value)));
      } on FormatException {
        invalid++;
      } on TypeError {
        invalid++;
      }
    }
    final library = SaveLibrary.fromJson({
      ...json,
      'bookmarks': bookmarks.map((e) => e.toJson()).toList(),
    });
    final raw = reading ?? json['readingCopies'];
    final copies = <String, ReadingCopy>{};
    var invalidCopies = 0;
    if (raw != null) {
      if (raw is! Map) throw const FormatException('Invalid reading copies');
      final ids = {for (final b in library.bookmarks) b.id};
      for (final e in raw.entries) {
        try {
          if (e.key is! String || !ids.contains(e.key) || e.value is! Map)
            throw const FormatException('Orphan reading copy');
          copies[e.key as String] = ReadingCopy.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          );
        } on FormatException {
          invalidCopies++;
        } on TypeError {
          invalidCopies++;
        }
      }
    }
    final p = _preview(library, current, invalid);
    return ImportPreview(
      library: p.library,
      duplicateCount: p.duplicateCount,
      invalidCount: p.invalidCount,
      readingCopies: copies,
      invalidCopies: invalidCopies,
    );
  }

  static ImportPreview _preview(
    SaveLibrary library,
    SaveLibrary? current,
    int invalid,
  ) {
    final known = current?.bookmarks.map(_key).toSet() ?? <String>{};
    var duplicates = 0;
    for (final b in library.bookmarks) {
      if (!known.add(_key(b))) duplicates++;
    }
    return ImportPreview(
      library: library,
      duplicateCount: duplicates,
      invalidCount: invalid,
    );
  }

  static Bookmark _bookmark(
    String url,
    int index, {
    String title = '',
    String note = '',
    List<String> tags = const [],
    String? collectionId,
    String? savedAt,
  }) {
    final u = UrlTools.normalize(url),
        now = DateTime.now().toUtc().toIso8601String();
    return Bookmark(
      id: 'import_$index',
      originalUrl: u.originalUrl,
      normalizedUrl: u.normalizedUrl,
      canonicalUrl: u.canonicalUrl,
      platform: u.platform,
      contentType: u.contentType,
      title: title,
      sourceDomain: u.sourceDomain,
      note: note,
      tags: tags,
      collectionId: collectionId,
      savedAt: savedAt ?? now,
      updatedAt: now,
    );
  }

  static ImportPreview _linksPreview(
    String text,
    SaveLibrary? current, {
    bool markdown = false,
  }) {
    final bookmarks = <Bookmark>[];
    var invalid = 0;
    if (markdown) {
      final matches = RegExp(
        r'\[([^\]\n]*)\]\(<?(https?://[^\s>]+)>?\)',
        caseSensitive: false,
      ).allMatches(text);
      for (final match in matches) {
        try {
          bookmarks.add(
            _bookmark(
              match.group(2)!,
              bookmarks.length,
              title: match.group(1)!,
            ),
          );
        } on FormatException {
          invalid++;
        }
      }
    }
    if (bookmarks.isEmpty) {
      for (final line in const LineSplitter().convert(text)) {
        if (line.trimLeft().startsWith('#')) continue;
        if (utf8.encode(line).length > UrlTools.maxInputBytes) {
          invalid++;
          continue;
        }
        final urls = UrlTools.extract(line);
        if (urls.isEmpty && line.trim().isNotEmpty) invalid++;
        for (final u in urls) {
          try {
            bookmarks.add(_bookmark(u.originalUrl, bookmarks.length));
          } on FormatException {
            invalid++;
          }
        }
      }
    }
    return _preview(SaveLibrary(bookmarks: bookmarks), current, invalid);
  }

  static ImportPreview _htmlPreview(String text, SaveLibrary? current) {
    final document = html.parse(text),
        bookmarks = <Bookmark>[],
        collections = <SaveCollection>[];
    var invalid = 0;
    String? walk(Element element, String? parent) {
      String? active = parent;
      String? declared;
      for (final child in element.children) {
        if (child.localName == 'h3') {
          final id = 'folder_${collections.length}';
          collections.add(
            SaveCollection(
              id: id,
              name: child.text.trim().isEmpty
                  ? 'Imported folder'
                  : child.text.trim(),
              parentId: parent,
            ),
          );
          active = id;
          declared ??= id;
        } else if (child.localName == 'a') {
          try {
            final epoch = int.tryParse(child.attributes['add_date'] ?? '');
            bookmarks.add(
              _bookmark(
                child.attributes['href'] ?? '',
                bookmarks.length,
                title: child.text,
                note: child.parent?.nextElementSibling?.localName == 'dd'
                    ? child.parent!.nextElementSibling!.text
                    : '',
                tags: (child.attributes['tags'] ?? '')
                    .toString()
                    .split(',')
                    .where((String e) => e.trim().isNotEmpty)
                    .map((String e) => e.trim())
                    .toList(),
                collectionId: parent,
                savedAt: epoch == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(
                        epoch * 1000,
                        isUtc: true,
                      ).toIso8601String(),
              ),
            );
          } on FormatException {
            invalid++;
          } on RangeError {
            invalid++;
          }
        } else if (child.localName == 'dl') {
          walk(child, active);
        } else {
          final heading = walk(child, parent);
          if (child.localName == 'dt') {
            if (heading != null) active = heading;
          }
        }
      }
      return declared;
    }

    walk(document.documentElement!, null);
    return _preview(
      SaveLibrary(bookmarks: bookmarks, collections: collections),
      current,
      invalid,
    );
  }

  static String _csvEncode(List<List<String>> rows) => rows
      .map(
        (row) => row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','),
      )
      .join('\r\n');
  static List<List<String>> _csvDecode(String text) {
    final rows = <List<String>>[];
    var row = <String>[], cell = StringBuffer(), quoted = false, closed = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          cell.write(c);
        }
        continue;
      }
      if (c == '"') {
        if (cell.isNotEmpty || closed)
          throw const FormatException('Malformed CSV quote');
        quoted = true;
      } else if (c == ',') {
        row.add(cell.toString());
        cell = StringBuffer();
        closed = false;
      } else if (c == '\r' || c == '\n') {
        row.add(cell.toString());
        rows.add(row);
        row = [];
        cell = StringBuffer();
        closed = false;
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      } else {
        if (closed)
          throw const FormatException('Unexpected text after CSV quote');
        cell.write(c);
      }
    }
    if (quoted) throw const FormatException('Unterminated CSV quote');
    if (cell.isNotEmpty || row.isNotEmpty || closed) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  static ImportPreview _csvPreview(String text, SaveLibrary? current) {
    final rows = _csvDecode(text);
    if (rows.isEmpty) throw const FormatException('CSV is empty');
    final headers = rows.first.map((s) => s.trim().toLowerCase()).toList();
    final urlIndex = headers.indexWhere(
      (h) => {'url', 'href', 'link', 'originalurl'}.contains(h),
    );
    if (urlIndex < 0) throw const FormatException('CSV needs URL column');
    var invalid = 0;
    Map<String, dynamic>? metadata;
    final bookmarks = <Bookmark>[],
        collections = <SaveCollection>[],
        folderIds = <String, String>{};
    for (final row in rows.skip(1)) {
      if (row.every((c) => c.isEmpty)) continue;
      String get(String key) {
        final i = headers.indexOf(key);
        return i < 0 || i >= row.length ? '' : row[i];
      }

      try {
        final data = get('handy_bookmark_data');
        if (data.isNotEmpty) {
          final parsed = _object(jsonDecode(data));
          if (parsed['format'] == 'handy-save') {
            if (metadata != null)
              throw const FormatException('Duplicate CSV metadata');
            metadata = parsed;
          } else {
            bookmarks.add(Bookmark.fromJson(parsed));
          }
          continue;
        }
        if (row.length != headers.length || urlIndex >= row.length)
          throw const FormatException('Invalid CSV row length');
        final folder = get('collection').isEmpty
            ? get('folder')
            : get('collection');
        String? collectionId;
        if (folder.isNotEmpty) {
          collectionId = folderIds.putIfAbsent(folder, () {
            final id = 'folder_${folderIds.length}';
            collections.add(SaveCollection(id: id, name: folder));
            return id;
          });
        }
        bookmarks.add(
          _bookmark(
            row[urlIndex],
            bookmarks.length,
            title: get('title'),
            note: get('note'),
            tags: get('tags')
                .split(RegExp('[;,]'))
                .where((e) => e.trim().isNotEmpty)
                .map((e) => e.trim())
                .toList(),
            collectionId: collectionId,
          ),
        );
      } on FormatException {
        invalid++;
      } on TypeError {
        invalid++;
      }
    }
    final library = metadata == null
        ? SaveLibrary(bookmarks: bookmarks, collections: collections)
        : SaveLibrary.fromJson({
            ...metadata,
            'bookmarks': bookmarks.map((e) => e.toJson()).toList(),
          });
    return _preview(library, current, invalid);
  }
}
