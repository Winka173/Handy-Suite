import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_card/data/store.dart';
import 'package:handy_card_engine/handy_card_engine.dart';
import 'card_flow_test.dart' show MemoryFiles, boot, settle;

void main() {
  testWidgets('the gallery filters by occasion and starts a design', (t) async {
    final store = MemoryCardStore(), files = MemoryFiles();
    await boot(t, store, files, size: const Size(1280, 1000));
    // Home shows one per occasion and a way to all of them.
    await t.tap(find.byKey(const Key('templates-all')));
    await settle(t);
    final all = cardTemplates.length - 1;
    expect(find.textContaining('$all templates'), findsOneWidget);
    await t.tap(find.byKey(const Key('gallery-kind-invitation')));
    await settle(t);
    final invitations = cardTemplates.where((x) => x.kind == 'invitation');
    expect(
      find.textContaining('${invitations.length} templates'),
      findsOneWidget,
    );
    final pick = invitations.first;
    await t.tap(find.byKey(Key('gallery-${pick.id}')));
    await settle(t);
    expect(find.byKey(const Key('studio')), findsOneWidget);
    final saved = store.records['design']!.values.single;
    expect(saved, contains('"kind":"invitation"'));
    await t.pumpWidget(const SizedBox());
  });
}
