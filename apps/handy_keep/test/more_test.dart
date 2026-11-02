// Value totals, CSV export, batch add from photos and loan reminders.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/csv.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_keep/app.dart';
import 'package:handy_keep/batch/batch_draft.dart';
import 'package:handy_notifications/controller.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:handy_ui/kit.dart';
import 'package:timezone/timezone.dart' as tz;
import 'helpers.dart';
import 'keep_ui_test.dart' show inDays, saved, stored;

/// A household with prices in two currencies and some without.
KeepState priced() {
  var s = saveBox(
    emptyKeepState(),
    InventoryBox(id: 'b1', name: 'Box 1', location: 'Hall'),
  );
  s = saveBox(s, InventoryBox(id: 'b2', name: 'Box 2'));
  return saveAssets(s, [
    createAsset(
      id: 'tv',
      name: 'TV',
      fields: {'boxId': 'b1', 'price': '12000000', 'currency': 'VND'},
    ),
    createAsset(
      id: 'pan',
      name: 'Pan',
      fields: {'boxId': 'b1', 'price': '450000', 'currency': 'VND'},
    ),
    createAsset(id: 'mug', name: 'Mug', fields: {'boxId': 'b1'}),
    createAsset(
      id: 'lens',
      name: 'Lens',
      fields: {'boxId': 'b2', 'price': '899.5', 'currency': 'USD'},
    ),
    createAsset(
      id: 'drill',
      name: 'Drill',
      fields: {
        'location': 'Attic',
        'price': '1500000',
        'currency': 'VND',
        'borrower': 'Lan',
        'lentOn': inDays(-3),
        'returnDue': inDays(4),
      },
    ),
    createAsset(id: 'rope', name: 'Rope', fields: {'location': 'Attic'}),
  ]);
}

/// A store that counts its writes.
class CountingStore extends Store {
  int writes = 0;
  @override
  Future<void> save(String value) async {
    writes++;
    await super.save(value);
  }
}

class RecordingPort implements NotificationsPort {
  final scheduled = <int, String>{};
  final asked = <bool>[];
  @override
  Future<bool> allowed(bool request) async {
    asked.add(request);
    return true;
  }

  @override
  Future<Map<int, String>> pending(String namespace) async => {...scheduled};
  @override
  Future<void> schedule(String namespace, ReminderRequest request) async =>
      scheduled[request.id] = request.signature;
  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

class MemorySettings implements ReminderSettingsStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

ImportedBytes photo(String name) => ImportedBytes(name, pngBytes);

/// A text as read, whatever spans or no-break spaces set it.
Finder plain(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll(' ', ' ') == text,
);

void main() {
  group('value totals', () {
    testWidgets('home adds up per currency and counts what has no price', (
      tester,
    ) async {
      await start(tester, store: stored(priced()));
      // Two currencies side by side, never one sum; a quiet line here.
      expect(
        plain('Total value  13,950,000 đ · 899.50 USD · 2 without a price'),
        findsOneWidget,
      );
      // Each place says what it holds; a borrower is a place too.
      expect(find.byKey(const Key('place-value-with:lan')), findsOneWidget);
      expect(plain('1,500,000 đ'), findsOneWidget);
      expect(plain('12,450,000 đ · 1 without a price'), findsOneWidget);
    });

    testWidgets('the boxes view is the moving and insurance list', (
      tester,
    ) async {
      await start(tester, store: stored(priced()));
      await tapKey(tester, 'filter-boxes');
      expect(find.text('Packed in 2 boxes · 4 items'), findsOneWidget);
      expect(find.text('12,450,000 đ · 899.50 USD'), findsOneWidget);
      expect(plain('1 without a price'), findsWidgets);
      await tapKey(tester, 'filter-lent');
      expect(find.text('Out on loan · 1 item'), findsOneWidget);
      expect(plain('1,500,000 đ'), findsWidgets);
    });

    testWidgets('no prices anywhere: no totals, no nagging', (tester) async {
      await start(
        tester,
        store: stored(
          saveAsset(emptyKeepState(), createAsset(id: 'a', name: 'Lamp')),
        ),
      );
      expect(find.byKey(const Key('keep-value')), findsNothing);
      expect(find.textContaining('without a price'), findsNothing);
    });

    testWidgets('the editor reads a typed price and keeps it per currency', (
      tester,
    ) async {
      final store = stored(priced());
      await start(tester, store: store);
      await tapKey(tester, 'item-new');
      await tester.enterText(find.byKey(const Key('item-name')), 'Fridge');
      // The usual currency (most items are in đồng) is the default.
      expect(find.text('VND'), findsWidgets);
      await tester.enterText(find.byKey(const Key('item-price')), '9.990.000');
      await tapKey(tester, 'item-save');
      final fridge = saved(store).assets.firstWhere((a) => a.name == 'Fridge');
      expect((fridge.price, fridge.currency), ('9990000', 'VND'));
      expect(
        plain('Total value  23,940,000 đ · 899.50 USD · 2 without a price'),
        findsOneWidget,
      );
    });

    testWidgets('a price too large keeps the form and changes nothing', (
      tester,
    ) async {
      final store = stored(priced());
      await start(tester, store: store);
      final before = store.text;
      await tapKey(tester, 'item-new');
      await tester.enterText(find.byKey(const Key('item-name')), 'Yacht');
      await tester.enterText(
        find.byKey(const Key('item-price')),
        '9999999999999',
      );
      await tapKey(tester, 'item-save');
      expect(find.text('Price is too large'), findsOneWidget);
      expect(find.byKey(const Key('item-name')), findsOneWidget);
      expect(store.text, before);
    });

    testWidgets('the item shows what was paid', (tester) async {
      await start(tester, store: stored(priced()));
      await tapKey(tester, 'item-lens');
      expect(find.text('Price paid'), findsOneWidget);
      expect(find.text('899.50 USD'), findsOneWidget);
    });
  });

  group('CSV export', () {
    testWidgets('the list menu saves what is shown, formula-safe', (
      tester,
    ) async {
      final files = Files();
      await start(tester, store: stored(priced()), files: files);
      await tapKey(tester, 'filter-lent');
      await tapKey(tester, 'keep-list-menu');
      expect(find.text('Save these 1 as CSV'), findsOneWidget);
      await tapKey(tester, 'export-csv');
      expect(files.exportedName, 'handy-keep-items.csv');
      expect(files.exportedMime, 'text/csv');
      expect(files.png!.take(3), [0xEF, 0xBB, 0xBF]);
      final rows = csvParse(utf8.decode(files.png!));
      expect(rows.length, 2);
      expect(rows.first.first, 'Name');
      expect(rows[1].take(4), ['Drill', 'Attic', '', 'Lan']);
      expect(rows[1][7], '1500000');
      expect(find.text('1 item saved as CSV.'), findsOneWidget);
    });

    testWidgets('settings saves every item; cancel says nothing', (
      tester,
    ) async {
      final files = Files()..cancel = true;
      await start(tester, store: stored(priced()), files: files);
      await tapKey(tester, 'open-settings');
      await tapKey(tester, 'keep-export-csv');
      expect(files.png, isNull);
      expect(find.textContaining('saved as CSV'), findsNothing);
      files.cancel = false;
      await tapKey(tester, 'keep-export-csv');
      final rows = csvParse(utf8.decode(files.png!));
      expect(rows.length, 7);
      expect(find.text('6 items saved as CSV.'), findsOneWidget);
    });

    testWidgets('a failed export leaves the inventory as it was', (
      tester,
    ) async {
      final store = stored(priced());
      final files = Files()..fail = true;
      await start(tester, store: store, files: files);
      final before = store.text;
      await tapKey(tester, 'keep-list-menu');
      await tapKey(tester, 'export-csv');
      expect(find.textContaining('Disk unavailable'), findsOneWidget);
      expect(store.text, before);
    });
  });

  group('batch add from photos', () {
    test('drafts check each photo and refuse unnamed ones', () {
      final d = BatchDraft(box: 'b1');
      d.add([
        photo('a.png'),
        ImportedBytes('notes.txt', Uint8List.fromList(utf8.encode('hello'))),
        ImportedBytes('big.png', Uint8List(4000001)),
        photo('b.png'),
      ]);
      expect(d.drafts.map((x) => x.file), ['a.png', 'b.png']);
      expect(d.rejected.map((x) => x.file), ['notes.txt', 'big.png']);
      d.drafts.first.name.text = 'Kettle';
      expect(() => d.build(), throwsFormatException);
      expect(d.unnamed, {d.drafts.last});
      d.drafts.last.name.text = 'Toaster';
      d.location.text = 'Kitchen';
      var n = 0;
      final edits = d.build(
        now: '2026-11-02T08:00:00.000Z',
        id: () => 'n${n++}',
      );
      expect(edits.map((e) => e.asset.name), ['Kettle', 'Toaster']);
      expect(edits.every((e) => e.asset.boxId == 'b1'), isTrue);
      expect(edits.every((e) => e.asset.location == 'Kitchen'), isTrue);
      expect(edits.every((e) => e.blobs.containsKey(e.asset.photoUri)), isTrue);
      expect(d.unnamed, isEmpty);
      d.dispose();
    });

    test('a batch stops at the limit and says why', () {
      final d = BatchDraft();
      d.add([for (var i = 0; i < 23; i++) photo('p$i.png')]);
      expect(d.drafts.length, BatchDraft.limit);
      expect(d.full, isTrue);
      expect(d.rejected.length, 3);
      d.dispose();
    });

    testWidgets('pick several, name each, one box for all, one write', (
      tester,
    ) async {
      final store = CountingStore()..text = serializeKeepState(priced());
      final files = Files()
        ..nextMany = [
          photo('1.png'),
          photo('2.png'),
          ImportedBytes('3.heic', Uint8List.fromList([0, 1, 2, 3])),
        ];
      await start(tester, store: store, files: files);
      await tapKey(tester, 'keep-list-menu');
      await tapKey(tester, 'batch-add');
      await tapKey(tester, 'batch-files');
      expect(find.byKey(const Key('batch-name-0')), findsOneWidget);
      expect(find.byKey(const Key('batch-name-1')), findsOneWidget);
      expect(find.textContaining('3.heic'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('batch-name-0')), 'Books');
      await tapKey(tester, 'batch-save');
      // An unnamed photo blocks the save and nothing is written.
      expect(find.text('Name it or remove it'), findsOneWidget);
      expect(store.writes, 0);
      await tester.enterText(find.byKey(const Key('batch-name-1')), 'Lamp');
      await tapKey(tester, 'batch-box');
      await tester.tap(find.text('Box 2').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'batch-save');
      expect(store.writes, 1);
      final s = saved(store);
      final added = s.assets.where((a) => ['Books', 'Lamp'].contains(a.name));
      expect(added.length, 2);
      expect(added.every((a) => a.boxId == 'b2'), isTrue);
      expect(added.every((a) => a.photoUri.isNotEmpty), isTrue);
      expect(find.text('2 items added.'), findsOneWidget);
    });

    testWidgets('closing with photos asks, and keeps nothing', (tester) async {
      final store = CountingStore()..text = serializeKeepState(priced());
      final files = Files()..nextMany = [photo('1.png')];
      await start(tester, store: store, files: files);
      await tapKey(tester, 'keep-list-menu');
      await tapKey(tester, 'batch-add');
      await tapKey(tester, 'batch-files');
      await tester.enterText(find.byKey(const Key('batch-name-0')), 'Vase');
      await tapKey(tester, 'batch-close');
      expect(find.text('Discard this photo?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('batch-save')), findsNothing);
      expect(store.writes, 0);
      expect(saved(store).assets.any((a) => a.name == 'Vase'), isFalse);
    });

    testWidgets('a failed write keeps every photo and name for a retry', (
      tester,
    ) async {
      final store = CountingStore()..text = serializeKeepState(priced());
      final files = Files()..nextMany = [photo('1.png')];
      await start(tester, store: store, files: files);
      final before = store.text;
      await tapKey(tester, 'keep-list-menu');
      await tapKey(tester, 'batch-add');
      await tapKey(tester, 'batch-files');
      await tester.enterText(find.byKey(const Key('batch-name-0')), 'Vase');
      store.fail = true;
      await tapKey(tester, 'batch-save');
      expect(find.byKey(const Key('batch-error')), findsOneWidget);
      expect(store.text, before);
      expect(find.text('Vase'), findsOneWidget);
      store.fail = false;
      await tapKey(tester, 'batch-save');
      expect(saved(store).assets.any((a) => a.name == 'Vase'), isTrue);
    });

    testWidgets('the camera takes photos in a row until it is closed', (
      tester,
    ) async {
      final store = stored(priced());
      final camera = Camera()
        ..burst = true
        ..queue.addAll([photo('a.jpg'), photo('b.jpg'), photo('c.jpg')]);
      await start(tester, store: store, camera: camera);
      await tapKey(tester, 'filter-boxes');
      await tapKey(tester, 'box-menu-b1');
      await tapKey(tester, 'box-batch-add');
      await tapKey(tester, 'batch-camera');
      for (var i = 0; i < 3; i++) {
        await tester.enterText(find.byKey(Key('batch-name-$i')), 'Cup $i');
      }
      await tapKey(tester, 'batch-remove-2');
      await tapKey(tester, 'batch-save');
      final cups = saved(store).assets.where((a) => a.name.startsWith('Cup'));
      expect(cups.map((a) => a.name), ['Cup 0', 'Cup 1']);
      expect(cups.every((a) => a.boxId == 'b1'), isTrue);
    });
  });

  group('loan reminders', () {
    testWidgets('a return date is scheduled; giving back or deleting cancels', (
      tester,
    ) async {
      final port = RecordingPort();
      final reminders = ReminderController(
        'keep',
        port: port,
        store: MemorySettings(),
        location: () async => tz.UTC,
      );
      addTearDown(reminders.dispose);
      final store = stored(
        saveAsset(emptyKeepState(), createAsset(id: 'tent', name: 'Tent')),
      );
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        KeepApp(
          documents: store,
          files: Files(),
          camera: Camera(),
          preferences: Preferences(),
          reminders: reminders,
        ),
      );
      await tester.pumpAndSettle();
      // Turned on: permission is asked once, then only checked.
      await tester.runAsync(() => reminders.setEnabled(true));
      expect(port.asked, [true]);
      final key = ReminderRequest('keep:tent-loan', tz.TZDateTime.utc(2026)).id;
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
      }

      await tapKey(tester, 'item-tent');
      // The lend dialog's calendar is covered elsewhere; this makes the same
      // store call the dialog makes.
      final app = tester.state(find.byType(KeepApp)) as dynamic;
      await tester.runAsync(
        () =>
            app.scope.store.lend('tent', 'Minh', inDays(0), inDays(5))
                as Future<void>,
      );
      await settle();
      expect(port.scheduled.keys, contains(key));
      expect(port.asked.skip(1), everyElement(false));
      await tapKey(tester, 'item-return');
      await settle();
      expect(port.scheduled.keys, isNot(contains(key)));
      await tester.runAsync(
        () =>
            app.scope.store.lend('tent', 'Minh', inDays(0), inDays(5))
                as Future<void>,
      );
      await settle();
      expect(port.scheduled.keys, contains(key));
      await tester.runAsync(
        () => app.scope.store.removeItem('tent') as Future<void>,
      );
      await settle();
      expect(port.scheduled, isEmpty);
    });

    testWidgets('an overdue loan is in "Needs a look" and on the Due page', (
      tester,
    ) async {
      final s = saveAsset(
        priced(),
        priced().assets.firstWhere((a) => a.id == 'drill').copyWith({
          'lentOn': inDays(-9),
          'returnDue': inDays(-1),
        }),
      );
      await start(tester, store: stored(s));
      expect(find.byKey(const Key('due-drill-loan')), findsOneWidget);
      expect(find.text('overdue by 1 day'), findsOneWidget);
      await tapKey(tester, 'due-all');
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.byKey(const Key('due-drill-loan')), findsOneWidget);
    });
  });
}
