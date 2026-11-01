// A guided walk through the app for a screen recording on a device:
// python tooling/device-tour.py --device <serial> habit
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_ui/kit.dart';
import 'package:integration_test/integration_test.dart';
import '../test/ui_test.dart' show MemoryStore;
import '../tool/screens_test.dart' show practice, now;

/// Lets the viewer see the screen before the next step.
Future<void> pause(WidgetTester t, [int ms = 1200]) async {
  await t.pumpAndSettle();
  await Future<void>.delayed(Duration(milliseconds: ms));
  await t.pump();
}

Finder _down() => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .hitTestable();

/// Scrolls every list on screen back to its top, the way a thumb would.
Future<void> toTop(WidgetTester t) async {
  for (final list in t.stateList<ScrollableState>(_down())) {
    unawaited(
      list.position.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      ),
    );
  }
  await pause(t, 700);
}

Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) await toTop(t);
  if (f.evaluate().isEmpty)
    await t.scrollUntilVisible(f, 300, scrollable: _down().first);
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await pause(t, 700);
}

Future<void> type(WidgetTester t, String key, String text) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  // A new text-input client after the last one closed on the device.
  await t.tap(f.first);
  await t.pumpAndSettle();
  await t.enterText(f.first, text);
  await pause(t, 700);
}

/// Scrolls smoothly until [key] is in view, so the film shows the way.
Future<void> show(WidgetTester t, String key, [int ms = 1500]) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty)
    await t.scrollUntilVisible(f, 300, scrollable: _down().first);
  unawaited(
    Scrollable.ensureVisible(
      t.element(f.first),
      alignment: .3,
      duration: const Duration(milliseconds: 600),
    ),
  );
  await pause(t, ms);
}

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
  testWidgets('Handy Habit tour', (t) async {
    final c = HabitController(
      open: () async => MemoryStore()..value = practice(),
    );
    await c.load();
    addTearDown(c.dispose);
    final width = t.view.physicalSize.width / t.view.devicePixelRatio;
    final wide = width >= HandySpace.wide;
    Future<void> area(int i) => tap(t, wide ? 'area-$i' : 'nav-$i');

    await t.pumpWidget(
      HabitApp(controller: c, clock: () => now.add(const Duration(minutes: 1))),
    );
    await pause(t, 2500);

    // Today: one tap on a bead marks it; water counts up one glass a tap.
    await tap(t, 'bead-water');
    await pause(t, 1200);
    await tap(t, 'bead-water');
    await pause(t, 1200);
    // Minutes ask how much.
    await tap(t, 'bead-walk');
    await tap(t, 'amount-rest');
    await pause(t, 1500);

    // A habit: its run of days and a month of beads; fill in a past day.
    await tap(t, 'habit-read');
    await pause(t, 2000);
    await show(t, 'day-2026-10-30', 1500);
    await tap(t, 'day-2026-10-30');
    await tap(t, 'field-state-done');
    await pause(t, 800);
    await tap(t, 'editor-save');
    await pause(t, 1500);
    await back(t);

    // The morning routine, step by step; the quick version first.
    await area(2);
    await pause(t, 1500);
    await tap(t, 'routine-morning');
    await pause(t, 1500);
    await tap(t, 'routine-lite');
    await pause(t, 2000);
    await tap(t, 'sheet-cancel');
    await tap(t, 'routine-start');
    await pause(t, 2500);
    await tap(t, 'routine-complete-step');
    await pause(t, 2500);
    await tap(t, 'routine-pause');
    await pause(t, 1200);
    await back(t);
    await back(t);

    // Insights: what actually happened, without a score.
    await area(3);
    await pause(t, 2500);
    await show(t, 'export-csv', 2000);

    // Settings: calendar, reminders, data.
    await tap(t, 'open-settings');
    await pause(t, 1500);
    await show(t, 'set-quiet', 1500);
    await show(t, 'habit-backup', 2000);
    await back(t);
    await area(0);
    await pause(t, 2000);
  }, timeout: const Timeout(Duration(minutes: 6)));
}
