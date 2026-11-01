import 'dart:typed_data';
import 'store_stub.dart'
    if (dart.library.io) 'store_native.dart'
    if (dart.library.js_interop) 'store_web.dart'
    as platform;

abstract interface class BookmarkStore {
  Future<Map<String, dynamic>> read();
  Future<void> write({
    List<Map<String, dynamic>> upserts = const [],
    List<String> deletes = const [],
    Map<String, dynamic>? settings,
    bool replace = false,
  });
  Future<Map<String, dynamic>> search(
    Map<String, dynamic> query, {
    int offset = 0,
    int limit = 100,
  });
  Future<Uint8List?> thumbnail(String id);
  Future<void> putThumbnail(String id, Uint8List bytes);
  Future<void> clearThumbnails();
  Future<String> integrity();
  Future<void> close();
}

Future<BookmarkStore> openBookmarkStore() => platform.openStore();
Future<void> preserveAndResetBookmarkStore() =>
    platform.preserveAndResetStore();
