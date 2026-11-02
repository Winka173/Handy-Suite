# Handy Bookmark local database

Native: sqlite3 3.5.2 bundled by build hooks, worker isolate, SQLite `user_version=2`,
foreign keys, busy timeout, WAL and synchronous FULL. A newer unknown version is
refused without resetting or deleting the file. Creation is a transaction. Version 1
migrates to 2 in one transaction that only adds `reading_copies`; rows are untouched.

| Table                | Purpose                                                                                                                               |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| bookmarks            | Primary ID, normalized/canonical URL, domain/platform/type, collection, flags, saved/updated/open dates/count, versioned JSON payload |
| collections          | ID, parent, order and validated metadata; domain validation prevents cycles/missing parents                                           |
| tags / bookmark_tags | Independent tag names and many-to-many bookmark membership; orphan definitions retained in versioned state                            |
| settings             | Versioned collection/smart-rule/saved-search definitions and local preferences                                                        |
| bookmark_search      | FTS5 index using bookmark rowid; rebuilt when inconsistent; no SQL constructed from user strings                                      |
| bookmark_order       | Derived indexed manual positions; canonical ID order stays in settings                                                                |
| thumbnails           | Bounded bytes, access time; delete cascades with bookmark; 20MB LRU budget                                                            |
| reading_copies       | Schema 2. Offline text copy per bookmark (JSON, at most 2MB, 200k characters); saved time; delete cascades with bookmark              |

Indexes cover normalized/canonical URL, domain, platform, collection, flags and
saved/updated/open dates. Duplicate URLs are deliberately **not unique**: explicit
Add Anyway is supported. Transactions validate state before writing and atomically
apply bulk upserts/deletes/settings. Results reach Flutter only after commit.
If a worker dies/times out, outcome is uncertain: reopen before retrying; do not
pretend every transport error means rollback.

On Web, IndexedDB `handy-save-bookmarks` (version 2) stores separate
bookmarks/state/thumbnails/reading records and commits the equivalent changes in one transaction. No tiny shared
preferences string holds the full library. Browser search uses bounded page output
over the shared domain matcher; full-library fallback and quota are limitations.

Native recovery preserves main/WAL/SHM files before creating an empty database;
browser recovery must write a separate snapshot before clearing. Corrupt/unreadable
browser records may prevent preservation and therefore refuse reset. Recovery files
are local, not encrypted, and not automatically synchronized or securely erased.

Library state version 2 (2026-11-02): `manualOrder` (bookmark ids in the person's own
order) moved from `preferences.bookmarkOrder` into the library so backups carry it; a
version 1 state is migrated on load and both stores still read the old key. Bookmarks
may carry `linkCheck` (`status` ok/moved/gone/unreachable, `checkedAt`, optional
`movedTo`, `httpStatus`, `reason`), written only after an explicit check. Reading copies
never sit in bookmark rows, so lists and search pages stay small.
