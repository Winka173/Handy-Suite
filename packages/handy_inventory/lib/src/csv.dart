part of '../handy_inventory.dart';

/// The CSV columns, in order. Apps pass their own words for the header row.
const keepCsvColumns = [
  'Name',
  'Kept at',
  'Box',
  'Borrower',
  'Lent on',
  'Back by',
  'Bought on',
  'Price',
  'Currency',
  'Warranty until',
  'Serial',
  'Notes',
];

/// One spreadsheet cell. Every cell is quoted. Text a spreadsheet would run
/// as a formula (starting with =, +, -, @, a tab or a return, or their
/// full-width forms) gets a leading apostrophe, so it stays text.
String _cell(String value) {
  final safe = RegExp(r'^[=+\-@\t\r＝＋－＠]').hasMatch(value) ? "'$value" : value;
  return '"${safe.replaceAll('"', '""')}"';
}

/// [items] as a CSV file for a spreadsheet: UTF-8 with a byte order mark so
/// Excel reads Vietnamese, CRLF line ends, one row per item in the given
/// order. Prices are plain decimals with the currency in its own column.
String keepCsv(
  KeepState state,
  Iterable<InventoryAsset> items, {
  List<String> headers = keepCsvColumns,
}) {
  if (headers.length != keepCsvColumns.length)
    throw ArgumentError('One header per column');
  final boxes = {for (final b in state.boxes) b.id: b.name};
  final rows = [
    headers,
    for (final a in items)
      [
        a.name,
        a.location,
        boxes[a.boxId] ?? '',
        a.borrower,
        a.lentOn,
        a.returnDue,
        a.purchasedOn,
        a.price,
        a.currency,
        a.warrantyUntil,
        a.serial,
        a.notes,
      ],
  ];
  return '﻿${rows.map((r) => r.map(_cell).join(',')).join('\r\n')}\r\n';
}
