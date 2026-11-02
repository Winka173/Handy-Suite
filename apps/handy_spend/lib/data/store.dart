import 'dart:typed_data';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'store_stub.dart'
    if (dart.library.io) 'store_native.dart'
    if (dart.library.js_interop) 'store_web.dart'
    as platform;

abstract interface class SpendStore {
  Future<SpendState> read();
  Future<void> commit(SpendState state, {required int expectedRevision});
  Future<String> integrity();

  /// Receipt bytes live beside the ledger, keyed by receipt ID. A file is
  /// written before the ledger change that lists it, so a failed change
  /// leaves at most an unlisted file, which [sweepReceipts] removes.
  Future<void> putReceipt(String id, Uint8List bytes);
  Future<Uint8List?> readReceipt(String id);

  /// Deletes stored receipt files not in [keep]; returns how many. Run only
  /// when the ledger opens, so an Undo in this session finds its files.
  Future<int> sweepReceipts(Set<String> keep);
}

Future<SpendStore> openSpendStore() => platform.openStore();
