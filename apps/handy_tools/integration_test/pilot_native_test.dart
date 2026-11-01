import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_tools/app.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_store/handy_store.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import '../test/pilot_test.dart' show FixtureFiles, openTool;

Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key).first);
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real platform preference persistence and calculator survive app recreation',
    (tester) async {
      // Isolated test namespace: never reads/writes a user's tools preferences.
      final repo = DevicePreferencesRepository('handy-pilotintegration');
      await repo.save(
        HandyPreferences(
          locale: 'en',
          theme: 'light',
          favorites: ['calculate'],
          drafts: {'calculate': '0.1 + 0.2'},
        ),
      );
      await tester.pumpWidget(HandyToolsApp(repository: repo));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pinned-calculate')), findsOneWidget);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('tools-home-light');
      }
      await openTool(tester, 'calculate');
      expect(find.widgetWithText(TextField, '0.1 + 0.2'), findsOneWidget);
      expect(find.text('0.3'), findsWidgets);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.takeScreenshot('tools-calculator');
      }
      await tester.pumpWidget(const SizedBox());
      final reopened = DevicePreferencesRepository('handy-pilotintegration');
      expect((await reopened.load()).drafts['calculate'], '0.1 + 0.2');
      await tester.pumpWidget(HandyToolsApp(repository: reopened));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pinned-calculate')), findsOneWidget);
      await repo.save(HandyPreferences());
    },
  );
  testWidgets(
    'native store refuses unconfigured ownership and optional QR history persists',
    (tester) async {
      final store = NativeLifetimeStore(productId: '');
      final native = await store.read();
      expect(native.isPro, isFalse);
      expect(native.status, 'unavailable');
      await store.dispose();
      final docs = localDocuments(
        'handy-tools-qr-integration',
        maxBytes: 300000,
      );
      await docs.save(QrHistory().serialize());
      final prefs = DevicePreferencesRepository('handy-qr-integration');
      await prefs.save(HandyPreferences(locale: 'en', theme: 'light'));
      // Fixture files: saving the code must not open the system picker.
      await tester.pumpWidget(
        HandyToolsApp(
          repository: prefs,
          qrHistoryDocuments: docs,
          files: FixtureFiles(),
        ),
      );
      await tester.pumpAndSettle();
      await openTool(tester, 'qr');
      await tester.enterText(
        find.byKey(const ValueKey('qr-field-0')),
        'Handy QR fixture',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tapKey(tester, const Key('qr-history'));
      await tapKey(tester, const Key('qr-history-toggle'));
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('tools-optional-qr-history');
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapKey(tester, const Key('qr-save'));
      final reopened = QrHistory.parse(
        (await localDocuments(
          'handy-tools-qr-integration',
          maxBytes: 300000,
        ).load())!,
      );
      expect(reopened.enabled, isTrue);
      expect(reopened.entries.single['text'], 'Handy QR fixture');
      await docs.save(QrHistory().serialize());
    },
  );
}
