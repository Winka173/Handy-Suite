import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_dev/app.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import '../test/helpers.dart' show Files, Store, tapKey;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native Dev pins/drafts survive real preferences reopen and exclude sensitive drafts',
    (tester) async {
      DevicePreferencesRepository repository() => DevicePreferencesRepository(
        'handy-dev-state-integration',
        knownTools: devPreferenceIds,
        workflowSteps: devWorkflowIds,
      );
      await repository().save(
        HandyPreferences(
          locale: 'en',
          theme: 'dark',
          drafts: {'jwt': 'never-load-secret', 'base64-encode': 'Xin chào'},
        ),
      );
      Future<void> show() async {
        await tester.pumpWidget(
          DevApp(files: Files(), documents: Store(), preferences: repository()),
        );
        await tester.pumpAndSettle();
      }

      await show();
      expect(find.byKey(const Key('draft-jwt')), findsNothing);
      expect(find.byKey(const Key('draft-base64-encode')), findsOneWidget);
      await tapKey(tester, 'open-catalog');
      await tester.enterText(find.byKey(const Key('catalog-search')), 'Base64');
      await tester.pumpAndSettle();
      await tapKey(tester, 'catalog-pin-base64-encode');
      final saved = await repository().load();
      expect(saved.favorites, ['base64-encode']);
      expect(saved.drafts, {'base64-encode': 'Xin chào'});
      expect((saved.locale, saved.theme), ('en', 'dark'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await show();
      expect(find.byKey(const Key('pinned-base64-encode')), findsOneWidget);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('dev-pinned-tools');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
