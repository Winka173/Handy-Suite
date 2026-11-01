import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'store_stub.dart'
    if (dart.library.io) 'store_native.dart'
    if (dart.library.js_interop) 'store_web.dart'
    as platform;

abstract interface class SpendStore {
  Future<SpendState> read();
  Future<void> commit(SpendState state, {required int expectedRevision});
  Future<String> integrity();
}

Future<SpendStore> openSpendStore() => platform.openStore();
