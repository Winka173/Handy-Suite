import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_trip/app.dart';
import 'package:handy_trip/controller.dart';
import 'package:handy_trip/data/store.dart';
import 'package:handy_trip/scope.dart';
import 'package:handy_trip/platform/location.dart';
import 'package:handy_trip/platform/reminders.dart';
import 'package:handy_trip/features/checkins/editor.dart';
import 'package:handy_trip/features/journal/editor.dart';
import 'package:handy_trip/features/expenses/editor.dart';
import 'package:handy_trip/features/bookings/editor.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_files/handy_files.dart';

// Test-only port. Production always uses SQLite/IndexedDB and OS adapters.
class MemoryStore implements TripStore {
  TripState value;
  bool fail = false;
  MemoryStore(this.value);
  @override
  Future<TripState> read() async => value;
  @override
  Future<void> commit(TripState next, {required int expectedRevision}) async {
    if (fail) throw StateError('write refused');
    if (expectedRevision != value.revision) throw StateError('stale');
    value = next;
  }

  @override
  Future<String> integrity() async => 'ok';
}

class DeniedLocation implements ForegroundLocation {
  int calls = 0;
  @override
  Future<CapturedLocation> capture() async {
    calls++;
    throw StateError('denied');
  }
}

TripState sample({String locale = 'en', String theme = 'light'}) => TripState(
  trips: [
    Trip({
      'id': 't',
      'title': 'Three days by the sea',
      'start': '2026-11-01',
      'end': '2026-11-03',
      'zone': 'Asia/Ho_Chi_Minh',
      'currency': 'VND',
      'budget': '2000000',
      'status': 'ongoing',
      'destination': 'A quiet coastal weekend',
      'created': '2026-10-01T00:00:00Z',
      'updated': '2026-10-01T00:00:00Z',
    }),
  ],
  places: [
    Place({
      'id': 'p',
      'name': 'Old town museum',
      'city': 'Da Nang',
      'category': 'attraction',
      'wishlist': true,
    }),
  ],
  stops: [
    Stop({
      'id': 's',
      'trip': 't',
      'place': 'p',
      'title': 'Visit the museum',
      'day': '2026-11-02',
      'time': '09:00',
      'duration': 60,
    }),
  ],
  bookings: [
    Booking({
      'id': 'b',
      'trip': 't',
      'title': 'Coastal guesthouse',
      'start': '2026-11-01T07:20:00Z',
      'end': '2026-11-03T03:45:00Z',
      'zone': 'Asia/Ho_Chi_Minh',
      'type': 'hotel',
      'code': 'PRIVATE-ABC',
      'assets': [],
    }),
  ],
  expenses: [
    Expense({
      'id': 'e',
      'trip': 't',
      'at': '2026-11-02T00:35:00Z',
      'zone': 'Asia/Ho_Chi_Minh',
      'currency': 'VND',
      'minor': '85000',
      'category': 'food',
      'description': 'Breakfast',
    }),
  ],
  notes: [
    JournalNote({
      'id': 'n',
      'trip': null,
      'at': '2026-11-01T02:17:00Z',
      'zone': 'Asia/Ho_Chi_Minh',
      'title': 'Morning light',
      'body': 'A quiet walk before the trip.',
    }),
  ],
  packing: [
    PackItem({
      'id': 'pack',
      'trip': 't',
      'title': 'Water bottle',
      'category': 'Essentials',
      'qty': 1,
    }),
  ],
  settings: {'onboarded': true, 'locale': locale, 'theme': theme},
);
TripScope makeScope(TripController c, {DeniedLocation? location}) => TripScope(
  controller: c,
  files: const SystemHandyFiles(),
  locationPort: location ?? DeniedLocation(),
  reminders: TripReminders(),
  clock: () => DateTime.utc(2026, 11, 2, 2, 30),
);

Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await t.pumpAndSettle();
}

Future<void> editorHost(
  WidgetTester t,
  TripScope scope,
  Future<void> Function(BuildContext) open,
) async {
  await t.pumpWidget(
    HandyApp(
      app: 'trip',
      title: 'Handy Trip',
      accent: const Color(0xff0284c7),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => open(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tap(t, find.text('Open'));
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.trip/share'),
          (call) async => call.method == 'drain' ? [] : true,
        );
  });
  testWidgets(
    'manual visit requires explicit confirmation and cancel never writes',
    (t) async {
      final store = MemoryStore(sample()),
          c = TripController(open: () async => store);
      await c.load();
      final denied = DeniedLocation(),
          scope = makeScope(c, location: denied)..chooseTrip('t');
      await editorHost(
        t,
        scope,
        (context) => editCheckIn(context, scope, stop: c.state!.stops.single),
      );
      await tap(t, find.byKey(const Key('trip-form-save')));
      expect(c.state!.visits, isEmpty);
      expect(find.byKey(const Key('trip-form-save')), findsOneWidget);
      await tap(t, find.text('Cancel'));
      expect(c.state!.visits, isEmpty);
      expect(denied.calls, 0);
      await tap(t, find.text('Open'));
      await tap(t, find.byType(SwitchListTile).first);
      await tap(t, find.byKey(const Key('trip-form-save')));
      expect(c.state!.visits.single.confirmed, isTrue);
      expect(c.state!.stops.single.status, 'visited');
      expect(denied.calls, 0);
      await c.undo();
      expect(c.state!.visits, isEmpty);
      await t.pumpWidget(const SizedBox());
      scope.dispose();
      c.dispose();
    },
  );
  testWidgets(
    'denied GPS offers manual fallback and does not invent coordinates',
    (t) async {
      final c = TripController(open: () async => MemoryStore(sample()));
      await c.load();
      final denied = DeniedLocation(),
          scope = makeScope(c, location: denied)..chooseTrip('t');
      await editorHost(
        t,
        scope,
        (context) => editCheckIn(
          context,
          scope,
          place: c.state!.places.single,
          gps: true,
        ),
      );
      expect(
        find.textContaining('Location unavailable or denied'),
        findsOneWidget,
      );
      await tap(t, find.byKey(const Key('trip-confirm')));
      await tap(t, find.byType(SwitchListTile).first);
      await tap(t, find.byKey(const Key('trip-form-save')));
      expect(c.state!.visits.single.origin, 'manual');
      expect(c.state!.visits.single.data['geo'], isNull);
      expect(denied.calls, 1);
      await t.pumpWidget(const SizedBox());
      scope.dispose();
      c.dispose();
    },
  );
  testWidgets(
    'editing records preserves wall time, original zone and spontaneous ownership',
    (t) async {
      final c = TripController(open: () async => MemoryStore(sample()));
      await c.load();
      final scope = makeScope(c)..chooseTrip('t');
      final note = c.state!.notes.single,
          expense = c.state!.expenses.single,
          booking = c.state!.bookings.single;
      for (final (open, verify)
          in <(Future<void> Function(BuildContext), void Function())>[
            (
              (context) => editNote(context, scope, old: note),
              () {
                expect(
                  DateTime.parse(c.state!.notes.single.at),
                  DateTime.parse(note.at),
                );
                expect(c.state!.notes.single.trip, isNull);
              },
            ),
            (
              (context) => editExpense(context, scope, expense),
              () {
                expect(
                  DateTime.parse(c.state!.expenses.single.at),
                  DateTime.parse(expense.at),
                );
                expect(c.state!.expenses.single.minor, expense.minor);
              },
            ),
            (
              (context) => editBooking(context, scope, booking),
              () {
                expect(
                  DateTime.parse(c.state!.bookings.single.start),
                  DateTime.parse(booking.start),
                );
                expect(
                  DateTime.parse(c.state!.bookings.single.end),
                  DateTime.parse(booking.end),
                );
              },
            ),
          ]) {
        await editorHost(t, scope, open);
        await tap(t, find.byKey(const Key('trip-form-save')));
        verify();
        expect(find.byKey(const Key('trip-form-save')), findsNothing);
      }
      await t.pumpWidget(const SizedBox());
      scope.dispose();
      c.dispose();
    },
  );
  for (final width in [320.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('responsive shell and all areas at $width', (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = TripController(open: () async => MemoryStore(sample()));
      await c.load();
      await t.pumpWidget(TripApp(controller: c));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      for (final label in ['Explore', 'Journal', 'Passport', 'Trips']) {
        await tap(t, find.text(label).last);
        expect(t.takeException(), isNull);
      }
      await tap(t, find.text('Three days by the sea').first);
      for (final label in [
        'Itinerary',
        'Places',
        'Packing',
        'Bookings',
        'Expenses',
        'Journal',
        'Overview',
      ]) {
        await tap(t, find.widgetWithText(ChoiceChip, label));
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
  testWidgets('large text and long trip names remain usable at 320px', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 2;
    final originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      originalErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalErrorHandler);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final data = sample();
    final c = TripController(
      open: () async => MemoryStore(
        data.copy({
          'trips': [
            data.trips.single.copy({
              'title':
                  'A long offline travel daybook with several destinations',
            }).toJson(),
          ],
        }),
      ),
    );
    await c.load();
    await t.pumpWidget(TripApp(controller: c));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await tap(t, find.textContaining('A long offline travel daybook').first);
    expect(t.takeException(), isNull);
    await tap(t, find.widgetWithText(ChoiceChip, 'Bookings'));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });
}
