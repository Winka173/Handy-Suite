part of '../handy_spend_engine.dart';

/// Statement column templates. A template remembers how one layout of
/// columns is read (columns, date order, decimal and grouping marks, sign
/// rule, delimiter, encoding) and is found again by its header signature.
/// No bank layouts are shipped: every template is one the person saved.

String _headerText(String h) =>
    h.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The same headers in the same order, ignoring case and spacing.
String headerSignature(List<String> headers) => sha256
    .convert(
      utf8.encode(
        '${headers.length}\u001f${headers.map(_headerText).join('\u001f')}',
      ),
    )
    .toString();

const _delimiters = {',', ';', '\t'}, _encodings = {'utf8', 'latin1'};

void _checkTemplate(Map<String, dynamic> t) {
  final headers = t['headers'];
  if (t['id'] is! String ||
      (t['id'] as String).isEmpty ||
      t['name'] is! String ||
      (t['name'] as String).trim().isEmpty ||
      (t['name'] as String).length > 128 ||
      headers is! List ||
      headers.isEmpty ||
      headers.length > 256 ||
      headers.any((h) => h is! String || h.length > 1024) ||
      t['signature'] != headerSignature(List<String>.from(headers)) ||
      !_delimiters.contains(t['delimiter']) ||
      !_encodings.contains(t['encoding']) ||
      t['mapping'] is! Map)
    throw const FormatException('Invalid statement template');
  final m = StatementMapping.fromJson(_map(t['mapping']));
  for (final c in [m.date, m.payee, m.amount, m.debit, m.credit, m.balance]) {
    if (c < -1 || c >= headers.length)
      throw const FormatException('Template column out of range');
  }
}

/// Schema 1 profiles had headers and a mapping only: they gain their
/// signature and the CSV defaults they were made with.
Map<String, dynamic> _upgradeTemplate(Map<String, dynamic> t) => {
  ...t,
  'signature':
      t['signature'] ??
      (t['headers'] is List
          ? headerSignature(List<String>.from(t['headers'] as List))
          : null),
  'delimiter': t['delimiter'] ?? ',',
  'encoding': t['encoding'] ?? 'utf8',
};

/// A template for [headers] read with [mapping].
Map<String, dynamic> statementTemplate({
  String? id,
  required String name,
  required List<String> headers,
  required StatementMapping mapping,
  String delimiter = ',',
  String encoding = 'utf8',
}) {
  final t = <String, dynamic>{
    'id': id ?? newId(),
    'name': name.trim(),
    'signature': headerSignature(headers),
    'headers': List<String>.from(headers),
    'mapping': mapping.toJson(),
    'delimiter': delimiter,
    'encoding': encoding,
  };
  _checkTemplate(t);
  return t;
}

/// The saved template for exactly these headers, if any.
Map<String, dynamic>? templateFor(SpendState s, List<String> headers) {
  final sig = headerSignature(headers);
  return s.profiles.where((t) => t['signature'] == sig).firstOrNull;
}

/// [s] with [t] saved, replacing a template for the same headers.
SpendState saveTemplate(SpendState s, Map<String, dynamic> t) => s.copy({
  'profiles': [
    for (final x in s.profiles)
      if (x['signature'] != t['signature'] && x['id'] != t['id']) x,
    t,
  ],
});
