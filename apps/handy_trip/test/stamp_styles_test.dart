import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_trip/app.dart';
import 'package:handy_trip/controller.dart';
import 'package:handy_trip/features/passport/stamp_design.dart';
import 'package:handy_trip/features/passport/stamp_styles.dart';
import 'package:handy_ui/kit.dart';
import 'ui_test.dart' show MemoryStore, sample, tap;

void main() {
  test('40 styles in 7 families, none differing by ink alone', () {
    expect(stampStyles, hasLength(40));
    expect(stampStyles.map((s) => s.id).toSet(), hasLength(40));
    expect(stampStyles.map((s) => s.signature).toSet(), hasLength(40));
    for (final f in stampFamilies.keys) {
      expect(
        stampStyles.where((s) => s.family == f).length,
        greaterThanOrEqualTo(4),
        reason: f,
      );
    }
    expect(stampStyle('from-a-newer-app').id, 'travel-ring');
  });

  testWidgets('every style draws a stamp with Vietnamese words', (t) async {
    await t.runAsync(() async {
      for (final st in stampStyles) {
        final png = await renderStampPng(
          const StampDesign(
            place: 'Phố cổ Hội An',
            day: '2026-11-02',
            trip: 'Ba ngày ở biển',
          ).withStyle(st),
          side: 200,
        );
        final frame = await (await ui.instantiateImageCodec(
          png,
        )).getNextFrame();
        expect(frame.image.width, 200, reason: st.id);
        frame.image.dispose();
      }
    });
  });

  testWidgets('a kept stamp shows in the Passport and reopens as it was', (
    t,
  ) async {
    t.view.physicalSize = const Size(1024, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = TripController(open: () async => MemoryStore(sample()));
    await c.load();
    await t.pumpWidget(
      TripApp(controller: c, clock: () => DateTime.utc(2026, 11, 2, 9)),
    );
    await t.pumpAndSettle();
    await tap(t, find.text('Trips').last);
    await tap(t, find.text('Three days by the sea').first);
    await tap(t, find.widgetWithText(ChoiceChip, 'Itinerary'));
    await tap(t, find.byKey(const Key('stop-visited-s')));
    final visit = c.state!.visits.single.key;
    await tap(t, find.text('Passport').last);
    expect(find.text('Your stamps'), findsOneWidget);
    await tap(t, find.byTooltip('Personal memory stamp').first);
    await tap(t, find.byKey(const Key('stamp-family-postmark')));
    await tap(t, find.byKey(const Key('stamp-style-postmark-round')));
    await tap(t, find.byKey(const Key('stamp-keep')));
    final kept = c.state!.visits.single.stamp!;
    expect(kept['style'], 'postmark-round');
    expect(kept['ink'], stampStyle('postmark-round').ink);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Your stamps · 1'), findsOneWidget);
    await tap(t, find.byKey(Key('stamp-tile-$visit')));
    // Opens on the kept style's family.
    final chip = t.widget<ChoiceChip>(
      find.byKey(const Key('stamp-family-postmark')),
    );
    expect(chip.selected, isTrue);
  });
}
