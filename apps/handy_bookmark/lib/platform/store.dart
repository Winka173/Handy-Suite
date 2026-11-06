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

    /// Recently Deleted rows, written in the same transaction. An id in
    /// [deletes] and [trashUpserts] moves into Trash with its offline copy;
    /// an id in [trashDeletes] and [upserts] is restored with it.
    List<Map<String, dynamic>> trashUpserts = const [],
    List<String> trashDeletes = const [],
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

  /// Stores copies in one transaction; every id must be a saved item or one
  /// in Recently Deleted. A copy of a Trash item waits beside it (as one
  /// deleted here would) and comes back when the item is restored.
  Future<void> putReadingCopies(Map<String, Map<String, dynamic>> copies);
  Future<void> deleteReadingCopy(String id);

  /// Which bookmarks have a copy, with the copy's saved time.
  Future<Map<String, String>> readingIndex();

  /// Every copy, for a full backup: of saved items, and of items in
  /// Recently Deleted (they are restorable, so their copies are too). Not
  /// the copies kept only for the short Undo window of other deletes.
  Future<Map<String, Map<String, dynamic>>> readingCopies();
  Future<void> clearReadingCopies();

  /// Stores a picture the person owns (content-addressed: storing the same
  /// one again does nothing). Call before writing the item that uses it.
  Future<void> putMedia(
    Map<String, dynamic> ref,
    Uint8List original,
    Uint8List preview,
  );

  /// The original bytes, or the small preview.
  Future<Uint8List?> media(String id, {bool preview = false});

  /// Every stored picture with its original size in bytes.
  Future<Map<String, int>> mediaIndex();

  /// Reclaims pictures that neither [keep], an item, nor a Trash item uses
  /// and that were stored more than [grace] ago. Returns how many went.
  Future<int> collectMedia(Set<String> keep, {Duration grace = mediaGrace});
}

/// Deleted items wait this long in Recently Deleted (the engine's rule).
const trashRetention = Duration(days: 30);

/// A picture stored this recently is never reclaimed: its item may still
/// be on its way to the database.
const mediaGrace = Duration(minutes: 10);

/// A preview may not exceed this many bytes.
const maxMediaPreviewBytes = 600 * 1024;

/// Refuses a picture whose record and bytes disagree, before any write.
void checkMedia(
  Map<String, dynamic> ref,
  Uint8List original,
  Uint8List preview,
) {
  if (original.isEmpty || original.length != ref['bytes'])
    throw const FormatException('Picture size does not match its record');
  if (original.length > 25 * 1024 * 1024)
    throw const FormatException('Picture too large');
  if (preview.isEmpty || preview.length > maxMediaPreviewBytes)
    throw const FormatException('Preview too large');
}

/// One stored reading copy may not exceed this many bytes of JSON.
const maxReadingCopyBytes = 2000000;

/// Deleted content is not a cache: retain it for recovery, then prune only the
/// expired deleted copies on a subsequent write. Active articles are untouched.
const readingUndoRetention = Duration(days: 7);

Future<BookmarkStore> openBookmarkStore() => platform.openStore();
Future<void> preserveAndResetBookmarkStore() =>
    platform.preserveAndResetStore();
