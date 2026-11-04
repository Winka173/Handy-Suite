import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';
import 'keep_ui_test.dart' show sample, stored;

// Measuring from a photo left Keep on 2026-11-04 (Handy Tools has it). Notes
// written by it before then are plain text and stay as they are.
void main() {
  testWidgets('the item menu no longer offers measuring; old notes stay', (
    t,
  ) async {
    final state = saveAsset(
      sample(),
      createAsset(
        id: 'shelf',
        name: 'Shelf',
        fields: {'notes': 'Đo bằng ảnh: ≈ 84 mm, ≈ 1,20 m'},
      ),
    );
    await start(t, store: stored(state));
    await tapKey(t, 'item-shelf');
    expect(find.textContaining('≈ 84 mm'), findsWidgets);
    await tapKey(t, 'more-menu');
    expect(find.byKey(const Key('item-measure')), findsNothing);
    expect(find.byKey(const Key('item-label')), findsOneWidget);
  });
}
