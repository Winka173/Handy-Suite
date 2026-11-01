// A guided walk through the app for a screen recording on a device:
// python tooling/device-tour.py --device <serial> keep
// Made for a landscape tablet (900 px wide or more): the places on the left,
// the chosen item beside them. The household is the review shots' one.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart' show serializeKeepState;
import 'package:handy_keep/app.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:integration_test/integration_test.dart';
import '../test/helpers.dart'
    show Camera, Files, Preferences, Store, testReminders;
import '../tool/screens_test.dart' show household;

/// Lets the viewer see the screen before the next step.
Future<void> pause(WidgetTester t, [int ms = 1200]) async {
  await t.pumpAndSettle();
  await Future<void>.delayed(Duration(milliseconds: ms));
  await t.pump();
}

/// The scrollable of the screen on top (the home list on the home screen).
Finder screenList() => find.byType(Scrollable).first;

Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  // The home list builds its rows lazily: from the top (the filters live
  // there), scroll down until this one exists.
  if (f.evaluate().isEmpty) {
    final list = t.state<ScrollableState>(screenList());
    if (list.position.pixels > 0) {
      unawaited(
        list.position.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        ),
      );
      await t.pumpAndSettle();
    }
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(f, 200, scrollable: screenList());
    }
  }
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await pause(t, 900);
}

Future<void> type(WidgetTester t, String key, String text) async {
  final f = find.byKey(Key(key));
  // The search field sits at the top of the home list; after scrolling
  // down the list may have let it go.
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(f, -300, scrollable: screenList());
  }
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  // A new text-input client after the last one closed on the device.
  await t.tap(f);
  await t.pumpAndSettle();
  await t.enterText(f, text);
  await pause(t, 700);
}

/// Puts the keyboard away so what it covered can be seen and tapped.
Future<void> done(WidgetTester t) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await pause(t, 600);
}

/// Scrolls the home list back up to the search field and the filters.
Future<void> toTop(WidgetTester t) async {
  await t.scrollUntilVisible(
    find.byKey(const Key('keep-search')),
    -300,
    scrollable: screenList(),
  );
  await pause(t, 600);
}

/// Goes back the way a person does: the top bar's back arrow, or the
/// system back when the screen has none.
Future<void> back(WidgetTester t) async {
  await t.pumpAndSettle();
  final arrow = find.byType(BackButton).hitTestable();
  if (arrow.evaluate().isNotEmpty) {
    await t.tap(arrow.last);
  } else {
    await t.binding.handlePopRoute();
  }
  await pause(t, 700);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Handy Keep tour', (t) async {
    await t.pumpWidget(
      KeepApp(
        documents: Store()..text = serializeKeepState(household()),
        files: Files(),
        camera: Camera(),
        preferences: Preferences()
          ..value = HandyPreferences(locale: 'vi', theme: 'light'),
        reminders: testReminders(),
      ),
    );
    await pause(t, 2000);

    // Nothing chosen yet: the pane beside the places lists every date,
    // returns, warranties and services. The drill Lan borrowed is late.
    // Open it; it is back. Then back to the dates.
    await pause(t, 2500);
    await tap(t, 'pane-due-i10-loan');
    await pause(t, 3000);
    await tap(t, 'item-return');
    await pause(t, 3000);
    await tap(t, 'pane-dates');
    await pause(t, 2500);

    // Search ignores accents: "bep" finds the kitchen box and the cupboard.
    await type(t, 'keep-search', 'bep');
    await done(t);
    await pause(t, 3000);
    await type(t, 'keep-search', '');
    await done(t);

    // One item: where it is now, its warranty, its serial.
    await tap(t, 'item-i5');
    await pause(t, 3500);

    // Moving it: the places already in use are one tap away.
    await tap(t, 'item-edit');
    await pause(t, 1500);
    await type(t, 'item-location', 'gac');
    await tap(t, 'place-Gác xép');
    await done(t);
    await pause(t, 1500);
    await tap(t, 'item-save');
    await pause(t, 3000);

    // Lending: the ladder goes to Hùng next door.
    await tap(t, 'item-i9');
    await pause(t, 2000);
    await tap(t, 'item-lend');
    await type(t, 'lend-who', 'Hùng');
    await done(t);
    await tap(t, 'lend-save');
    await pause(t, 3000);

    // Who has what, and when it should come back.
    await toTop(t);
    await tap(t, 'filter-lent');
    await pause(t, 2500);
    await tap(t, 'item-i11');
    await pause(t, 3000);

    // Packing for the move: things by box, and a QR label for the kitchen box.
    await tap(t, 'filter-boxes');
    await pause(t, 3000);
    await tap(t, 'box-menu-b1');
    await tap(t, 'box-label');
    await pause(t, 3500);
    await back(t);
    await tap(t, 'filter-all');
    await pause(t, 1500);

    // At the new place, the label opens the box. A phone reads it with the
    // camera; here the label's link is pasted.
    await tap(t, 'keep-open-label');
    await type(t, 'keep-label-input', 'handy-keep://box/b1');
    await done(t);
    await tap(t, 'keep-label-open');
    await pause(t, 3500);

    // Settings: reminders and backups, then the dark theme.
    await tap(t, 'open-settings');
    await pause(t, 2000);
    await t.scrollUntilVisible(
      find.byKey(const Key('keep-export-zip')),
      250,
      scrollable: screenList(),
    );
    await pause(t, 3000);
    final theme = find.byKey(const Key('settings-theme'));
    await t.scrollUntilVisible(theme, -250, scrollable: screenList());
    await pause(t, 1000);
    await t.tap(find.descendant(of: theme, matching: find.text('Tối')));
    await pause(t, 2000);
    await back(t);
    await pause(t, 3000);
  });
}
