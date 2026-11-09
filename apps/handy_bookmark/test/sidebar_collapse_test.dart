import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'new_flows_test.dart' show boot, settle;
import 'widget_test.dart' show tapKey;

void main() {
  testWidgets('the wide sidebar folds away and comes back, remembered', (
    t,
  ) async {
    final (c, _) = await boot(t, size: const Size(1280, 800));
    double side() => t.getSize(find.byKey(const Key('bookmark-sidebar'))).width;
    expect(side(), greaterThan(200));
    await tapKey(t, 'side-collapse');
    await settle(t);
    expect(find.byKey(const Key('bookmark-sidebar')), findsNothing);
    expect(find.byKey(const Key('side-open')), findsOneWidget);
    expect(c.preferences['sidebarCollapsed'], isTrue);
    await tapKey(t, 'side-open');
    await settle(t);
    expect(side(), greaterThan(200));
    expect(c.preferences['sidebarCollapsed'], isFalse);
  });
}
