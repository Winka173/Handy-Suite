import 'package:flutter_test/flutter_test.dart';
import 'package:handy_trip/app.dart';
import 'package:handy_trip/controller.dart';
import 'package:handy_ui/kit.dart';
import 'ui_test.dart' show MemoryStore, sample, tap;

void main() {
  testWidgets('a stop is marked visited in one tap, and Edit opens the form', (
    t,
  ) async {
    t.view.physicalSize = const Size(1024, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = TripController(open: () async => MemoryStore(sample()));
    await c.load();
    // Today is day 2, the museum stop's day.
    await t.pumpWidget(
      TripApp(controller: c, clock: () => DateTime.utc(2026, 11, 2, 9)),
    );
    await t.pumpAndSettle();
    await tap(t, find.text('Trips').last);
    await tap(t, find.text('Three days by the sea').first);
    await tap(t, find.widgetWithText(ChoiceChip, 'Itinerary'));
    expect(c.state!.visits, isEmpty);
    await tap(t, find.byKey(const Key('stop-visited-s')));
    final v = c.state!.visits.single;
    expect(v.confirmed, isTrue);
    expect(v.place, 'p');
    expect(v.stop, 's');
    expect(find.textContaining('Visited:'), findsOneWidget);
    // Confirmed now: the one-tap button gives way to the record.
    expect(find.byKey(const Key('stop-visited-s')), findsNothing);
    await tap(t, find.byKey(const Key('quick-checkin-edit')));
    expect(find.text('Edit visit'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
}
