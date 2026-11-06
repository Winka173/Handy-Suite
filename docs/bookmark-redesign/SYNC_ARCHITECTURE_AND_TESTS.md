# Handy Bookmark: sync architecture and tests

Status (2026-11-06):

- **Protocol and merge:** DONE in the engine, tested with simulated devices.
- **Folder adapter** (a folder a cloud client keeps in step, on Windows, macOS and Linux):
  CODE + host tests. Not tested between two real computers.
- **Native iCloud Drive / Google Drive adapters for iOS and Android:** BLOCKED. They need an
  iCloud container and entitlement (Apple developer account and a Mac with Xcode), a Google
  Cloud OAuth client for Drive's app folder, and two real devices to prove them.

Sync is not backup. Sync keeps devices agreeing, deletions included. A backup is a separate
file that can bring back what sync removed.

## Layout in the person's folder

```
handy-bookmark/
  library.json        {"format":"handy-bookmark-sync","version":1,"library":{…}}
  media/<sha256>      each picture's original bytes, named by their hash
```

The `library` object is `SaveLibrary.toJson()`, the same model the stores and backups use. It
holds items, Recently Deleted, tombstones, collections, smart collections, saved filters, tags
and the manual order.

These stay on each device:

- device settings: theme, language, library name, notifications, sync folder;
- offline reading copies;
- page pictures fetched from sites;
- the store's own bookkeeping.

## One sync (`syncOnce`, `packages/handy_bookmark_engine/lib/src/sync.dart`)

1. Read `library.json` and remember its tag.
2. Merge it with this device's library (`mergeLibraries`).
3. Upload every picture the merged library uses that the folder lacks. Pictures go up before
   the library that names them, so the folder never points at a missing picture.
4. Download every picture the merged library uses that this device lacks. Each download must
   hash to its id, or the sync stops with nothing applied.
5. If the merge differs from what was read, write it with `ifMatch` set to the tag read, or
   `ifAbsent` for the first write.
6. If another device wrote in between (`SyncConflict`), start again from step 1, up to 3 times.
7. The app applies the result with `update((current) => mergeLibraries(current, result))`.
   Anything changed locally during the sync is merged again, not overwritten. The whole result
   is one store write.

## Merge rules

| Thing                                                   | Rule                                                                                                                                                                                                                                                                                          |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Item (link or picture), in the list or Recently Deleted | **Last change wins.** The change time is the later of `updatedAt` and `deletedAt`, then the higher `rev`, then a stable content hash, so every device picks the same version. Moving to Recently Deleted counts as a change. Restoring is a newer change, so a restore beats an older delete. |
| Item deleted for good (tombstone)                       | The tombstone removes any copy that did not change after it. A copy edited elsewhere after the deletion survives, and that tombstone is dropped.                                                                                                                                              |
| Collection, smart collection, saved filter              | These carry no change time. When both sides have one, the folder's version wins. The first device to sync an edit decides, and every device then agrees. Collection tombstones remove the collection. Its items go to Not sorted, and its children become top-level.                          |
| Tags                                                    | Union.                                                                                                                                                                                                                                                                                        |
| Manual order                                            | The folder's order, then this device's additions.                                                                                                                                                                                                                                             |
| Pictures                                                | Content-addressed. Identical pictures are one file, and they never conflict.                                                                                                                                                                                                                  |
| Tombstones                                              | Union, keeping the latest per thing. They are pruned after 365 days (`pruneTombstones`). A device that has been silent longer must restore from a backup.                                                                                                                                     |

Clocks: change times come from each device's clock. A device whose clock is badly wrong can
win or lose edits it should not. This is documented, not hidden.

## Adapters

- `MemorySyncProvider` (engine): the simulated folder. It can drop the connection
  (`failWrites`) and inject another device's write between read and write (`beforeWrite`).
- `FolderSyncProvider` (`apps/handy_bookmark/lib/sync/folder_sync_io.dart`): a folder on disk.
  - A file's tag is the SHA-256 of its bytes, so a write meant for an older version is refused
    even when a cloud client replaced the file in between.
  - Writes go to a temporary file first and are renamed into place.
  - Paths containing `..` are refused.
- iCloud Drive (iOS) and the Google Drive app folder (Android): BLOCKED, see the top.

## In the app

Settings → **Sync between devices**:

- On a computer: choose a synced folder, then **Sync now**. It shows the last time and how many
  pictures were sent and received.
- On phones and the web: a sentence says that this build has no cloud adapter on this device
  yet.

Received pictures are prepared like ones the person added (checked, previewed) and must hash
to their id.

## Tests

Engine, `test/sync_test.dart` (11 tests, simulated devices):

- an item saved on one device reaches the other;
- the later edit wins, and both devices end byte-identical;
- a delete beats an older edit, and a newer edit brings the item back;
- deleted for good stays gone on a device that never saw the deletion, and the tombstone
  propagates;
- a collection deleted on one device sends its items to Not sorted elsewhere;
- pictures travel by content, and an altered picture is refused with nothing stored;
- a write from another device between read and write is merged, not lost (2 attempts);
- a dropped connection changes nothing, and the next sync completes;
- a second sync with nothing new writes nothing;
- items merge the same whichever side is local;
- anything but a sync file is refused.

App, `test/sync_folder_test.dart` (2 tests, real files in a temp folder):

- conditional writes and path checks;
- two controllers meet through one folder: links, a picture (byte-identical original) and a
  deletion travel both ways.

## Next

1. iOS: an iCloud container and an `NSFileCoordinator`-based adapter behind `SyncProvider`.
   Needs a Mac, Xcode and a developer account.
2. Android: the Drive REST `appDataFolder` with OAuth (`drive.appdata` scope) behind
   `SyncProvider`. Needs a Google Cloud project and an OAuth client.
3. Automatic sync on start, on resume and a minute after a change, with the last error shown
   in Settings.
4. Prove it on two real devices, and record the evidence in `docs/qa/evidence` only from real
   runs.
