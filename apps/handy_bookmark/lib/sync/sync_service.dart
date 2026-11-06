import 'package:flutter/foundation.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import '../controller.dart';
import '../services/media_import.dart';
export 'folder_sync_stub.dart' if (dart.library.io) 'folder_sync_io.dart';

/// This device's pictures as sync sees them. A received picture is
/// prepared like one the person added (checked, previewed) and must hash
/// to the id it arrived under.
class DeviceSyncMedia implements SyncMedia {
  final SaveController c;
  DeviceSyncMedia(this.c);

  @override
  Future<Uint8List?> original(String id) => c.store!.media(id);

  @override
  Future<void> store(MediaRef ref, Uint8List original) async {
    final p = await compute(
      (({Uint8List bytes, String name}) f) =>
          preparePicture(f.bytes, name: f.name),
      (bytes: original, name: ref.name),
    );
    if (p.ref.id != ref.id)
      throw const FormatException('A synced picture does not match its id');
    await c.store!.putMedia(ref.toJson(), p.original, p.preview);
  }
}

/// Syncs once and applies the result, merging again with anything that
/// changed here meanwhile. Nothing local is replaced before the merge is
/// written to the store in one change.
Future<SyncResult> syncLibrary(SaveController c, SyncProvider remote) async {
  final r = await syncOnce(
    local: c.library!,
    remote: remote,
    media: DeviceSyncMedia(c),
  );
  await c.update((current) => mergeLibraries(current, r.library));
  return r;
}
