import 'package:flutter_test/flutter_test.dart';
import 'package:handy_keep/inventory/keep_store.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';
import 'keep_ui_test.dart' show sample, stored;

void main() {
  testWidgets('an item opens the measuring page from its menu', (t) async {
    await start(t, store: stored(sample()));
    await tapKey(t, 'item-drill');
    await tapKey(t, 'more-menu');
    await tapKey(t, 'item-measure');
    expect(find.text('Measure from a photo'), findsWidgets);
    expect(find.byKey(const Key('measure-pick')), findsOneWidget);
  });

  test('a measurement is written under the notes, nothing else', () async {
    final store = KeepStore(stored(sample()));
    await store.load();
    final before = store.state!.assets.first;
    await store.appendNote(before.id, 'Measured: ≈ 84 mm');
    final after = store.state!.assets.firstWhere((a) => a.id == before.id);
    expect(
      after.notes,
      before.notes.isEmpty
          ? 'Measured: ≈ 84 mm'
          : '${before.notes}\nMeasured: ≈ 84 mm',
    );
    expect(after.name, before.name);
    expect(after.location, before.location);
    expect(after.boxId, before.boxId);
  });
}
