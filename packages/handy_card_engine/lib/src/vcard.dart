part of '../handy_card_engine.dart';

/// [p] as a vCard (RFC 2426 for 3.0, RFC 6350 for 4.0): values escaped,
/// lines folded at 75 octets without splitting a character, CRLF endings.
/// Private values are left out unless [includePrivate].
String vcardFor(
  CardProfile p, {
  String version = '3.0',
  bool includePrivate = false,
}) {
  if (version != '3.0' && version != '4.0')
    throw ArgumentError('vCard 3.0 or 4.0');
  Iterable<ProfileValue> open(List<ProfileValue> l) => l.where(
    (v) => v.value.trim().isNotEmpty && (includePrivate || !v.private),
  );
  String type(String label, String fallback) {
    final t = label.trim().toLowerCase();
    final known = const {
      'home',
      'work',
      'cell',
      'mobile',
      'voice',
      'fax',
      'pager',
      'text',
    };
    final v = known.contains(t) ? (t == 'mobile' ? 'cell' : t) : fallback;
    return version == '4.0' ? 'TYPE=$v' : 'TYPE=${v.toUpperCase()}';
  }

  final name = p.displayName.trim().isEmpty
      ? p.organization.trim()
      : p.displayName.trim();
  final lines = <String>[
    'BEGIN:VCARD',
    'VERSION:$version',
    'FN:${_vEscape(name)}',
    // Vietnamese and many other names do not split cleanly into family and
    // given names; the whole name goes in the given-name slot.
    'N:;${_vEscape(name)};;;',
    if (p.organization.trim().isNotEmpty)
      'ORG:${_vEscape(p.organization.trim())}',
    if (p.role.trim().isNotEmpty) 'TITLE:${_vEscape(p.role.trim())}',
    for (final t in open(p.phones))
      if (telUri(t.value) != null)
        version == '4.0'
            ? 'TEL;${type(t.label, 'voice')};VALUE=uri:${telUri(t.value)}'
            : 'TEL;${type(t.label, 'voice')}:${_vEscape(t.value.trim())}',
    for (final e in open(p.emails))
      if (isEmail(e.value))
        'EMAIL;${type(e.label, 'internet')}:${_vEscape(e.value.trim())}',
    for (final w in [...open(p.websites), ...open(p.socials)])
      if (safeHttpsUrl(w.value) != null)
        'URL:${_vEscape(safeHttpsUrl(w.value)!)}',
    for (final a in open(p.addresses))
      // The address is kept as one line in the street slot.
      'ADR;${type(a.label, 'work')}:;;${_vEscape(a.value.trim())};;;;',
    if (p.bio.trim().isNotEmpty) 'NOTE:${_vEscape(p.bio.trim())}',
    for (final c in open(p.custom))
      'NOTE:${_vEscape('${c.label}: ${c.value}')}',
    'END:VCARD',
  ];
  return '${lines.map(_vFold).join('\r\n')}\r\n';
}

String _vEscape(String v) => v
    .replaceAll(r'\', r'\\')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\n')
    .replaceAll(',', r'\,')
    .replaceAll(';', r'\;');

/// Folds a line to 75-octet chunks; continuation lines start with a space.
String _vFold(String line) {
  final out = StringBuffer();
  var used = 0;
  for (final rune in line.runes) {
    final ch = String.fromCharCode(rune);
    final size = utf8.encode(ch).length;
    if (used + size > 75) {
      out.write('\r\n ');
      used = 1;
    }
    out.write(ch);
    used += size;
  }
  return out.toString();
}

/// Reads the plain fields of a vCard (FN, ORG, TITLE, TEL, EMAIL, URL,
/// ADR, NOTE) into a new profile. Anything else is ignored.
CardProfile profileFromVcard(String text, {required String id}) {
  if (text.length > 200000) throw const FormatException('vCard too large');
  final unfolded = text.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  if (!unfolded.contains('BEGIN:VCARD'))
    throw const FormatException('Not a vCard');
  String un(String v) => v
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\');
  var name = '', org = '', title = '', note = '';
  final phones = <ProfileValue>[], emails = <ProfileValue>[];
  final urls = <ProfileValue>[], addresses = <ProfileValue>[];
  for (final line in unfolded.split(RegExp(r'\r?\n'))) {
    final colon = line.indexOf(':');
    if (colon < 1) continue;
    final head = line.substring(0, colon).toUpperCase();
    final key = head.split(';').first.split('.').last;
    final value = line.substring(colon + 1);
    switch (key) {
      case 'FN':
        name = un(value);
      case 'ORG':
        org = un(value.split(';').first);
      case 'TITLE':
        title = un(value);
      case 'TEL':
        phones.add(
          ProfileValue(
            head.contains('CELL') ? 'cell' : '',
            un(value.replaceFirst('tel:', '')),
          ),
        );
      case 'EMAIL':
        emails.add(ProfileValue('', un(value)));
      case 'URL':
        urls.add(ProfileValue('', un(value)));
      case 'ADR':
        addresses.add(
          ProfileValue(
            '',
            un(value.split(';').where((s) => s.isNotEmpty).join(', ')),
          ),
        );
      case 'NOTE':
        note = un(value);
    }
  }
  return CardProfile(
    id: id,
    displayName: name,
    organization: org,
    role: title,
    bio: note,
    phones: phones.take(30).toList(),
    emails: emails.take(30).toList(),
    websites: urls.take(30).toList(),
    addresses: addresses.take(30).toList(),
  );
}
