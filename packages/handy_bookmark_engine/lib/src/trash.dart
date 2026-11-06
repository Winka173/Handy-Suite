import 'models.dart';

/// Recently Deleted. Deleting moves an item, whole, into [SaveLibrary.trash]
/// with its deletion time; restoring brings back the same item (same ID,
/// dates, tags, note, picture); deleting for good leaves a [Tombstone] so a
/// device that was offline cannot bring it back. Nothing here runs on a
/// timer: expiry happens when [expireTrash] is called at a defined moment
/// (opening the library, before a backup or a sync).

/// When [b], deleted at [Bookmark.deletedAt], leaves Recently Deleted.
DateTime trashExpiry(
  Bookmark b, {
  Duration retention = SaveLibrary.trashRetention,
}) => DateTime.parse(b.deletedAt!).add(retention);

/// Whole days left before [b] goes for good, counted from UTC instants so
/// a change of time zone or a clock moved back never adds days. 0 means it
/// goes at the next check; never more than [retention] in days.
int trashDaysLeft(
  Bookmark b,
  DateTime now, {
  Duration retention = SaveLibrary.trashRetention,
}) {
  final left = trashExpiry(b, retention: retention).difference(now.toUtc());
  if (left <= Duration.zero) return 0;
  // A clock set before the deletion never shows more than the retention.
  final days = (left.inHours + 23) ~/ 24;
  return days > retention.inDays ? retention.inDays : days;
}

/// Moves [ids] into Recently Deleted at [now]. Items already in Trash or
/// unknown are ignored. The manual order forgets them.
SaveLibrary moveToTrash(SaveLibrary library, Iterable<String> ids, String now) {
  final wanted = ids.toSet();
  if (wanted.isEmpty) return library;
  final moved = <Bookmark>[];
  final kept = <Bookmark>[];
  for (final b in library.bookmarks) {
    if (wanted.contains(b.id)) {
      moved.add(b.copyWith(deletedAt: now, rev: b.rev + 1));
    } else {
      kept.add(b);
    }
  }
  if (moved.isEmpty) return library;
  return library.copyWith(
    bookmarks: kept,
    trash: [...moved, ...library.trash],
    manualOrder: [
      for (final id in library.manualOrder)
        if (!wanted.contains(id)) id,
    ],
  );
}

/// Brings [ids] back from Recently Deleted as they were, at [now]. An item
/// whose collection was deleted meanwhile goes to Not sorted (or to
/// [collectionId] when the person picked one). Restoring is a new change
/// ([Bookmark.rev] increases), not an undo of history.
SaveLibrary restoreFromTrash(
  SaveLibrary library,
  Iterable<String> ids,
  String now, {
  String? collectionId,
}) {
  final wanted = ids.toSet();
  final known = {for (final c in library.collections) c.id};
  if (collectionId != null && !known.contains(collectionId))
    throw const FormatException('Restore target collection is missing');
  final back = <Bookmark>[];
  final stay = <Bookmark>[];
  for (final b in library.trash) {
    if (!wanted.contains(b.id)) {
      stay.add(b);
      continue;
    }
    final home =
        collectionId ??
        (b.collectionId != null && known.contains(b.collectionId)
            ? b.collectionId
            : null);
    back.add(
      b.copyWith(
        deletedAt: null,
        collectionId: home,
        updatedAt: now,
        rev: b.rev + 1,
      ),
    );
  }
  if (back.isEmpty) return library;
  return library.copyWith(
    bookmarks: [...library.bookmarks, ...back],
    trash: stay,
  );
}

/// Deletes [ids] from Recently Deleted for good, leaving tombstones.
/// Pictures they used are freed only if nothing else uses them
/// ([mediaInUse]); the store reclaims them.
SaveLibrary purgeTrash(SaveLibrary library, Iterable<String> ids, String now) {
  final wanted = ids.toSet();
  final gone = [
    for (final b in library.trash)
      if (wanted.contains(b.id)) b,
  ];
  if (gone.isEmpty) return library;
  return library.copyWith(
    trash: [
      for (final b in library.trash)
        if (!wanted.contains(b.id)) b,
    ],
    tombstones: _withTombstones(library.tombstones, [
      for (final b in gone)
        Tombstone(entity: 'bookmark', id: b.id, deletedAt: now),
    ]),
  );
}

/// Empties Recently Deleted.
SaveLibrary emptyTrash(SaveLibrary library, String now) =>
    purgeTrash(library, [for (final b in library.trash) b.id], now);

/// Deletes for good what has been in Recently Deleted for [retention] or
/// longer at [now]. Returns the library unchanged (identical) when nothing
/// expired, so callers can skip a write.
SaveLibrary expireTrash(
  SaveLibrary library,
  DateTime now, {
  Duration retention = SaveLibrary.trashRetention,
}) {
  final at = now.toUtc();
  final expired = [
    for (final b in library.trash)
      if (!trashExpiry(b, retention: retention).isAfter(at)) b.id,
  ];
  if (expired.isEmpty) return library;
  return purgeTrash(library, expired, at.toIso8601String());
}

List<Tombstone> _withTombstones(List<Tombstone> old, List<Tombstone> added) {
  final ids = {for (final t in added) '${t.entity}:${t.id}'};
  return [
    for (final t in old)
      if (!ids.contains('${t.entity}:${t.id}')) t,
    ...added,
  ];
}

/// Records collections deleted for good (for sync).
SaveLibrary withCollectionTombstones(
  SaveLibrary library,
  Iterable<String> ids,
  String now,
) => library.copyWith(
  tombstones: _withTombstones(library.tombstones, [
    for (final id in ids)
      Tombstone(entity: 'collection', id: id, deletedAt: now),
  ]),
);

/// Tombstones older than [age] are dropped: a device silent that long
/// must restore from a backup rather than sync.
SaveLibrary pruneTombstones(
  SaveLibrary library,
  DateTime now, {
  Duration age = const Duration(days: 365),
}) {
  final cutoff = now.toUtc().subtract(age);
  final kept = [
    for (final t in library.tombstones)
      if (DateTime.parse(t.deletedAt).isAfter(cutoff)) t,
  ];
  return kept.length == library.tombstones.length
      ? library
      : library.copyWith(tombstones: kept);
}

/// Every picture a live or recently deleted item uses. A picture outside
/// this set may be reclaimed; one inside it never is.
Set<String> mediaInUse(SaveLibrary library) => {
  for (final b in library.bookmarks)
    if (b.media != null) b.media!.id,
  for (final b in library.trash)
    if (b.media != null) b.media!.id,
};
