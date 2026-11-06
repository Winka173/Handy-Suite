# Migration, backup and Trash

- **Schema:** SQLite schema 4 and IndexedDB 4 are unchanged. The portable format stays at
  version 2 or 3 (an optional key was added, nothing removed); older readers ignore new keys.
- **Renamed titles:** stored in the existing `title` field with `metadataSource: 'user'`. No new
  column. A refresh keeps user titles; a ZIP round trip and a Trash restore keep them (tests in
  `rename_share_test.dart`).
- **collectionViews:**
  - backups carry `cards`, `sort` and the new `cover` (`readCollectionViews` keeps `cover` only
    when it names an item in the file; a merge remaps it, and a duplicate points at the link
    already saved);
  - folder sync carries no preferences, so views stay on the device where they were set.
- **Offline copies in Trash:**
  - now included in ZIP and JSON backups, and restored beside their Trash item (expiry is the
    deletion date + 30 days); they come back on restore;
  - formats that cannot carry copies (CSV, HTML, MD, TXT) count them in the omission report;
  - copies kept only for the 7-day Undo of a plain delete are still left out.
- **Pictures:** originals and previews go in ZIP. The automatic backup records what it left out
  (too large, missing, unreadable, format) and is only called complete when nothing was.
  Picture cleanup never removes media used by a live or Trash item, or media stored in the last
  10 minutes.
- **Housekeeping:** `SaveController.tidy()` runs at open and before each automatic backup:
  - Trash older than 30 days expires;
  - tombstones older than 365 days are pruned, counted back from the earlier of now and the
    newest change, so a fast clock cannot drop recent ones;
  - unused pictures are reclaimed.
- **Resurrection risk:**
  - a device offline for less than 365 days cannot bring a deleted item back (tested with
    `mergeLibraries`);
  - after 365 days a deleted item can reappear. Nothing is lost, but deletion is not
    guaranteed beyond the horizon;
  - not built: refusing a plain merge for a device whose last sync is older than the horizon
    (belongs in `lib/sync/sync_service.dart`).
- **Deleting a collection:** `removeCollection` offers three choices (leave items in Not
  sorted, move them to another collection, or send them to Trash):
  - subcollections move up a level;
  - Trash items of the deleted collection follow the move target, otherwise go to Not sorted;
  - smart collections and saved filters naming it follow the move;
  - a tombstone is written.
  - The UI now uses it, which fixes a crash when moving to another collection while
    subcollections existed.
  - The collection tree itself is not restorable from Trash; the sheet's copy says what
    happens to items.
- **Damaged trees:** loading repairs a missing parent (moved to the top), a cycle (cut) and an
  item filed in a missing collection (moved to Not sorted), instead of failing to open.
