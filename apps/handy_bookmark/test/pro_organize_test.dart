import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'welcome_test.dart' show open;
import 'widget_test.dart' show tapKey;
import 'new_flows_test.dart' show settle;

void main() {
  testWidgets('Free sees the dry run of a rule; applying it asks for Pro '
      'and writes nothing', (t) async {
    final c = await open(
      t,
      urls: ['https://www.youtube.com/watch?v=a', 'https://a.com/one'],
    );
    await t.runAsync(
      () => c.update(
        (l) => l.copyWith(
          collections: [
            ...l.collections,
            SaveCollection(id: 'v', name: 'Watch'),
          ],
        ),
        prefs: {
          ...c.preferences,
          'organizeRules': [
            organizePresets.first
                .copyWith(enabled: true, collectionId: 'v')
                .toJson(),
          ],
        },
      ),
    );
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/organize');
    await settle(t);
    expect(find.text('Into Watch'), findsOneWidget);
    await tapKey(t, 'organize-preview');
    await settle(t);
    expect(find.textContaining('1 would change'), findsOneWidget);
    await tapKey(t, 'organize-apply');
    await settle(t);
    expect(find.byKey(const Key('explore-pro')), findsOneWidget);
    expect(
      c.library!.bookmarks.where((b) => b.collectionId == 'v'),
      isEmpty,
      reason: 'nothing is written without Pro',
    );
  });
}
