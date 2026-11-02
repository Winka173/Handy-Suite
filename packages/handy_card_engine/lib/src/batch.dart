part of '../handy_card_engine.dart';

/// Profile fields a spreadsheet column can fill.
const batchFields = [
  'name',
  'role',
  'org',
  'phone',
  'email',
  'website',
  'address',
  'bio',
];

/// One row of a batch: the profile it makes, the file name for its card,
/// and why it was skipped (null when it is kept).
class BatchRow {
  final int line;
  final CardProfile profile;
  final String fileName;
  final String? problem;
  const BatchRow(this.line, this.profile, this.fileName, this.problem);
}

/// Rows of a CSV (first row headers) turned into profiles by [mapping]
/// (profile field → header). A row without a name, with a broken email or
/// phone, or repeating an earlier name and email, is reported, not made.
/// File names are safe and unique.
List<BatchRow> batchRows(
  List<List<String>> table,
  Map<String, String> mapping,
) {
  if (table.isEmpty) throw const FormatException('The file has no rows');
  if (table.length > 2001)
    throw const FormatException('At most 2000 rows at a time');
  final headers = table.first.map((h) => h.trim()).toList();
  int? col(String field) {
    final h = mapping[field];
    if (h == null) return null;
    final i = headers.indexOf(h);
    return i < 0 ? null : i;
  }

  final seen = <String>{}, names = <String, int>{};
  final out = <BatchRow>[];
  for (var r = 1; r < table.length; r++) {
    final row = table[r];
    String get(String field) {
      final i = col(field);
      return i == null || i >= row.length ? '' : row[i].trim();
    }

    if (row.every((c) => c.trim().isEmpty)) continue;
    final profile = CardProfile(
      id: newCardId(),
      displayName: get('name'),
      role: get('role'),
      organization: get('org'),
      bio: get('bio'),
      phones: [if (get('phone').isNotEmpty) ProfileValue('', get('phone'))],
      emails: [if (get('email').isNotEmpty) ProfileValue('', get('email'))],
      websites: [
        if (get('website').isNotEmpty) ProfileValue('', get('website')),
      ],
      addresses: [
        if (get('address').isNotEmpty) ProfileValue('', get('address')),
      ],
    );
    String? problem;
    final key =
        '${profile.displayName.toLowerCase()}|${get('email').toLowerCase()}';
    if (profile.displayName.isEmpty) {
      problem = 'No name';
    } else if (get('email').isNotEmpty && !isEmail(get('email'))) {
      problem = 'Email is not valid';
    } else if (get('phone').isNotEmpty && telUri(get('phone')) == null) {
      problem = 'Phone is not valid';
    } else if (!seen.add(key)) {
      problem = 'Repeats an earlier row';
    }
    var base = safeCardFileName(
      profile.displayName.isEmpty ? 'card-$r' : profile.displayName,
    );
    final n = names[base.toLowerCase()] = (names[base.toLowerCase()] ?? 0) + 1;
    if (n > 1) base = '$base-$n';
    out.add(BatchRow(r + 1, profile, base, problem));
  }
  return out;
}
