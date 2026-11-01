import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_recall_app/app.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native review saves schedule and reopens with original card identity',
    (tester) async {
      final store = localDocuments('handy-recall-integration');
      final state = saveCard(
        saveDeck(
          emptyRecallState(),
          RecallDeck(id: 'integration-deck', name: 'Integration Skills'),
        ),
        createCard(
          id: 'integration-card',
          deckId: 'integration-deck',
          front: 'Question',
          back: 'Answer',
          now: '2026-01-01T00:00:00.000Z',
        ),
      );
      await store.save(exportRecallBackup(state));
      final prefs = DevicePreferencesRepository('handy-recall-integration');
      await prefs.save(HandyPreferences(locale: 'en'));
      await tester.pumpWidget(RecallApp(documents: store, preferences: prefs));
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('recall-home-light');
      }
      await tester.tap(find.byKey(const Key('study-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review-show')));
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS'))
        await binding.takeScreenshot('recall-study-answer');
      await tester.tap(find.byKey(const Key('grade-good')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review-done')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final reopened = parseRecallBackup(
        (await localDocuments('handy-recall-integration').load())!,
      );
      expect(reopened.cards.single.id, 'integration-card');
      expect(reopened.cards.single.reviewCount, 1);
      expect(reopened.cards.single.ease, state.cards.single.ease);
      await tester.pumpWidget(RecallApp(documents: store, preferences: prefs));
      await tester.pumpAndSettle();
      expect(find.text('Integration Skills'), findsOneWidget);
      await store.save(exportRecallBackup(emptyRecallState()));
    },
  );
}
