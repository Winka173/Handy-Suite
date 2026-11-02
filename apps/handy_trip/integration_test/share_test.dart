import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_trip/app.dart';
import 'package:handy_trip/controller.dart';
import 'package:handy_trip/data/store_native.dart';
import 'package:handy_trip/platform/share_inbox.dart';
import '../test/ui_test.dart' as fixtures;
import 'native_test.dart' show complete;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'OS text share stays queued on cancel, saves manually, then acknowledges',
    (t) async {
      final dir = (await t.runAsync(getApplicationSupportDirectory))!;
      final store = NativeTripStore('${dir.path}/handy-trip-share-qa.sqlite');
      final c = TripController(open: () async => store);
      await t.runAsync(c.load);
      await t.runAsync(
        () => c.change(
          (s) => s.copy({
            'settings': {'onboarded': true, 'locale': 'en'},
          }),
        ),
      );
      final inbox = TripShareInbox();
      final pending = (await t.runAsync(inbox.pending))!;
      expect(
        pending,
        isNotEmpty,
        reason:
            'Send a real ACTION_SEND to the dedicated emulator before this run',
      );
      final originalCount = c.state!.places.length;
      await t.pumpWidget(TripApp(controller: c));
      await t.pumpAndSettle();
      await fixtures.tap(t, find.text('Review').first);
      await fixtures.tap(t, find.text('Cancel'));
      expect((await t.runAsync(inbox.pending))!.length, pending.length);
      expect(c.state!.places.length, originalCount);
      await fixtures.tap(t, find.text('Review').first);
      await t.enterText(
        find.byKey(const Key('field-name')),
        'Shared user-confirmed place',
      );
      await t.tap(find.byKey(const Key('trip-form-save')));
      await complete(t, () => c.state!.places.length == originalCount + 1);
      for (var n = 0; n < 100; n++) {
        if ((await t.runAsync(inbox.pending))!.length == pending.length - 1)
          break;
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await t.pump();
      }
      expect((await t.runAsync(inbox.pending))!.length, pending.length - 1);
      final saved = c.state!.places.firstWhere(
        (p) => p.data['shareId'] == pending.first.id,
      );
      expect(saved.name, 'Shared user-confirmed place');
      expect(saved.geo, isNull);
      expect(saved.url, startsWith('https://example.com/'));
      expect(c.state!.visits, isEmpty);
      final fresh = (await t.runAsync(
        () => NativeTripStore(store.path).read(),
      ))!;
      expect(fresh.place(saved.key).toJson(), saved.toJson());
      await fixtures.tap(t, find.text('Explore').last);
      if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
      await t.pumpAndSettle();
      await binding.takeScreenshot('trip-native-share-confirmed');
      binding.reportData = {
        ...binding.reportData ?? {},
        'share': 'real Android ACTION_SEND; cancel/commit/ack/reopen',
        'manualGeoConfirmation': true,
        'physicalDevice': false,
      };
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
