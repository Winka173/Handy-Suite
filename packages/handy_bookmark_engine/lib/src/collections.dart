import 'models.dart';
import 'trash.dart';

/// What happens to the items filed directly in a collection that is
/// deleted. Items in its subcollections stay there; the subcollections
/// move up a level.
enum CollectionContents {
  /// They stay, in Not sorted.
  unfile,

  /// They move to another collection ([removeCollection]'s `moveTo`).
  move,

  /// They go to Recently Deleted for [SaveLibrary.trashRetention], and come
  /// back to Not sorted when restored.
  trash,
}

/// Deletes collection [id] for good, at [now]:
///
/// - its subcollections move up a level (to its parent, or to the top);
/// - the items filed directly in it follow [contents];
/// - items of it already in Recently Deleted come back, when restored, to
///   [moveTo] when the others moved there, else to Not sorted;
/// - smart collections and saved filters that named it name [moveTo] when
///   its items moved there; otherwise they are left as they are (and match
///   nothing until edited);
/// - a tombstone is left so a device that syncs later cannot bring it back.
///
/// An unknown [id] changes nothing. [moveTo] must be another collection
/// that exists (one of its own subcollections is fine: they stay).
SaveLibrary removeCollection(
  SaveLibrary library,
  String id, {
  required String now,
  CollectionContents contents = CollectionContents.unfile,
  String? moveTo,
}) {
  final gone = library.collections.where((c) => c.id == id).firstOrNull;
  if (gone == null) return library;
  final moving = contents == CollectionContents.move;
  if (moving &&
      (moveTo == null ||
          moveTo == id ||
          !library.collections.any((c) => c.id == moveTo)))
    throw const FormatException('Move target collection is missing');
  final inside = [
    for (final b in library.bookmarks)
      if (b.collectionId == id) b.id,
  ];
  final base = contents == CollectionContents.trash
      ? moveToTrash(library, inside, now)
      : library;
  final home = moving ? moveTo : null;
  return withCollectionTombstones(
    base.copyWith(
      collections: [
        for (final c in base.collections)
          if (c.id != id)
            c.parentId == id ? c.copyWith(parentId: gone.parentId) : c,
      ],
      bookmarks: [
        for (final b in base.bookmarks)
          b.collectionId == id
              ? b.copyWith(collectionId: home, updatedAt: now, rev: b.rev + 1)
              : b,
      ],
      // Their deletion time stays: a later change time would let this
      // device's copy outlive a deletion for good made elsewhere.
      trash: [
        for (final b in base.trash)
          b.collectionId == id ? b.copyWith(collectionId: home) : b,
      ],
      smartCollections: [
        for (final s in base.smartCollections)
          moving && s.rules.any((r) => _names(r, id))
              ? s.copyWith(
                  rules: [
                    for (final r in s.rules)
                      _names(r, id) ? r.copyWith(value: moveTo) : r,
                  ],
                )
              : s,
      ],
      savedSearches: [
        for (final s in base.savedSearches)
          moving && s.query['collectionId'] == id
              ? s.copyWith(query: {...s.query, 'collectionId': moveTo})
              : s,
      ],
    ),
    [id],
    now,
  );
}

bool _names(SmartRule r, String id) =>
    r.field == 'collectionId' && r.value == id;
