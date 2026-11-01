import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'store_stub.dart'
    if (dart.library.io) 'store_native.dart'
    if (dart.library.js_interop) 'store_web.dart'
    as platform;

abstract interface class HabitStore {
  Future<HabitState> read();
  Future<void> commit(HabitState state, {required int expectedRevision});
  Future<String> integrity();
}

Future<HabitStore> openHabitStore() => platform.openStore();
