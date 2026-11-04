import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'pilot_test.dart' show MemoryPreferences, enter, openTool, start;

void main() {
  testWidgets('a tool opened once comes back under Recent', (tester) async {
    final repo = MemoryPreferences();
    await start(tester, repo: repo);
    expect(find.byKey(const Key('recent-salary')), findsNothing);
    await openTool(tester, 'salary');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(repo.state.drafts['recent'], 'salary');
    // The bench rebuilds from the saved settings on the next visit.
    await start(tester, repo: repo);
    expect(find.byKey(const Key('recent-salary')), findsOneWidget);
    await tester.tap(find.byKey(const Key('recent-salary')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recent-salary')), findsNothing);
  });

  testWidgets('a situation chip answers with the right figure', (tester) async {
    await start(tester);
    await tester.tap(find.byKey(const Key('example-1,000,000 + VAT 10%')));
    await tester.pumpAndSettle();
    expect(find.text('1,100,000'), findsOneWidget);
    await enter(tester, '2.400.000 - 15% - 5%');
    expect(find.text('1,938,000'), findsOneWidget);
  });
}
