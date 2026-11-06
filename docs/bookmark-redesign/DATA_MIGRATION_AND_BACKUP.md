# Handy Bookmark: data, migration and backup

Three version numbers, never conflated:

| Layer                                              | Before | Now | What changed                                                                                                                                                                                                  |
| -------------------------------------------------- | ------ | --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Native SQLite `user_version` (`handy-save.sqlite`) | 3      | 4   | `bookmarks.kind` (default `link`), `bookmarks.media_id`, tables `trash` and `media`, indexes `idx_kind`, `idx_media`, `idx_trash_media`; full-text index rebuilt once with text that ignores Vietnamese marks |
| Web IndexedDB (`handy-save-bookmarks`)             | 3      | 4   | stores `trash` and `media` added; no record rewritten                                                                                                                                                         |
| Library / portable state (`handy-save`)            | 2      | 3   | items: `kind`, `media`, `deletedAt`, `rev`; library: `trash`, `tombstones`. Written as 3 only when one of these is used, so a library without pictures or deleted items stays 2                               |

Database and key names (`handy-save*`) keep their old names on purpose.

## Upgrade rules

- Native: additive steps 1 → 2 (reading copies) → 3 (deleted-copy retention) → 4, in one
  transaction; a newer database than the app knows is refused without changing its bytes.
- Web: `onupgradeneeded` creates missing stores only.
- Library 1, 2 and 3 read; 4 and later are refused.

## Pictures (owned media)

- A picture the person adds (an image item, or a link's chosen preview) is user data:
  stored once by the SHA-256 of its original bytes, original plus a small preview, in the
  `media` table (SQLite BLOB, in the database file) or `media` store (raw bytes in
  IndexedDB). Fetched page thumbnails stay a separate, disposable 20 MB cache.
- Limits: original ≤ 25 MB, preview ≤ 600 KB; record and bytes must agree before any write.
- Reclaimed only by an explicit collection that keeps every picture an item or a Trash item
  uses, plus any stored in the last 10 minutes (its item may still be on its way).

## Recently Deleted

- Delete moves an item, whole, into Trash for 30 days. Its offline copy moves with it (kept
  30 days instead of the 7-day Undo window) and comes back on restore with the same ID and
  address. Delete for good drops the copy and leaves a tombstone for sync.
- Expiry happens at defined moments with an explicit clock (opening the library, before a
  backup or sync), not on a background timer.

## Tests (Windows host)

| Test                                                                                    | Covers                                                                                                                                                                                                                |
| --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `apps/handy_bookmark/test/store_v4_test.dart` (native SQLite)                           | 3 → 4 with active and retained copies; Trash with copy for 30 days, restore, purge, across reopen; pictures stored once, exact bytes, reference-safe collection with grace; kind filter; accent-free full-text search |
| `apps/handy_bookmark/test/store_v2_test.dart`, `reading_undo_test.dart`                 | 1 → 4 and 2 → 4 keep every row (fixtures now also drop version 4's additions)                                                                                                                                         |
| `apps/handy_bookmark/test/store_v4_browser_test.dart`, `reading_undo_browser_test.dart` | Real IndexedDB in Chrome (`dart test -p chrome -j 1`; the files share one browser database, so they must run one at a time)                                                                                           |
| `packages/handy_bookmark_engine/test/items_trash_test.dart`                             | Model, Trash rules on a fixed clock, tombstones, picture references, search, duplicates, exports                                                                                                                      |

Full backup with pictures (ZIP) and restore of Trash are the next slice; until then a JSON
or ZIP export carries Trash items and picture records but not picture bytes.
