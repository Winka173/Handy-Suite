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

abstract interface class IncrementalHabitStore implements HabitStore {
  Future<void> commitDelta(
    HabitState previous,
    HabitState next, {
    required int expectedRevision,
  });
}

/// Recovery is device-local, excluded from ordinary backups and imports.
abstract interface class RecoverableHabitStore implements HabitStore {
  Future<void> saveRecovery({required int expectedRevision});
  Future<HabitState?> readRecovery();
}

Future<HabitStore> openHabitStore() => platform.openStore();
