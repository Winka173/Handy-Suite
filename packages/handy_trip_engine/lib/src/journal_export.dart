part of '../handy_trip_engine.dart';

Json journalDocument(TripState s, {bool privateText = false}) {
  final public = publicDocument(s);
  return {
    'app': 'handy-trip-journal',
    'schema': 1,
    'privateText': privateText,
    'visits': public['visits'],
    'notes': [
      for (final n in s.notes)
        {
          'id': n.key,
          'day': localDay(DateTime.parse(n.at), n.zone),
          if (privateText) 'title': n.title,
          if (privateText) 'body': n.body,
        },
    ],
    if (privateText)
      'visitNotes': [
        for (final v in s.visits)
          {'id': v.key, 'note': v.note, 'rating': v.data['rating']},
      ],
  };
}

String journalMarkdown(TripState s, {bool privateText = false}) {
  String escaped(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('#', r'\#');
  final doc = journalDocument(s, privateText: privateText);
  return '# Handy Trip journal\n\n${privateText ? 'PRIVATE: contains personal journal text.' : 'Public: private text and coordinates omitted.'}\n\n'
      '${(doc['visits'] as List).map((v) => '## ${v['day']} / ${escaped(v['place'])}').join('\n\n')}\n\n'
      '${(doc['notes'] as List).map((n) => '## ${n['day']}\n\n${privateText ? '${escaped(n['title'])}\n\n${escaped(n['body'])}' : ''}').join('\n\n')}';
}

/// Selected journal images only. New filenames and RGB pixels remove EXIF,
/// original names, booking documents, precise positions and private captions.
Uint8List photoAlbum(TripState s) {
  final ids = {
    ...s.visits.expand((v) => v.assets),
    ...s.notes.expand((n) => n.assets),
  };
  if (ids.length > 200)
    throw const FormatException('Select at most 200 album images per file');
  final archive = Archive(), hashes = <String, dynamic>{};
  var count = 0, total = 0;
  for (final a in s.assets.where(
    (a) => ids.contains(a.key) && a.mime.startsWith('image/'),
  )) {
    final clean = publicImage(s.files[a.path]!);
    total += clean.length;
    if (total > portableLimit - 100000)
      throw const FormatException('Album exceeds 30 MB; select a day');
    final name = 'photos/${(++count).toString().padLeft(4, '0')}.jpg';
    archive.addFile(ArchiveFile(name, clean.length, clean));
    hashes[name] = {
      'size': clean.length,
      'sha256': sha256.convert(clean).toString(),
    };
  }
  final manifest = utf8.encode(
    jsonEncode({
      'app': 'handy-trip-photo-album',
      'schema': 1,
      'photos': count,
      'files': hashes,
      'privacy':
          'Reencoded pixels; no EXIF or private captions. Review visible image content before sharing.',
    }),
  );
  archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
