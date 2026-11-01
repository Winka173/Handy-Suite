// A guided walk through the app for a screen recording on a device:
// python tooling/device-tour.py --device <serial> recall
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall/handy_recall.dart' show exportRecallBackup;
import 'package:handy_recall_app/app.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:integration_test/integration_test.dart';
import '../test/helpers.dart'
    show Files, Preferences, Store, now, testReminders;
import '../tool/screens_test.dart' show diagram, library;

/// Lets the viewer see the screen before the next step.
Future<void> pause(WidgetTester t, [int ms = 1200]) async {
  await t.pumpAndSettle();
  await Future<void>.delayed(Duration(milliseconds: ms));
  await t.pump();
}

Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await pause(t, 700);
}

Future<void> type(WidgetTester t, String key, String text) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  // A new text-input client after the last one closed on the device.
  await t.tap(f);
  await t.pumpAndSettle();
  await t.enterText(f, text);
  await pause(t, 700);
}

/// Picks the segment labelled [label] of the segmented control [key].
Future<void> choose(WidgetTester t, String key, String label) async {
  final f = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.text(label),
  );
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await pause(t, 700);
}

/// Closes the soft keyboard so the viewer sees the whole screen.
Future<void> hideKeyboard(WidgetTester t) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await pause(t, 500);
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
  testWidgets('Handy Recall tour', (t) async {
    // Three weeks into Japanese N3, anatomy and IELTS writing, with the
    // clock fixed so eleven cards are due and the forecast has a shape.
    final picture = await diagram();
    await t.pumpWidget(
      RecallApp(
        documents: Store()..text = exportRecallBackup(library(picture)),
        files: Files(),
        preferences: Preferences()
          ..value = HandyPreferences(locale: 'vi', theme: 'light'),
        reminders: testReminders(),
        clock: () => now,
      ),
    );
    await pause(t, 2000);

    // Today: how many cards are due, the minutes it takes, two weeks ahead.
    await pause(t, 2500);

    // A review over every deck: show the answer, then grade it. The
    // picture card lifts its covers when the answer shows.
    await tap(t, 'study-start');
    await pause(t, 1200);
    const grades = ['good', 'hard', 'good', 'easy', 'good', 'again'];
    var i = 0;
    while (i < 30 &&
        find.byKey(const Key('review-show')).evaluate().isNotEmpty) {
      await tap(t, 'review-show');
      await pause(t, i < 3 ? 1800 : 1100);
      await tap(t, 'grade-${i < grades.length ? grades[i] : 'good'}');
      i++;
    }

    // The session is over: what was done and when to come back.
    expect(find.byKey(const Key('review-done')), findsOneWidget);
    await pause(t, 2500);
    await tap(t, 'review-close');

    // Today again: nothing due, the forecast moved to the days ahead.
    await pause(t, 2500);

    // A deck: its cards by due date, then a search through them.
    await tap(t, 'deck-n3');
    await pause(t, 2000);
    await type(t, 'card-search', 'ける');
    await pause(t, 1500);
    await type(t, 'card-search', '');
    await hideKeyboard(t);

    // Two new cards: save one and keep going, then save and close.
    await tap(t, 'card-new');
    await type(t, 'card-front', '覚える (おぼえる)');
    await type(t, 'card-back', 'nhớ, ghi nhớ');
    await pause(t, 800);
    await tap(t, 'card-save-next');
    await pause(t, 1200);
    await type(t, 'card-front', '教える (おしえる)');
    await type(t, 'card-back', 'dạy, chỉ bảo');
    await hideKeyboard(t);
    await tap(t, 'card-save');
    await pause(t, 2000);
    await back(t);

    // Settings, then dark.
    await tap(t, 'open-settings');
    await pause(t, 1500);
    await choose(t, 'settings-theme', 'Tối');
    await pause(t, 1500);
    await back(t);
    await pause(t, 2500);
  });
}
