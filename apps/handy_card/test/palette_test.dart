import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_card/data/store.dart';
import 'package:handy_card_engine/handy_card_engine.dart';
import 'card_flow_test.dart' show MemoryFiles, boot, settle;

void main() {
  testWidgets('a template switches palette in one tap and Undo brings it '
      'back', (t) async {
    final store = MemoryCardStore(), files = MemoryFiles();
    await boot(t, store, files, size: const Size(1280, 1000));
    await t.tap(find.byKey(const Key('templates-all')));
    await settle(t);
    final registry = ElementRegistry.standard();
    final pick = cardTemplates.firstWhere(
      (x) =>
          x.id.contains('-') &&
          paletteOf(x.build(registry, DateTime.utc(2026)))?.id == 'paper',
    );
    await t.scrollUntilVisible(
      find.byKey(Key('gallery-${pick.id}')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await t.tap(find.byKey(Key('gallery-${pick.id}')));
    await settle(t);

    await t.tap(find.byKey(const Key('studio-colours')));
    await settle(t);
    expect(find.textContaining('colours you picked yourself stay'), findsOne);
    await t.tap(find.byKey(const Key('palette-night')));
    await settle(t);
    String saved() => store.records['design']!.values.single;
    expect(saved(), contains('"background":"15181D"'));

    await t.tapAt(const Offset(20, 20));
    await settle(t);
    await t.tap(find.byKey(const Key('studio-undo')));
    await settle(t);
    expect(saved(), isNot(contains('"background":"15181D"')));
    await t.pumpWidget(const SizedBox());
  });
}
