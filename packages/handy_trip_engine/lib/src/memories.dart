part of '../handy_trip_engine.dart';

String redactBookingCodes(TripState s, String value) {
  for (final b in s.bookings.where((b) => b.code.isNotEmpty)) {
    value = value.replaceAll(
      RegExp(RegExp.escape(b.code), caseSensitive: false),
      '[private]',
    );
  }
  return value;
}

Json stampData(TripState s, String visitId) {
  final v = s.visits.firstWhere((v) => v.key == visitId);
  if (!v.confirmed)
    throw const FormatException('Only user-confirmed visits have stamps');
  return {
    'place': redactBookingCodes(
      s,
      s.place(v.place).name,
    ).replaceAll(RegExp(r'\s+'), ' ').trim(),
    'day': localDay(DateTime.parse(v.at), v.zone),
    'trip': v.trip == null
        ? ''
        : redactBookingCodes(
            s,
            s.trip(v.trip!).title,
          ).replaceAll(RegExp(r'\s+'), ' ').trim(),
    'label': 'Personal travel memory — not an official document',
  };
}

Json memoryBookData(
  TripState s,
  String tripId, {
  bool privateText = false,
  bool includeMoney = false,
}) {
  final trip = s.trip(tripId),
      visits = s.visits.where((v) => v.trip == tripId && v.confirmed).toList(),
      notes = s.notes.where((n) => n.trip == tripId).toList();
  final days = {
    ...trip.days,
    for (final v in visits) localDay(DateTime.parse(v.at), v.zone),
    for (final n in notes) localDay(DateTime.parse(n.at), n.zone),
  }.toList()..sort();
  return {
    'app': 'handy-trip-memory-book',
    'schema': 1,
    'title': redactBookingCodes(s, trip.title),
    'start': trip.start,
    'end': trip.end,
    'zone': trip.zone,
    'cover': trip.cover,
    'privateText': privateText,
    'includeMoney': includeMoney,
    'visits': visits.length,
    'uniquePlaces': visits.map((v) => v.place).toSet().length,
    if (includeMoney)
      'expenses': expenseTotals(
        s,
        tripId,
      ).map((k, v) => MapEntry(k, v.toString())),
    'days': [
      for (final d in days)
        {
          'day': d,
          'visits': [
            for (final v in visits.where(
              (v) => localDay(DateTime.parse(v.at), v.zone) == d,
            ))
              {
                ...stampData(s, v.key),
                'id': v.key,
                'assets': v.assets,
                if (privateText) 'note': v.note,
              },
          ],
          'notes': [
            for (final n in notes.where(
              (n) => localDay(DateTime.parse(n.at), n.zone) == d,
            ))
              {
                'id': n.key,
                'assets': n.assets,
                if (privateText) 'title': n.title,
                if (privateText) 'body': n.body,
              },
          ],
        },
    ],
  };
}

String _html(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
Uint8List memoryBookZip(
  TripState s,
  String tripId, {
  bool privateText = false,
  bool includeMoney = false,
  String layout = 'daybook',
}) {
  if (!['daybook', 'contact-sheet'].contains(layout))
    throw const FormatException('Unknown memory book layout');
  final book = memoryBookData(
        s,
        tripId,
        privateText: privateText,
        includeMoney: includeMoney,
      ),
      photos = <String, Uint8List>{};
  String photo(String key) {
    final asset = s.assets.firstWhere((a) => a.key == key);
    if (!asset.mime.startsWith('image/')) return '';
    if (photos.length >= 100 && !photos.containsKey(key))
      throw const FormatException('Select at most 100 book photos');
    photos.putIfAbsent(key, () => publicImage(s.files[asset.path]!));
    return '<figure><img src="photos/$key.jpg" alt="Travel photo">${privateText ? '<figcaption>${_html(asset.text('caption'))}</figcaption>' : ''}</figure>';
  }

  final body = StringBuffer(
    '<h1>${_html(book['title'])}</h1><p>${tripId.isEmpty ? '' : _html('${book['start']} — ${book['end']} / ${book['zone']}')}</p><p>${book['visits']} visits · ${book['uniquePlaces']} unique places. User confirmed; not GPS proof.</p>',
  );
  if (book['cover'] != null) body.write(photo(book['cover']));
  for (final d in book['days'] as List) {
    body.write('<section><h2>${d['day']}</h2>');
    for (final v in d['visits'] as List) {
      body.write('<h3>${_html(v['place'])}</h3>');
      if (privateText) body.write('<p>${_html(v['note'])}</p>');
      for (final id in v['assets'] as List) body.write(photo(id));
    }
    for (final n in d['notes'] as List) {
      if (privateText)
        body.write('<h3>${_html(n['title'])}</h3><p>${_html(n['body'])}</p>');
      for (final id in n['assets'] as List) body.write(photo(id));
    }
    body.write('</section>');
  }
  if (includeMoney)
    for (final e in object(book['expenses']).entries)
      body.write(
        '<p>${e.key}: ${amount(minorValue(e.value), e.key)} (separate currency)</p>',
      );
  final html =
      '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; img-src \'self\' file: data:; style-src \'unsafe-inline\'"><title>Handy Trip memory book</title><style>body{max-width:60rem;margin:auto;padding:24px;font-family:system-ui;color:#171717;background:white}section{border-top:1px solid #ddd;padding:16px 0}img{max-width:100%;max-height:600px}figure{margin:16px 0;${layout == 'contact-sheet' ? 'display:inline-block;width:46%;vertical-align:top;' : ''}}p{white-space:pre-wrap}@media(max-width:600px){figure{width:100%}}</style><body><p>${privateText || includeMoney ? 'Private selections included.' : 'Private text and expenses omitted.'} Photos reencoded without EXIF; review visible image content.</p>$body</body></html>';
  final entries = <String, Uint8List>{
    'index.html': Uint8List.fromList(utf8.encode(html)),
    for (final e in photos.entries) 'photos/${e.key}.jpg': e.value,
  };
  if (entries.values.fold<int>(0, (a, b) => a + b.length) >
      portableLimit - 100000)
    throw const FormatException('Book exceeds 30 MB; choose a smaller trip');
  final manifest = utf8.encode(
    jsonEncode({
      'app': 'handy-trip-memory-book',
      'schema': 1,
      'privateText': privateText,
      'includeMoney': includeMoney,
      'layout': layout,
      'files': entries.map(
        (k, v) => MapEntry(k, {
          'size': v.length,
          'sha256': sha256.convert(v).toString(),
        }),
      ),
    }),
  );
  final archive = Archive()
    ..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  for (final e in entries.entries)
    archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
