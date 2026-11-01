import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart';

const now = '2026-10-31T08:00:00.000Z';
void main() {
  InventoryAsset asset([String id = 'camera']) =>
      createAsset(id: id, name: 'Máy ảnh 😀', now: now);
  test('legacy v1 exact JSON roundtrip preserves IDs dates and fields', () {
    final state = saveAsset(
      emptyKeepState(),
      asset().copyWith({
        'location': 'Phòng 1',
        'serial': 'ABC-123',
        'notes': 'Giữ nguyên dữ liệu',
        'purchasedOn': '2024-02-29',
        'warrantyUntil': '2026-11-01',
      }),
    );
    final encoded = serializeKeepState(state),
        reopened = parseKeepState(encoded);
    expect(reopened.toJson(), state.toJson());
    expect(reopened.assets.single.createdAt, now);
    expect(reopened.assets.single.receipts, isEmpty);
  });
  test(
    'portable JSON strips local file references only, not inventory metadata',
    () {
      final item = asset().copyWith({
        'photoUri': 'file:///old/photo.png',
        'receipts': [
          {
            'id': 'r1',
            'name': 'Invoice',
            'mime': 'application/pdf',
            'uri': 'file:///old/invoice.pdf',
          },
        ],
      });
      final state = saveAsset(emptyKeepState(), item),
          portable = exportKeepBackup(state);
      expect(portable, isNot(contains('file:///')));
      final restored = parseKeepBackup(portable);
      expect(restored.assets.single.name, item.name);
      expect(restored.assets.single.receipts, isEmpty);
      expect(state.assets.single.photoUri, 'file:///old/photo.png');
      expect(
        parseKeepBackup(serializeKeepState(state)).assets.single.photoUri,
        '',
      );
    },
  );
  test('CRUD updates preserve row order and never mutate original', () {
    final a = saveAsset(emptyKeepState(), asset('a')),
        b = saveAsset(a, asset('b')),
        updated = saveAsset(b, asset('a').copyWith({'name': 'Updated'}));
    expect(updated.assets.map((a) => a.id), ['a', 'b']);
    expect(b.assets.first.name, 'Máy ảnh 😀');
    expect(removeAsset(updated, 'a').assets.single.id, 'b');
    expect(() => b.assets.clear(), throwsUnsupportedError);
  });
  test('boxes detach members safely and searches include box locations', () {
    var state = saveBox(
      emptyKeepState(),
      InventoryBox(id: 'b', name: 'Thùng máy ảnh', location: 'Kho tầng 2'),
    );
    state = saveAsset(state, asset().copyWith({'boxId': 'b'}));
    expect(assetsInBox(state, 'b').single.id, 'camera');
    expect(searchAssets(state, 'máy kho').single.id, 'camera');
    final updated = removeBox(state, 'b');
    expect(updated.assets.single.boxId, '');
    expect(updated.assets.single.name, state.assets.single.name);
  });
  test('lend/return retains item fields and updates timestamp', () {
    final original = saveAsset(emptyKeepState(), asset());
    final lent = lendAsset(
      original,
      'camera',
      'An',
      '2026-10-31',
      '2026-11-03',
      now: '2026-10-31T09:00:00Z',
    );
    expect(lent.assets.single.borrower, 'An');
    expect(lent.assets.single.updatedAt, '2026-10-31T09:00:00.000Z');
    final returned = returnAsset(lent, 'camera', now: '2026-11-04T10:00:00Z');
    expect(returned.assets.single.borrower, '');
    expect(returned.assets.single.lentOn, '');
    expect(returned.assets.single.returnDue, '');
    expect(returned.assets.single.name, original.assets.single.name);
  });
  test('reminders stable dates/overdue and not borrowed loan dates absent', () {
    final a = asset().copyWith({
      'maintenanceDue': '2026-10-30',
      'warrantyUntil': '2026-11-02',
      'borrower': 'An',
      'lentOn': '2026-10-30',
      'returnDue': '2026-10-31',
    });
    final reminders = getKeepReminders(
      saveAsset(emptyKeepState(), a),
      '2026-10-31',
    );
    expect(reminders.map((r) => r.kind), ['maintenance', 'loan', 'warranty']);
    expect(reminders.map((r) => r.overdue), [true, false, false]);
  });
  test('strict calendar dates and offsets normalize correctly', () {
    for (final date in [
      '2023-02-29',
      '2026-02-30',
      '2026-13-01',
      '0000-01-01',
      '2026-1-01',
    ]) {
      expect(isCalendarDate(date), false);
      expect(
        () => asset().copyWith({'purchasedOn': date}),
        throwsFormatException,
      );
    }
    expect(isCalendarDate('2024-02-29'), true);
    expect(
      asset().copyWith({'createdAt': '2026-10-31T15:00:00+07:00'}).createdAt,
      now,
    );
  });
  for (final change in <Map<String, Object?>>[
    {'id': '../escape'},
    {'name': ' '},
    {'photoUri': 'https://host/image.png'},
    {'createdAt': '2026-02-30T08:00:00Z'},
    {'updatedAt': '2026-10-30T08:00:00Z'},
    {'borrower': 'An'},
    {'lentOn': '2026-10-30'},
    {'borrower': 'An', 'lentOn': '2026-10-31', 'returnDue': '2026-10-30'},
    {'purchasedOn': '2026-11-01', 'warrantyUntil': '2026-10-31'},
    {'notes': 'x' * 10001},
    {
      'receipts': [
        {'id': 'r', 'name': 'a', 'mime': 'text/plain', 'uri': 'file:///a'},
      ],
    },
  ]) {
    test(
      'invalid fields ${change.keys.join(',')}',
      () => expect(() => asset().copyWith(change), throwsFormatException),
    );
  }
  test('receipt types local paths duplicate and count guards', () {
    for (final mime in ['image/png', 'image/jpeg', 'application/pdf']) {
      expect(
        asset()
            .copyWith({
              'receipts': [
                {
                  'id': 'r',
                  'name': 'Hóa đơn',
                  'mime': mime,
                  'uri': 'file:///invoice',
                },
              ],
            })
            .receipts
            .single
            .mime,
        mime,
      );
    }
    final receipt = {
      'id': 'r',
      'name': 'Invoice',
      'mime': 'application/pdf',
      'uri': 'file:///a',
    };
    expect(
      () => asset().copyWith({
        'receipts': [receipt, receipt],
      }),
      throwsFormatException,
    );
    expect(
      () => asset().copyWith({'receipts': List.filled(21, receipt)}),
      throwsFormatException,
    );
    expect(
      () => asset().copyWith({
        'receipts': [
          {...receipt, 'uri': 'content://outside'},
        ],
      }),
      throwsFormatException,
    );
  });
  test('cross references duplicates versions malformed imports rejected', () {
    final map = emptyKeepState().toJson();
    for (final raw in [
      null,
      [],
      {'version': 99, 'assets': [], 'boxes': []},
      {
        ...map,
        'assets': [asset().toJson(), asset().toJson()],
      },
      {
        ...map,
        'assets': [
          asset().copyWith({'boxId': 'missing'}).toJson(),
        ],
      },
      {
        ...map,
        'boxes': [
          {'id': 'b', 'name': 'Box', 'location': '', 'notes': ''},
          {'id': 'b', 'name': 'Box2', 'location': '', 'notes': ''},
        ],
      },
    ]) {
      expect(() => validateKeepState(raw), throwsFormatException);
    }
    expect(() => parseKeepState('{broken'), throwsFormatException);
    expect(() => parseKeepBackup('x' * 8000001), throwsFormatException);
  });
  test('UTF8 backup limits use bytes not only characters', () {
    final many = KeepState(
      assets: List.generate(
        300,
        (i) => createAsset(
          id: 'a$i',
          name: 'n',
          now: now,
          fields: {'notes': 'ệ' * 9500},
        ),
      ),
    );
    expect(() => exportKeepBackup(many), throwsFormatException);
  });
  test('maximum capacity rejects insert but edits/deletion still work', () {
    final state = KeepState(
      assets: List.generate(keepAssetLimit, (i) => asset('a$i')),
    );
    expect(validateKeepState(state.toJson()).assets.length, keepAssetLimit);
    expect(() => saveAsset(state, asset('extra')), throwsFormatException);
    expect(
      saveAsset(
        state,
        asset('a0').copyWith({'name': 'Changed'}),
      ).assets.first.name,
      'Changed',
    );
    expect(removeAsset(state, 'a0').assets.length, keepAssetLimit - 1);
  });
  test('legacy receipts missing remain absent in serialized form', () {
    final raw = asset().toJson();
    expect(raw.containsKey('receipts'), false);
    expect(
      jsonDecode(serializeKeepState(KeepState(assets: [asset()])))['version'],
      1,
    );
  });
}
