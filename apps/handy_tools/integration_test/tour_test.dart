// A guided walk through the app for a screen recording on a device:
// python tooling/device-tour.py --device <serial> tools
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_tools/app.dart';
import 'package:handy_ui/kit.dart';
import 'package:integration_test/integration_test.dart';
import '../test/pilot_test.dart'
    show FixtureFiles, MemoryPreferences, QrTestDocuments;

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

/// Opens a tool from the catalog (Ctrl K), scrolling to its row.
Future<void> openTool(WidgetTester t, String id) async {
  await tap(t, 'open-catalog');
  final row = find.byKey(Key('catalog-$id'));
  await t.scrollUntilVisible(
    row,
    120,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await pause(t, 600);
  await t.tap(row);
  await pause(t, 900);
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
  testWidgets('Handy Tools tour', (t) async {
    await t.pumpWidget(
      HandyToolsApp(
        repository: MemoryPreferences()
          ..state = HandyPreferences(
            locale: 'vi',
            favorites: ['split-bill', 'loan', 'units'],
          ),
        files: FixtureFiles(),
        qrHistoryDocuments: QrTestDocuments(),
      ),
    );
    await pause(t, 2000);

    // The bench: type, get the answer, keep it on the tape.
    for (final line in [
      '1.385.000 / 3',
      '15% của 2.400.000',
      '4 x 125.000',
      '5 km sang mi',
    ]) {
      await type(t, 'bench-input', line);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await pause(t);
    }

    // Text: strip accents, then title case, as one chain.
    await type(t, 'bench-input', 'Nguyễn Văn An\nnguyễn văn an\nTrần Thị Bình');
    await tap(t, 'transform-accents');
    await tap(t, 'transform-title-case');
    await pause(t, 1500);

    // A loan, from the catalog.
    await openTool(t, 'loan');
    await type(t, 'field-principal', '250000000');
    await type(t, 'field-rate', '9.5');
    await type(t, 'field-months', '24');
    await pause(t, 2000);

    // A Wi-Fi QR code.
    await openTool(t, 'qr');
    await tap(t, 'qr-mode-wifi');
    await type(t, 'qr-field-0', 'Nha Minh 5G');
    await type(t, 'qr-field-1', 'bep-ga-2026');
    await pause(t, 2000);

    // A password.
    await openTool(t, 'password');
    await pause(t, 2000);

    // Settings, then dark.
    await tap(t, 'open-settings');
    await pause(t, 1500);
    await back(t);
    await pause(t, 1000);
  });
}
