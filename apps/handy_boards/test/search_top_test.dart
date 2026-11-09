import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'kanban_app_test.dart';

void main() {
  for (final size in [const Size(400, 860), const Size(1280, 900)]) {
    testWidgets(
      'search opens in the top bar; the board does not move (${size.width})',
      (t) async {
        await boot(t, studyState(), size: size);
        await tap(t, find.text('Semester 1').first);
        await settle(t);
        final band = find.byKey(const Key('board-band'));
        final before = t.getTopLeft(band);
        await tap(t, find.byKey(const Key('board-search')));
        await settle(t);
        final field = find.byKey(const Key('board-search-field'));
        expect(field, findsOneWidget);
        expect(t.getTopLeft(band), before);
        expect(
          t.getCenter(field).dy,
          closeTo(t.getCenter(find.byKey(const Key('board-search'))).dy, 12),
        );
        await tap(t, find.byKey(const Key('board-search')));
        await settle(t);
        expect(field, findsNothing);
        expect(t.getTopLeft(band), before);
      },
    );
  }
}
