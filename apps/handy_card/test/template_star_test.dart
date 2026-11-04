import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_card/data/store.dart';
import 'package:handy_card_engine/handy_card_engine.dart';
import 'card_flow_test.dart' show MemoryFiles, boot, settle;

void main() {
  testWidgets('starred templates gather under their own chip and stay', (
    t,
  ) async {
    final store = MemoryCardStore(), files = MemoryFiles();
    await boot(t, store, files, size: const Size(1280, 1000));
    await t.tap(find.byKey(const Key('templates-all')));
    await settle(t);
    expect(find.byKey(const Key('gallery-kind-favorites')), findsNothing);
    final first = cardTemplates.where((x) => x.id != 'blank').first;
    await t.tap(find.byKey(Key('gallery-star-${first.id}')));
    await settle(t);
    await t.tap(find.byKey(const Key('gallery-kind-favorites')));
    await settle(t);
    expect(find.textContaining('1 template ·'), findsOneWidget);
    expect(find.byKey(Key('gallery-${first.id}')), findsOneWidget);
    expect(store.records['settings']!.values.single, contains(first.id));
    // Unstarring the last one goes back to all.
    await t.tap(find.byKey(Key('gallery-star-${first.id}')));
    await settle(t);
    expect(find.byKey(const Key('gallery-kind-favorites')), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
