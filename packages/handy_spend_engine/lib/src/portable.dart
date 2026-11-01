part of '../handy_spend_engine.dart';

const portableLimit = 30000000;
Uint8List backup(SpendState state, {bool zip = true}) {
  state.validate();
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(state.toJson())));
  if (bytes.length > portableLimit - 4096)
    throw const FormatException('Backup exceeds 30MB');
  if (!zip) return bytes;
  final manifest = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'app': 'handy-spend',
        'version': 1,
        'files': {'data.json': sha256.convert(bytes).toString()},
        'attachments': <String>[],
      }),
    ),
  );
  return Uint8List.fromList(
    ZipEncoder().encode(
      Archive()
        ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
        ..addFile(ArchiveFile('data.json', bytes.length, bytes)),
    ),
  );
}

SpendState restore(Uint8List bytes, {bool zip = true}) {
  if (bytes.length > portableLimit)
    throw const FormatException('Backup exceeds 30MB');
  var data = bytes;
  if (zip) {
    final files = decodePortableZip(
      bytes,
      isAllowedPath: (p) => {'manifest.json', 'data.json'}.contains(p),
      maxEntries: 2,
      maxEntryBytes: portableLimit - 4096,
    );
    if (files.length != 2) throw const FormatException('Missing backup files');
    final manifest = _map(jsonDecode(utf8.decode(files['manifest.json']!)));
    if (manifest['app'] != 'handy-spend' ||
        manifest['version'] != 1 ||
        _map(manifest['files'])['data.json'] !=
            sha256.convert(files['data.json']!).toString())
      throw const FormatException('Backup checksum/schema mismatch');
    data = files['data.json']!;
  }
  return SpendState.fromJson(_map(jsonDecode(utf8.decode(data))));
}

String cell(String value) => '"${value.replaceAll('"', '""')}"';
String safeCell(String value) =>
    RegExp(r'^[\s]*[=+@\-\t\r]').hasMatch(value) ? "'$value" : value;
String csvEncode(List<List<String>> rows, {String delimiter = ','}) =>
    rows.map((r) => r.map(cell).join(delimiter)).join('\r\n');
List<List<String>> csvParse(String text, {String delimiter = ','}) {
  if (text.length > portableLimit || ![',', ';', '\t'].contains(delimiter))
    throw const FormatException('CSV limit or delimiter');
  if (text.startsWith('\ufeff')) text = text.substring(1);
  final result = <List<String>>[], row = <String>[];
  var value = StringBuffer(), quoted = false, closed = false;
  void finishCell() {
    row.add(value.toString());
    value = StringBuffer();
    closed = false;
    if (row.length > 256) throw const FormatException('Too many columns');
  }

  void finishRow() {
    finishCell();
    if (row.any((e) => e.isNotEmpty)) result.add(List.of(row));
    row.clear();
    if (result.length > 100001) throw const FormatException('Too many rows');
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          value.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        value.write(c);
      }
      continue;
    }
    if (c == '"' && value.isEmpty && !closed) {
      quoted = true;
      continue;
    }
    if (c == delimiter) {
      finishCell();
      continue;
    }
    if (c == '\r' || c == '\n') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      finishRow();
      continue;
    }
    if (closed) throw const FormatException('Invalid quoted CSV field');
    value.write(c);
  }
  if (quoted) throw const FormatException('Unterminated quoted field');
  if (value.isNotEmpty || row.isNotEmpty || closed) finishRow();
  if (result.isEmpty) throw const FormatException('Empty statement');
  return result;
}

String decodeStatement(Uint8List bytes, {String encoding = 'utf8'}) {
  if (bytes.length > 12000000)
    throw const FormatException('Statement exceeds 12MB');
  if (encoding == 'latin1') return latin1.decode(bytes);
  if (bytes.length >= 2 &&
      ((bytes[0] == 255 && bytes[1] == 254) ||
          (bytes[0] == 254 && bytes[1] == 255))) {
    if (bytes.length.isOdd) throw const FormatException('Malformed UTF16');
    final little = bytes[0] == 255,
        d = ByteData.sublistView(bytes),
        codes = <int>[];
    for (var i = 2; i < bytes.length; i += 2) {
      codes.add(d.getUint16(i, little ? Endian.little : Endian.big));
    }
    return String.fromCharCodes(codes);
  }
  return utf8.decode(bytes);
}

String _xml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
Uint8List xlsxEncode(List<List<String>> rows) {
  if (rows.length > 100001 || rows.any((r) => r.length > 256))
    throw const FormatException('Spreadsheet limits');
  final sheet = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
  );
  for (var r = 0; r < rows.length; r++) {
    sheet.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      var n = c + 1, letters = '';
      while (n > 0) {
        n--;
        letters = String.fromCharCode(65 + n % 26) + letters;
        n ~/= 26;
      }
      sheet.write(
        '<c r="$letters${r + 1}" t="inlineStr"><is><t xml:space="preserve">${_xml(rows[r][c])}</t></is></c>',
      );
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');
  final parts = {
        '[Content_Types].xml':
            '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
        '_rels/.rels':
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
        'xl/workbook.xml':
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Transactions" sheetId="1" r:id="rId1"/></sheets></workbook>',
        'xl/_rels/workbook.xml.rels':
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
        'xl/worksheets/sheet1.xml': sheet.toString(),
      },
      archive = Archive();
  var total = 0;
  for (final e in parts.entries) {
    final bytes = utf8.encode(e.value);
    total += bytes.length;
    if (total > portableLimit)
      throw const FormatException('Spreadsheet exceeds 30MB');
    archive.addFile(ArchiveFile(e.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

List<List<String>> xlsxParse(Uint8List bytes) {
  final files = decodePortableZip(
    bytes,
    isAllowedPath: (p) =>
        p == '[Content_Types].xml' ||
        p.startsWith('xl/') ||
        p.startsWith('_rels/') ||
        p.startsWith('docProps/'),
    maxEntries: 256,
    maxEntryBytes: 12000000,
  );
  XmlDocument xml(String path) {
    final text = utf8.decode(
      files[path] ?? (throw const FormatException('Missing worksheet')),
    );
    if (RegExp(r'<!DOCTYPE|<!ENTITY', caseSensitive: false).hasMatch(text))
      throw const FormatException('XML entities prohibited');
    return XmlDocument.parse(text);
  }

  for (final path in files.keys.where((p) => p.endsWith('.rels'))) {
    if (xml(path)
        .findAllElements('Relationship')
        .any((e) => e.getAttribute('TargetMode') == 'External'))
      throw const FormatException('External workbook links prohibited');
  }
  if (files.keys.any((p) => p.toLowerCase().endsWith('.bin')))
    throw const FormatException('Macro workbooks prohibited');
  final strings = files.containsKey('xl/sharedStrings.xml')
      ? xml('xl/sharedStrings.xml')
            .findAllElements('si')
            .map((s) => s.findAllElements('t').map((e) => e.innerText).join())
            .toList()
      : <String>[];
  final workbook = xml('xl/workbook.xml');
  if (workbook
      .findAllElements('workbookPr')
      .any(
        (e) =>
            e.getAttribute('date1904') == '1' ||
            e.getAttribute('date1904') == 'true',
      ))
    throw const FormatException('1904 date system not supported; export CSV');
  final first = workbook.findAllElements('sheet').firstOrNull;
  if (first == null) throw const FormatException('No worksheet');
  final rid = first.getAttribute(
        'id',
        namespaceUri:
            'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
      ),
      rels = xml('xl/_rels/workbook.xml.rels').findAllElements('Relationship'),
      target = rels
          .where((e) => e.getAttribute('Id') == rid)
          .firstOrNull
          ?.getAttribute('Target');
  if (target == null || target.contains('..') || target.contains('\\'))
    throw const FormatException('Invalid worksheet reference');
  final path = target.startsWith('/') ? target.substring(1) : 'xl/$target';
  final rows = <List<String>>[];
  for (final row in xml(path).findAllElements('row')) {
    if (rows.length >= 100001) throw const FormatException('Too many rows');
    final values = <String>[];
    for (final c in row.findElements('c')) {
      if (c.findElements('f').isNotEmpty)
        throw const FormatException(
          'Formula cells prohibited; export values only',
        );
      final ref = c.getAttribute('r') ?? '',
          m = RegExp(r'^([A-Z]+)\d+$').firstMatch(ref);
      if (m == null) throw const FormatException('Missing cell reference');
      var index = 0;
      for (final ch in m[1]!.codeUnits) {
        index = index * 26 + ch - 64;
      }
      if (index < 1 || index > 256)
        throw const FormatException('Too many columns');
      while (values.length < index) {
        values.add('');
      }
      final type = c.getAttribute('t'),
          value = c.findElements('v').firstOrNull?.innerText ?? '';
      values[index - 1] = type == 's'
          ? strings[int.parse(value)]
          : type == 'inlineStr'
          ? c.findAllElements('t').map((e) => e.innerText).join()
          : value;
    }
    if (values.any((e) => e.isNotEmpty)) rows.add(values);
  }
  if (rows.isEmpty) throw const FormatException('Empty worksheet');
  return rows;
}

List<List<String>> transactionRows(SpendState s, Iterable<Entry> entries) {
  final ac = {for (final a in s.accounts) a.id: a};
  return [
    [
      'date',
      'payee',
      'amount',
      'currency',
      'account',
      'kind',
      'category',
      'note',
      '_handy_entry_v1',
    ],
    ...entries.map(
      (e) => [
        e.when,
        safeCell(e.payee),
        decimalMoney(e.amount, ac[e.account]!.currency),
        ac[e.account]!.currency,
        safeCell(ac[e.account]!.name),
        e.kind,
        e.category ?? '',
        safeCell(e.note),
        base64Encode(utf8.encode(jsonEncode(e.toJson()))),
      ],
    ),
  ];
}

List<Entry> readTransactionRows(SpendState s, List<List<String>> rows) {
  if (rows.first.length != 9 || rows.first.last != '_handy_entry_v1')
    throw const FormatException('Not a Handy transaction export');
  final result = <Entry>[];
  for (final row in rows.skip(1)) {
    if (row.length != 9) throw const FormatException('Malformed exported row');
    final e = Entry.fromJson(
          _map(jsonDecode(utf8.decode(base64Decode(row.last)))),
        ),
        expected = transactionRows(s, [e]).last;
    if (jsonEncode(row) != jsonEncode(expected))
      throw const FormatException(
        'Visible fields differ from portable record; use statement mapping for edited files',
      );
    result.add(e);
  }
  s.copy({'entries': result.map((e) => e.toJson()).toList()});
  return result;
}

class StatementMapping {
  final int date, payee, amount, debit, credit, balance;
  final String dateFormat, decimal, group, zone, account;
  final bool reverse, newestFirst;
  const StatementMapping({
    required this.account,
    this.date = 0,
    this.payee = 1,
    this.amount = 2,
    this.debit = -1,
    this.credit = -1,
    this.balance = -1,
    this.dateFormat = 'ymd',
    this.decimal = '.',
    this.group = ',',
    this.zone = 'Asia/Ho_Chi_Minh',
    this.reverse = false,
    this.newestFirst = false,
  });
  Map<String, dynamic> toJson() => {
    'account': account,
    'date': date,
    'payee': payee,
    'amount': amount,
    'debit': debit,
    'credit': credit,
    'balance': balance,
    'newestFirst': newestFirst,
    'dateFormat': dateFormat,
    'decimal': decimal,
    'group': group,
    'zone': zone,
    'reverse': reverse,
  };
  factory StatementMapping.fromJson(Map<String, dynamic> j) => StatementMapping(
    account: _text(j['account']),
    date: j['date'] as int,
    payee: j['payee'] as int,
    amount: j['amount'] as int,
    debit: j['debit'] as int,
    credit: j['credit'] as int,
    balance: j['balance'] as int? ?? -1,
    newestFirst: j['newestFirst'] == true,
    dateFormat: _text(j['dateFormat']),
    decimal: _text(j['decimal']),
    group: _text(j['group']),
    zone: _text(j['zone']),
    reverse: j['reverse'] == true,
  );
}

String fingerprint(Entry e, String zone, {bool absolute = false}) => sha256
    .convert(
      utf8.encode(
        '${e.account}|${reportDay(e.when, zone)}|${absolute ? e.amount.abs() : e.amount}|${e.payee.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}',
      ),
    )
    .toString();

class StatementRow {
  final int number;
  final Entry? entry;
  final String status, error;
  const StatementRow(this.number, this.entry, this.status, [this.error = '']);
}

class StatementPreview {
  final String fileHash, batchId;
  final List<StatementRow> rows;
  final String? statementAccount, balanceAt;
  final BigInt? closingBalance;
  const StatementPreview(
    this.fileHash,
    this.batchId,
    this.rows, {
    this.statementAccount,
    this.balanceAt,
    this.closingBalance,
  });
  Map<String, String>? reconciliation(SpendState state) {
    if (statementAccount == null || balanceAt == null || closingBalance == null)
      return null;
    final ledger = balances(state, balanceAt!)[statementAccount!]!;
    return {
      'account': statementAccount!,
      'asOf': balanceAt!,
      'statement': '$closingBalance',
      'ledger': '$ledger',
      'difference': '${ledger - closingBalance!}',
    };
  }

  SpendState commit(
    SpendState current,
    Set<int> selected, {
    bool allowPartial = false,
  }) {
    if (!allowPartial && rows.any((r) => r.status == 'error'))
      throw const FormatException(
        'Fix errors or explicitly allow partial import',
      );
    final chosen = rows.where((r) => selected.contains(r.number)).toList();
    if (chosen.any((r) => r.entry == null))
      throw const FormatException('Invalid selected row');
    if (chosen.any((r) => r.status == 'needs classification'))
      throw const FormatException(
        'Classify liability credits explicitly before import',
      );
    if (chosen.isEmpty) throw const FormatException('No rows selected');
    final entries = chosen.map((r) => r.entry!).toList(),
        record = <String, dynamic>{
          'id': batchId,
          'fileHash': fileHash,
          'at': DateTime.now().toUtc().toIso8601String(),
          'totalRows': rows.length,
          'imported': entries.length,
          'entries': {
            for (final e in entries)
              e.id: sha256
                  .convert(utf8.encode(jsonEncode(e.toJson())))
                  .toString(),
          },
          'undone': false,
        };
    final combined = current.copy({
      'entries': [
        ...current.entries.map((e) => e.toJson()),
        ...entries.map((e) => e.toJson()),
      ],
    });
    record['reconciliation'] = reconciliation(combined);
    return combined.copy({
      'imports': [...current.imports, record],
    });
  }
}

StatementPreview previewStatement(
  SpendState s,
  List<List<String>> rows,
  StatementMapping mapping,
  Uint8List source,
) {
  if (rows.length < 2 || rows.length > 100001)
    throw const FormatException('Invalid row count');
  final ac = s.accounts
      .where((a) => a.id == mapping.account && !a.archived)
      .firstOrNull;
  if (ac == null) throw const FormatException('Choose an active account');
  location(mapping.zone);
  if (!{'ymd', 'dmy', 'mdy', 'excel'}.contains(mapping.dateFormat) ||
      !{'', ',', '.', ' ', '\u00a0'}.contains(mapping.group))
    throw const FormatException('Unsupported date/number mapping');
  if (mapping.decimal == mapping.group || !{'.', ','}.contains(mapping.decimal))
    throw const FormatException('Invalid separators');
  final known = s.entries.map((e) => fingerprint(e, mapping.zone)).toSet(),
      similar = s.entries
          .map((e) => fingerprint(e, mapping.zone, absolute: true))
          .toSet(),
      batch = newId(),
      result = <StatementRow>[];
  BigInt? closing;
  String? latest;
  String get(List<String> r, int i) => i < 0 || i >= r.length
      ? throw const FormatException('Missing mapped column')
      : r[i].trim();
  BigInt money(String text) {
    text = text.trim();
    if (text.startsWith('(') && text.endsWith(')'))
      text = '-${text.substring(1, text.length - 1)}';
    final body = text.replaceFirst(RegExp(r'^[+-]'), ''),
        parts = body.split(mapping.decimal);
    if (parts.length > 2)
      throw const FormatException('Repeated decimal separator');
    if (mapping.group.isNotEmpty &&
        parts.first.contains(mapping.group) &&
        !RegExp(
          '^[0-9]{1,3}(?:${RegExp.escape(mapping.group)}[0-9]{3})+\$',
        ).hasMatch(parts.first))
      throw const FormatException('Malformed digit grouping');
    if (parts.length == 2 &&
        mapping.group.isNotEmpty &&
        parts[1].contains(mapping.group))
      throw const FormatException('Grouping in fraction');
    if (mapping.group.isNotEmpty) text = text.replaceAll(mapping.group, '');
    return minor(text, ac.currency, decimal: mapping.decimal);
  }

  for (var i = 1; i < rows.length; i++) {
    try {
      final r = rows[i], rawDate = get(r, mapping.date);
      String date;
      if (mapping.dateFormat == 'excel') {
        final n = int.parse(rawDate);
        if (n == 60 || n < 1 || n > 200000)
          throw const FormatException('Invalid Excel date');
        date = day(
          DateTime.utc(1899, 12, n < 60 ? 31 : 30).add(Duration(days: n)),
        );
      } else if (mapping.dateFormat == 'ymd') {
        if (rawDate.length > 10 &&
            !RegExp(
              r'^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d\d:\d\d)$',
            ).hasMatch(rawDate))
          throw const FormatException('Time requires an explicit timezone');
        date = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
        calendar(date);
      } else {
        final p = rawDate.split(RegExp(r'[/.-]'));
        if (p.length != 3 || p[2].length != 4)
          throw const FormatException('Ambiguous date');
        date =
            '${p[2]}-${p[mapping.dateFormat == 'dmy' ? 1 : 0].padLeft(2, '0')}-${p[mapping.dateFormat == 'dmy' ? 0 : 1].padLeft(2, '0')}';
        calendar(date);
      }
      var amount = BigInt.zero;
      if (mapping.amount >= 0) {
        amount = money(get(r, mapping.amount));
      } else {
        final debit = get(r, mapping.debit),
            credit = get(r, mapping.credit),
            d = debit.isEmpty ? BigInt.zero : money(debit),
            c = credit.isEmpty ? BigInt.zero : money(credit);
        if (d.isNegative ||
            c.isNegative ||
            d != BigInt.zero && c != BigInt.zero)
          throw const FormatException('Invalid debit/credit pair');
        amount = c - d;
      }
      if (mapping.reverse) amount = -amount;
      final payee = get(r, mapping.payee);
      String? category;
      for (final rule in s.rules) {
        if (rule['contains'] is String &&
            payee.toLowerCase().contains(
              (rule['contains'] as String).toLowerCase(),
            ) &&
            s.categories.any(
              (c) =>
                  c.id == rule['category'] &&
                  c.kind == (amount.isNegative ? 'expense' : 'income'),
            )) {
          category = rule['category'] as String;
          break;
        }
      }
      final e = Entry(
            id: newId(),
            account: ac.id,
            kind: amount.isNegative ? 'expense' : 'income',
            amount: amount,
            when: mapping.dateFormat == 'ymd' && rawDate.length > 10
                ? timestamp(rawDate)
                : localTimestamp(date, mapping.zone),
            payee: payee,
            category: category,
            batch: batch,
          ),
          key = fingerprint(e, mapping.zone),
          potential = fingerprint(e, mapping.zone, absolute: true),
          status = known.contains(key)
              ? 'duplicate'
              : similar.contains(potential)
              ? 'possible reversal'
              : ac.liability && amount > BigInt.zero
              ? 'needs classification'
              : 'new';
      if (reportDay(e.when, s.zone).compareTo(ac.asOf) < 0)
        throw const FormatException('Transaction before opening balance');
      if (mapping.balance >= 0) {
        final value = money(get(r, mapping.balance));
        if (latest == null ||
            e.when.compareTo(latest) > 0 ||
            e.when == latest && !mapping.newestFirst) {
          closing = value;
          latest = e.when;
        }
      }
      known.add(key);
      similar.add(potential);
      result.add(StatementRow(i + 1, e, status));
    } catch (error) {
      result.add(
        StatementRow(
          i + 1,
          null,
          'error',
          error is FormatException ? error.message : 'Malformed row',
        ),
      );
    }
  }
  return StatementPreview(
    sha256.convert(source).toString(),
    batch,
    List.unmodifiable(result),
    statementAccount: mapping.account,
    closingBalance: closing,
    balanceAt: latest == null ? null : reportDay(latest, s.zone),
  );
}

SpendState undoImport(SpendState current, String batchId) {
  final record = current.imports
      .where((r) => r['id'] == batchId && r['undone'] != true)
      .firstOrNull;
  if (record == null) throw const FormatException('Import unavailable');
  final expected = _map(record['entries']),
      entries = current.entries.where((e) => e.batch == batchId).toList();
  if (entries.length != expected.length ||
      entries.any(
        (e) =>
            expected[e.id] !=
            sha256.convert(utf8.encode(jsonEncode(e.toJson()))).toString(),
      ))
    throw const FormatException('Batch changed; undo refused');
  return current.copy({
    'entries': current.entries
        .where((e) => e.batch != batchId)
        .map((e) => e.toJson())
        .toList(),
    'imports': [
      for (final r in current.imports)
        if (r['id'] == batchId) {...r, 'undone': true} else r,
    ],
  });
}
