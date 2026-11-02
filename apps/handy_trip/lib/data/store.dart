import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'store_stub.dart'
    if (dart.library.io) 'store_native.dart'
    if (dart.library.js_interop) 'store_web.dart'
    as platform;

abstract interface class TripStore {
  Future<TripState> read();
  Future<void> commit(TripState next, {required int expectedRevision});
  Future<String> integrity();
}

Future<TripStore> openTripStore() => platform.openStore();
