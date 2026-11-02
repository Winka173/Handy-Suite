import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'vn_tools_test.dart' show go, type;
import 'pilot_test.dart' show start;

Future<void> tapKey(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

String result(WidgetTester t) =>
    t.widget<Text>(find.byKey(const Key('draw-result'))).data!;

void main() {
  testWidgets('a pick comes from the list, and earlier draws stay listed', (
    t,
  ) async {
    await start(t);
    await go(t, 'draw');
    expect(
      t.widget<FilledButton>(find.byKey(const Key('draw-go'))).onPressed,
      isNull,
      reason: 'nothing to pick from yet',
    );
    expect(find.byKey(const Key('draw-needs')), findsOneWidget);
    await type(t, 'draw-list', 'An\nBình\nChi');
    await tapKey(t, 'draw-go');
    final first = result(t);
    expect(['An', 'Bình', 'Chi'], contains(first));
    await tapKey(t, 'draw-go');
    expect(find.text('Earlier draws'), findsOneWidget);
  });

  testWidgets('teams use every name; coin and dice need no list', (t) async {
    await start(t);
    await go(t, 'draw');
    await tapKey(t, 'draw-mode-teams');
    await type(t, 'draw-list', 'An\nBình\nChi\nDũng\nEm');
    await tapKey(t, 'draw-go');
    final teams = result(t).split('\n');
    expect(teams, hasLength(2));
    expect(teams.join(',').split(RegExp(r'[,:]')).length, greaterThan(5));
    await tapKey(t, 'draw-mode-coin');
    await tapKey(t, 'draw-go');
    expect(['Heads', 'Tails'], contains(result(t)));
    await tapKey(t, 'draw-mode-dice');
    await type(t, 'draw-dice', '7d1');
    await tapKey(t, 'draw-go');
    expect(find.byKey(const Key('draw-error')), findsOneWidget);
    await type(t, 'draw-dice', '3d6');
    await tapKey(t, 'draw-go');
    final total = int.parse(result(t).split('= ').last);
    expect(total, inInclusiveRange(3, 18));
  });
}
