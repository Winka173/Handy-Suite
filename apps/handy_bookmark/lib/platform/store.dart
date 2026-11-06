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

  /// Offline reading copies live apart from the bookmark rows (schema 2) so
  /// lists never carry their text. Deleted copies are hidden and retained for
  /// [readingUndoRetention]; restoring the same ID and URL restores the copy.
  Future<Map<String, dynamic>?> readingCopy(String id);

  /// Stores copies in one transaction; every id must be a saved bookmark.
  Future<void> putReadingCopies(Map<String, Map<String, dynamic>> copies);
  Future<void> deleteReadingCopy(String id);

  /// Which bookmarks have a copy, with the copy's saved time.
  Future<Map<String, String>> readingIndex();

  /// Every copy, for a full backup.
  Future<Map<String, Map<String, dynamic>>> readingCopies();
  Future<void> clearReadingCopies();
}

/// One stored reading copy may not exceed this many bytes of JSON.
const maxReadingCopyBytes = 2000000;

/// Deleted content is not a cache: retain it for recovery, then prune only the
/// expired deleted copies on a subsequent write. Active articles are untouched.
const readingUndoRetention = Duration(days: 7);

Future<BookmarkStore> openBookmarkStore() => platform.openStore();
Future<void> preserveAndResetBookmarkStore() =>
    platform.preserveAndResetStore();
