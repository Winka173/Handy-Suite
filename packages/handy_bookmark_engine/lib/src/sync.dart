import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'models.dart';
import 'trash.dart';

/// Sync between devices through a folder the person owns (their iCloud
/// Drive or Google Drive app folder). This is not a backup: it keeps
/// devices agreeing, deletions included, and a backup is still a separate
/// file. Layout under [syncRoot]:
///
/// - `library.json`: the merged library (items, Recently Deleted,
///   tombstones, collections, smart collections, saved filters, tags,
///   manual order) in [syncFormat];
/// - `media/<sha256>`: each picture's original bytes, named by content.
///
/// Device settings (theme, library name, notifications), offline reading
/// copies and fetched page pictures stay on each device.
const syncRoot = 'handy-bookmark';
const syncFormat = 'handy-bookmark-sync';
const syncVersion = 1;

/// The remote changed between reading and writing it.
class SyncConflict implements Exception {
  const SyncConflict();
  @override
  String toString() => 'SyncConflict';
}

/// A remote file and the version tag to write against.
class RemoteFile {
  final Uint8List bytes;
  final String etag;
  const RemoteFile(this.bytes, this.etag);
}

/// The person's cloud folder. Adapters (iCloud Drive, Google Drive) and
/// the in-memory test provider implement it. Paths are relative to the
/// app's own folder there.
abstract class SyncProvider {
  /// The file, or null when there is none.
  Future<RemoteFile?> read(String path);

  /// Writes [bytes]; with [ifMatch] only when the file is still at that
  /// tag, with [ifAbsent] only when there is no file (else [SyncConflict]).
  /// Returns the new tag.
  Future<String> write(
    String path,
    Uint8List bytes, {
    String? ifMatch,
    bool ifAbsent = false,
  });

  /// Names directly under [folder].
  Future<Set<String>> list(String folder);
}

/// The device's own pictures, as sync needs them.
abstract class SyncMedia {
  Future<Uint8List?> original(String id);

  /// Stores a picture received from another device (already checked
  /// against its id).
  Future<void> store(MediaRef ref, Uint8List original);
}

/// When a record last changed: its edit, or its move to Recently Deleted.
String changedAt(Bookmark b) =>
    b.deletedAt != null && b.deletedAt!.compareTo(b.updatedAt) > 0
    ? b.deletedAt!
    : b.updatedAt;

String _hash(Object json) =>
    sha256.convert(utf8.encode(jsonEncode(json))).toString();

/// The newer of two versions of one item: later change, then higher
/// revision, then a stable tie-break on content (so every device picks
/// the same one).
Bookmark newer(Bookmark a, Bookmark b) {
  final t = changedAt(a).compareTo(changedAt(b));
  if (t != 0) return t > 0 ? a : b;
  if (a.rev != b.rev) return a.rev > b.rev ? a : b;
  return _hash(a.toJson()).compareTo(_hash(b.toJson())) >= 0 ? a : b;
}

/// Merges this device's library with the one in the folder. Items follow
/// last change wins ([newer]); a tombstone removes an item that did not
/// change after it; collections, smart collections and saved filters
/// (which carry no change time) keep the folder's version when both have
/// one, so the first device to sync a conflicting edit decides and every
/// device then agrees. Tags are joined; the manual order is the folder's
/// with this device's additions after it.
SaveLibrary mergeLibraries(SaveLibrary local, SaveLibrary remote) {
  // Tombstones: one per thing, the latest.
  final graves = <String, Tombstone>{};
  for (final t in [...remote.tombstones, ...local.tombstones]) {
    final key = '${t.entity}:${t.id}';
    final old = graves[key];
    if (old == null || t.deletedAt.compareTo(old.deletedAt) > 0)
      graves[key] = t;
  }
  // Items: the newer of each, wherever it lives (list or Recently Deleted).
  final items = <String, Bookmark>{};
  for (final b in [
    ...remote.bookmarks,
    ...remote.trash,
    ...local.bookmarks,
    ...local.trash,
  ]) {
    final old = items[b.id];
    items[b.id] = old == null ? b : newer(old, b);
  }
  for (final id in [...items.keys]) {
    final grave = graves['bookmark:$id'];
    if (grave == null) continue;
    if (grave.deletedAt.compareTo(changedAt(items[id]!)) >= 0) {
      items.remove(id);
    } else {
      // Edited elsewhere after it was deleted for good: it lives on.
      graves.remove('bookmark:$id');
    }
  }
  // Collections: the folder's version wins a clash; tombstones remove.
  final collections = <String, SaveCollection>{
    for (final c in local.collections) c.id: c,
    for (final c in remote.collections) c.id: c,
  }..removeWhere((id, _) => graves.containsKey('collection:$id'));
  // A parent that is gone makes its children top-level.
  final cols = [
    for (final c in collections.values)
      c.parentId != null && !collections.containsKey(c.parentId)
          ? SaveCollection(
              id: c.id,
              name: c.name,
              color: c.color,
              icon: c.icon,
              description: c.description,
              position: c.position,
            )
          : c,
  ];
  final known = {for (final c in cols) c.id};
  Bookmark home(Bookmark b) =>
      b.collectionId != null && !known.contains(b.collectionId)
      ? b.copyWith(collectionId: null)
      : b;
  final live = <Bookmark>[], deleted = <Bookmark>[];
  for (final b in items.values) {
    (b.deletedAt == null ? live : deleted).add(home(b));
  }
  // Remote order first so devices converge.
  live.sort((a, b) => a.savedAt.compareTo(b.savedAt));
  deleted.sort((a, b) => (b.deletedAt ?? '').compareTo(a.deletedAt ?? ''));
  final smart = {
    for (final s in local.smartCollections) s.id: s,
    for (final s in remote.smartCollections) s.id: s,
  };
  final searches = {
    for (final s in local.savedSearches) s.id: s,
    for (final s in remote.savedSearches) s.id: s,
  };
  return SaveLibrary(
    tags: {...remote.tags, ...local.tags}.toList(),
    bookmarks: live,
    collections: cols,
    smartCollections: smart.values.toList(),
    savedSearches: searches.values.toList(),
    manualOrder: [
      ...remote.manualOrder,
      for (final id in local.manualOrder)
        if (!remote.manualOrder.contains(id)) id,
    ],
    trash: deleted,
    tombstones: graves.values.toList(),
  );
}

Uint8List encodeSyncLibrary(SaveLibrary library) => Uint8List.fromList(
  utf8.encode(
    jsonEncode({
      'format': syncFormat,
      'version': syncVersion,
      'library': library.toJson(),
    }),
  ),
);

SaveLibrary decodeSyncLibrary(Uint8List bytes) {
  final json = jsonDecode(utf8.decode(bytes));
  if (json is! Map ||
      json['format'] != syncFormat ||
      json['version'] != syncVersion ||
      json['library'] is! Map)
    throw const FormatException('Not a Handy Bookmark sync file');
  return SaveLibrary.fromJson(
    Map<String, dynamic>.from(json['library'] as Map),
  );
}

/// What one sync did.
class SyncResult {
  final SaveLibrary library;
  final int picturesSent, picturesReceived, attempts;
  final bool wrote;
  const SyncResult({
    required this.library,
    required this.picturesSent,
    required this.picturesReceived,
    required this.attempts,
    required this.wrote,
  });
}

/// One sync: read the folder, merge, send pictures the folder lacks,
/// fetch pictures this device lacks (each checked against its id), then
/// write the merged library only if it differs, against the version read.
/// A concurrent write from another device is retried from the start, up
/// to [attempts] times. Pictures go up before the library that needs them,
/// so the folder never names a picture it does not hold.
///
/// The caller applies [SyncResult.library] by merging it once more with
/// whatever changed locally meanwhile ([mergeLibraries] is safe to repeat).
Future<SyncResult> syncOnce({
  required SaveLibrary local,
  required SyncProvider remote,
  required SyncMedia media,
  int attempts = 3,
}) async {
  for (var attempt = 1; attempt <= attempts; attempt++) {
    final file = await remote.read('$syncRoot/library.json');
    final theirs = file == null ? null : decodeSyncLibrary(file.bytes);
    final merged = theirs == null ? local : mergeLibraries(local, theirs);
    final needed = mediaInUse(merged);
    final refs = {
      for (final b in [...merged.bookmarks, ...merged.trash])
        if (b.media != null) b.media!.id: b.media!,
    };
    final there = await remote.list('$syncRoot/media');
    var sent = 0, received = 0;
    for (final id in needed) {
      if (there.contains(id)) continue;
      final bytes = await media.original(id);
      if (bytes == null) continue;
      await remote.write('$syncRoot/media/$id', bytes);
      sent++;
    }
    for (final id in needed) {
      if (await media.original(id) != null) continue;
      final blob = await remote.read('$syncRoot/media/$id');
      if (blob == null) continue;
      if (sha256.convert(blob.bytes).toString() != id)
        throw const FormatException('A synced picture does not match its id');
      await media.store(refs[id]!, blob.bytes);
      received++;
    }
    final same =
        theirs != null && _hash(theirs.toJson()) == _hash(merged.toJson());
    if (same) {
      return SyncResult(
        library: merged,
        picturesSent: sent,
        picturesReceived: received,
        attempts: attempt,
        wrote: false,
      );
    }
    try {
      await remote.write(
        '$syncRoot/library.json',
        encodeSyncLibrary(merged),
        ifMatch: file?.etag,
        ifAbsent: file == null,
      );
      return SyncResult(
        library: merged,
        picturesSent: sent,
        picturesReceived: received,
        attempts: attempt,
        wrote: true,
      );
    } on SyncConflict {
      if (attempt == attempts) rethrow;
    }
  }
  throw const SyncConflict();
}

/// A folder kept in memory: the simulated provider used by tests and by
/// the in-app "try sync between two simulated devices" check. [failWrites]
/// makes the next writes throw (a dropped connection);
/// [beforeWrite] runs just before a library write lands (to inject a
/// concurrent change).
class MemorySyncProvider implements SyncProvider {
  final files = <String, (Uint8List, String)>{};
  int _tag = 0, failWrites = 0, writes = 0;
  Future<void> Function()? beforeWrite;

  @override
  Future<RemoteFile?> read(String path) async {
    final f = files[path];
    return f == null ? null : RemoteFile(f.$1, f.$2);
  }

  @override
  Future<String> write(
    String path,
    Uint8List bytes, {
    String? ifMatch,
    bool ifAbsent = false,
  }) async {
    if (failWrites > 0) {
      failWrites--;
      throw StateError('Connection lost');
    }
    if (path.endsWith('library.json') && beforeWrite != null) {
      final hook = beforeWrite!;
      beforeWrite = null;
      await hook();
    }
    final old = files[path];
    if (ifAbsent && old != null) throw const SyncConflict();
    if (ifMatch != null && old?.$2 != ifMatch) throw const SyncConflict();
    final tag = 'v${++_tag}';
    files[path] = (Uint8List.fromList(bytes), tag);
    writes++;
    return tag;
  }

  @override
  Future<Set<String>> list(String folder) async => {
    for (final p in files.keys)
      if (p.startsWith('$folder/')) p.substring(folder.length + 1),
  };
}
