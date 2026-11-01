import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_keep/inventory/whereabouts.dart';

const at = '2026-10-01T08:00:00.000Z';
InventoryAsset item(
  String id,
  String name, [
  Map<String, Object?> f = const {},
]) => createAsset(id: id, name: name, now: at, fields: f);

void main() {
  final state = saveAsset(
    saveAsset(
      saveAsset(
        saveAsset(
          saveBox(
            emptyKeepState(),
            InventoryBox(id: 'b7', name: 'Thùng 7', location: 'Gác xép'),
          ),
          item('drill', 'Máy khoan', {
            'location': 'Gác xép',
            'boxId': 'b7',
            'borrower': 'Lan',
            'lentOn': '2026-10-12',
            'returnDue': '2026-10-27',
          }),
        ),
        item('lamp', 'Đèn bàn', {'boxId': 'b7'}),
      ),
      item('pot', 'Nồi cơm', {
        'location': 'Tủ bếp',
        'warrantyUntil': '2026-11-13',
      }),
    ),
    item('tape', 'Thước dây'),
  );

  test('each item sits in its most specific place, borrowers first', () {
    final places = whereabouts(state, state.assets);
    expect(places.map((p) => (p.kind, p.name, p.items.length)).toList(), [
      (PlaceKind.borrower, 'Lan', 1),
      (PlaceKind.box, 'Thùng 7', 1),
      (PlaceKind.location, 'Tủ bếp', 1),
      (PlaceKind.none, '', 1),
    ]);
    expect(places[1].detail, 'Gác xép');
  });

  test('empty boxes appear only when asked', () {
    final s = saveBox(state, InventoryBox(id: 'b8', name: 'Thùng 8'));
    expect(whereabouts(s, s.assets).any((p) => p.box?.id == 'b8'), isFalse);
    final empty = whereabouts(
      s,
      s.assets,
      emptyBoxes: true,
    ).singleWhere((p) => p.box?.id == 'b8');
    expect(empty.items, isEmpty);
  });

  test('search ignores accents and looks inside boxes and loans', () {
    expect(findItems(state, 'may khoan').single.id, 'drill');
    expect(findItems(state, 'gac xep').map((a) => a.id), ['drill', 'lamp']);
    expect(findItems(state, 'lan').single.id, 'drill');
    expect(findItems(state, 'không có'), isEmpty);
  });

  test('due items count days from today; attention keeps the next 30', () {
    final due = dueItems(state, '2026-11-01');
    expect(due.map((d) => (d.item.id, d.kind, d.days)).toList(), [
      ('drill', 'loan', -5),
      ('pot', 'warranty', 12),
    ]);
    expect(due.first.overdue, isTrue);
    expect(attention(state, '2026-11-01', window: 10).single.item.id, 'drill');
  });

  test('known locations merge items and boxes without repeats', () {
    expect(knownLocations(state), ['Gác xép', 'Tủ bếp']);
  });
}
