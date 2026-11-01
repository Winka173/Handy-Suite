import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_keep/inventory/keep_store.dart' show today;
import 'package:handy_keep/library.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

String inDays(int n) => DateTime.parse(
  '${today()}T00:00:00Z',
).add(Duration(days: n)).toIso8601String().substring(0, 10);

KeepState sample() => saveAsset(
  saveAsset(
    saveAsset(
      saveBox(
        emptyKeepState(),
        InventoryBox(id: 'b7', name: 'Box 7', location: 'Attic'),
      ),
      createAsset(
        id: 'camera',
        name: 'Máy ảnh',
        fields: {'location': 'Office'},
      ),
    ),
    createAsset(
      id: 'drill',
      name: 'Drill',
      fields: {
        'boxId': 'b7',
        'borrower': 'Lan',
        'lentOn': inDays(-10),
        'returnDue': inDays(-2),
      },
    ),
  ),
  createAsset(id: 'lamp', name: 'Lamp', fields: {'boxId': 'b7'}),
);

Store stored(KeepState s) => Store()..text = serializeKeepState(s);
KeepState saved(Store s) => InventoryLibrary.parse(s.text!).state;

void main() {
  testWidgets(
    'things are listed under where they are; search ignores accents',
    (tester) async {
      await start(tester, store: stored(sample()));
      expect(find.text('Things at home'), findsOneWidget);
      expect(find.textContaining('With Lan'), findsWidgets);
      expect(find.textContaining('Box 7'), findsWidgets);
      expect(find.text('Máy ảnh'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('keep-search')), 'may anh');
      await tester.pumpAndSettle();
      expect(find.text('Máy ảnh'), findsOneWidget);
      expect(find.text('Lamp'), findsNothing);
      await tester.enterText(find.byKey(const Key('keep-search')), 'attic');
      await tester.pumpAndSettle();
      expect(find.text('Lamp'), findsOneWidget);
      expect(find.text('Máy ảnh'), findsNothing);
    },
  );

  testWidgets('corrupt inventory does not silently reset saved data', (
    tester,
  ) async {
    final store = Store()..text = '{bad';
    await start(tester, store: store);
    expect(find.text('Keep could not read your inventory'), findsOneWidget);
    expect(store.text, '{bad');
  });

  testWidgets('the overdue loan is the first thing to read', (tester) async {
    await start(tester, store: stored(sample()));
    expect(find.text('Needs a look'), findsOneWidget);
    expect(find.byKey(const Key('due-drill-loan')), findsOneWidget);
    expect(find.text('overdue by 2 days'), findsOneWidget);
    await tapKey(tester, 'due-all');
    expect(find.text('Overdue'), findsOneWidget);
  });

  testWidgets('a search with no match adds that thing, named already', (
    tester,
  ) async {
    final store = Store();
    await start(tester, store: store);
    expect(find.byKey(const Key('add-first-box')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('keep-search')), 'Ladder');
    await tester.pumpAndSettle();
    await tapKey(tester, 'add-from-search');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('item-name')))
          .controller!
          .text,
      'Ladder',
    );
    await tester.enterText(find.byKey(const Key('item-location')), 'Garage');
    await tapKey(tester, 'item-save');
    expect(saved(store).assets.single.location, 'Garage');
  });

  testWidgets(
    'a box name survives a failed save; retry commits before closing',
    (tester) async {
      final store = Store()..fail = true;
      await start(tester, store: store);
      await tapKey(tester, 'add-first-box');
      await tester.enterText(find.byKey(const Key('box-name')), 'Travel draft');
      await tapKey(tester, 'box-save');
      expect(find.byKey(const Key('box-name')), findsOneWidget);
      expect(find.textContaining('write rejected'), findsOneWidget);
      expect(store.text, isNull);
      store.fail = false;
      await tapKey(tester, 'box-save');
      expect(find.byKey(const Key('box-name')), findsNothing);
      expect(find.textContaining('Travel draft'), findsWidgets);
      expect(store.text, contains('Travel draft'));
    },
  );

  testWidgets('lending keeps the dialog on a failed write; return clears it', (
    tester,
  ) async {
    final store = stored(sample());
    await start(tester, store: store);
    await tapKey(tester, 'item-camera');
    expect(find.byKey(const Key('item-where')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('item-where'))).data,
      'Office',
    );
    await tapKey(tester, 'item-lend');
    await tester.enterText(find.byKey(const Key('lend-who')), 'Minh');
    store.fail = true;
    await tapKey(tester, 'lend-save');
    expect(find.byKey(const Key('lend-who')), findsOneWidget);
    expect(saved(store).assets.first.borrower, isEmpty);
    store.fail = false;
    await tapKey(tester, 'lend-save');
    expect(
      tester.widget<Text>(find.byKey(const Key('item-where'))).data,
      'With Minh',
    );
    await tapKey(tester, 'item-return');
    expect(
      tester.widget<Text>(find.byKey(const Key('item-where'))).data,
      'Office',
    );
    expect(saved(store).assets.first.borrower, isEmpty);
  });

  testWidgets('wide screens show the item beside the list; Escape closes it', (
    tester,
  ) async {
    await start(tester, store: stored(sample()), size: const Size(1280, 900));
    // Nothing chosen: the pane lists the dates, and the list drops its strip.
    expect(find.text('Dates to watch'), findsOneWidget);
    expect(find.byKey(const Key('pane-due-drill-loan')), findsOneWidget);
    expect(find.byKey(const Key('due-all')), findsNothing);
    await tapKey(tester, 'item-lamp');
    expect(
      tester.widget<Text>(find.byKey(const Key('item-where'))).data,
      'Box 7 · Attic',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('item-view')), findsNothing);
    // A date opens its item beside the list; the arrow goes back.
    await tapKey(tester, 'pane-due-drill-loan');
    expect(find.byKey(const Key('item-view')), findsOneWidget);
    await tapKey(tester, 'pane-dates');
    expect(find.byKey(const Key('pane-due-drill-loan')), findsOneWidget);
  });

  testWidgets('deleting a box keeps its things, out of any box', (
    tester,
  ) async {
    final store = stored(sample());
    await start(tester, store: store);
    await tapKey(tester, 'filter-boxes');
    await tapKey(tester, 'box-menu-b7');
    await tapKey(tester, 'box-delete');
    await tapKey(tester, 'confirm-action');
    final s = saved(store);
    expect(s.boxes, isEmpty);
    expect(s.assets.length, 3);
  });

  testWidgets('restoring a backup that repeats an item changes nothing', (
    tester,
  ) async {
    final store = stored(sample());
    final before = store.text;
    final files = Files()
      ..nextBytes = ImportedBytes(
        'b.zip',
        InventoryLibrary(sample(), {}).portable(),
      );
    await start(tester, store: store, files: files);
    await tapKey(tester, 'open-settings');
    await tapKey(tester, 'keep-restore-zip');
    await tapKey(tester, 'restore-merge');
    expect(store.text, before);
    await tapKey(tester, 'keep-restore-zip');
    await tapKey(tester, 'restore-replace');
    expect(saved(store).assets.length, 3);
  });
}
