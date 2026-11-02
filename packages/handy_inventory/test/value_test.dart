import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/csv.dart';
import 'package:handy_inventory/handy_inventory.dart';

const now = '2026-10-31T08:00:00.000Z';
final png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
  ),
);

InventoryAsset item(String id, [Map<String, Object?> fields = const {}]) =>
    createAsset(id: id, name: 'Món $id', now: now, fields: fields);

void main() {
  group('schema v2', () {
    test('a version 1 file loads, its items have no price', () {
      final v1 = {
        'version': 1,
        'assets': [
          {
            for (final e in item('old').toJson().entries)
              if (e.key != 'price' && e.key != 'currency') e.key: e.value,
          },
        ],
        'boxes': [],
      };
      final state = parseKeepState(jsonEncode(v1));
      expect(state.assets.single.price, '');
      expect(state.assets.single.currency, '');
      expect(
        jsonDecode(serializeKeepState(state))['version'],
        keepStateVersion,
      );
    });

    test('price and currency roundtrip through JSON, backup and ZIP', () {
      final state = saveAssets(emptyKeepState(), [
        item('a', {
          'price': '4500000',
          'currency': 'VND',
          'photoUri': 'file:///p/a.png',
        }),
        item('b', {'price': '129.9', 'currency': 'USD'}),
        item('c'),
      ]);
      expect(
        parseKeepState(serializeKeepState(state)).toJson(),
        state.toJson(),
      );
      final backup = parseKeepBackup(exportKeepBackup(state));
      expect(backup.assets.map((a) => (a.price, a.currency)), [
        ('4500000', 'VND'),
        ('129.9', 'USD'),
        ('', ''),
      ]);
      final zip = buildKeepZip(state, {'file:///p/a.png': png});
      final bundle = parseKeepZip(zip);
      final restored = bundle.materialize({
        bundle.files.single.path: 'file:///new/a.png',
      });
      expect(restored.assets.first.price, '4500000');
      expect(restored.assets.first.currency, 'VND');
      expect(restored.assets[1].price, '129.9');
      expect(restored.assets.first.photoUri, 'file:///new/a.png');
    });

    test('bad prices and unpaired currencies are refused', () {
      for (final f in <Map<String, Object?>>[
        {'price': '12', 'currency': ''},
        {'price': '', 'currency': 'VND'},
        {'price': '-5', 'currency': 'USD'},
        {'price': '1e5', 'currency': 'USD'},
        {'price': '012', 'currency': 'USD'},
        {'price': '1.234', 'currency': 'USD'},
        {'price': '10.5', 'currency': 'VND'},
        {'price': '10', 'currency': 'usd'},
        {'price': '10', 'currency': 'DOLLAR'},
        {'price': '1234567890123', 'currency': 'USD'},
        {'price': 12, 'currency': 'USD'},
      ]) {
        expect(() => item('x', f), throwsFormatException, reason: '$f');
      }
    });
  });

  group('parsePrice', () {
    test('reads the ways people write money', () {
      expect(parsePrice('', 'VND'), '');
      expect(parsePrice('  ', 'USD'), '');
      expect(parsePrice('4.500.000', 'VND'), '4500000');
      expect(parsePrice('4,500,000', 'VND'), '4500000');
      expect(parsePrice('4 500 000', 'VND'), '4500000');
      expect(parsePrice('1,299.90', 'USD'), '1299.9');
      expect(parsePrice('1.299,90', 'EUR'), '1299.9');
      expect(parsePrice('12.5', 'USD'), '12.5');
      expect(parsePrice('1.000', 'USD'), '1000');
      expect(parsePrice('0', 'USD'), '0');
      expect(parsePrice('007', 'USD'), '7');
      expect(parsePrice('3.00', 'USD'), '3');
    });
    test('refuses what is not a number, in both languages', () {
      for (final bad in ['abc', '-5', '12a', '=1+2', '.', '1234567890123']) {
        expect(
          () => parsePrice(bad, 'USD'),
          throwsA(
            isA<FormatException>().having((e) => e.message, 'm', contains('/')),
          ),
          reason: bad,
        );
      }
    });
  });

  group('valueOf', () {
    test('sums per currency, never across, and counts unpriced', () {
      final v = valueOf([
        item('a', {'price': '4500000', 'currency': 'VND'}),
        item('b', {'price': '250000', 'currency': 'VND'}),
        item('c', {'price': '129.9', 'currency': 'USD'}),
        item('d', {'price': '0.15', 'currency': 'USD'}),
        item('e'),
        item('f'),
        item('g'),
      ]);
      expect(v.items, 7);
      expect(v.unpriced, 3);
      // Two items each: a tie, so by code.
      expect(v.amounts, [('USD', '130.05'), ('VND', '4750000')]);
      final more = valueOf([
        item('a', {'price': '1', 'currency': 'VND'}),
        item('b', {'price': '2', 'currency': 'VND'}),
        item('c', {'price': '3', 'currency': 'USD'}),
      ]);
      expect(more.amounts, [('VND', '3'), ('USD', '3.00')]);
      expect(v.hasPrices, isTrue);
    });
    test('nothing priced is no total, not a zero', () {
      final v = valueOf([item('a')]);
      expect(v.hasPrices, isFalse);
      expect(v.amounts, isEmpty);
      expect(v.unpriced, 1);
      expect(valueOf(const []).items, 0);
    });
    test('a real zero price is counted as priced', () {
      final v = valueOf([
        item('gift', {'price': '0', 'currency': 'USD'}),
      ]);
      expect(v.amounts, [('USD', '0.00')]);
      expect(v.unpriced, 0);
    });
    test('5,000 items at the largest price do not overflow', () {
      final v = valueOf([
        for (var i = 0; i < 5000; i++)
          item('i$i', {'price': '999999999999.99', 'currency': 'USD'}),
      ]);
      expect(v.amounts.single.$2, '4999999999999950.00');
    });
    test('usual currency is the most used, ties by code', () {
      var s = saveAssets(emptyKeepState(), [
        item('a', {'price': '1', 'currency': 'USD'}),
        item('b', {'price': '1', 'currency': 'VND'}),
      ]);
      expect(usualCurrency(s), 'USD');
      s = saveAsset(s, item('c', {'price': '2', 'currency': 'VND'}));
      expect(usualCurrency(s), 'VND');
      expect(usualCurrency(emptyKeepState()), isNull);
    });
  });

  test('saveAssets adds all or nothing', () {
    final s = saveAssets(emptyKeepState(), [item('a'), item('b')]);
    expect(s.assets.map((a) => a.id), ['a', 'b']);
    final renamed = saveAssets(s, [
      s.assets.first.copyWith({'name': 'Đổi tên'}),
      item('c'),
    ]);
    expect(renamed.assets.map((a) => a.name), ['Đổi tên', 'Món b', 'Món c']);
    expect(
      () => saveAssets(s, [
        item('d', {'boxId': 'missing'}),
        item('e'),
      ]),
      throwsFormatException,
    );
    expect(s.assets.length, 2);
  });

  group('keepCsv', () {
    final state = saveAssets(
      saveBox(emptyKeepState(), InventoryBox(id: 'b1', name: 'Thùng 1')),
      [
        item('a', {
          'location': 'Tủ bếp, ngăn trên',
          'boxId': 'b1',
          'price': '4500000',
          'currency': 'VND',
          'purchasedOn': '2024-02-29',
          'warrantyUntil': '2026-02-28',
          'serial': '=HYPERLINK("http://x")',
          'notes': 'Dòng 1\n"trích" dẫn',
        }),
        item('b', {
          'borrower': '@Lan',
          'lentOn': '2026-10-01',
          'returnDue': '2026-10-20',
          'notes': '+1 pin, -2 ốc',
        }),
      ],
    );
    test('BOM, CRLF, header, one row per item, values intact', () {
      final csv = keepCsv(state, state.assets);
      expect(csv.startsWith('﻿'), isTrue);
      expect(csv.endsWith('\r\n'), isTrue);
      final rows = csvParse(csv);
      expect(rows.first, keepCsvColumns);
      expect(rows.length, 3);
      expect(rows[1], [
        'Món a',
        'Tủ bếp, ngăn trên',
        'Thùng 1',
        '',
        '',
        '',
        '2024-02-29',
        '4500000',
        'VND',
        '2026-02-28',
        '\'=HYPERLINK("http://x")',
        'Dòng 1\n"trích" dẫn',
      ]);
      expect(rows[2][3], "'@Lan");
      expect(rows[2][11], "'+1 pin, -2 ốc");
      expect(utf8.encode(csv).take(3), [0xEF, 0xBB, 0xBF]);
    });
    test('formula starts are neutralised, including full-width ones', () {
      for (final start in ['=', '+', '-', '@', '＝', '＋', '－', '＠']) {
        final s = saveAsset(state, item('z', {'notes': '${start}SUM(A1)'}));
        final row = csvParse(keepCsv(s, [s.assets.last])).last;
        expect(row[11], "'${start}SUM(A1)", reason: start);
      }
      // Fields are trimmed on save, so a tab or a return can only lead a
      // header cell; the guard covers it there too.
      final rows = csvParse(
        keepCsv(state, [], headers: [for (final _ in keepCsvColumns) '\tx']),
      );
      expect(rows.first.first, "'\tx");
    });
    test('only the given items, with localized headers', () {
      final headers = [for (final c in keepCsvColumns) 'vi:$c'];
      final rows = csvParse(
        keepCsv(state, [state.assets.last], headers: headers),
      );
      expect(rows.first, headers);
      expect(rows.length, 2);
      expect(rows[1].first, 'Món b');
      expect(() => keepCsv(state, [], headers: ['x']), throwsArgumentError);
    });
  });
}
