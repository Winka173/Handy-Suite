# Handy Save local database

Native: sqlite3 3.5.2 bundled by build hooks, worker isolate, SQLite `user_version=1`,
foreign keys, busy timeout, WAL and synchronous FULL. A newer unknown version is
refused without resetting or deleting the file. Creation is a transaction.

| Table                | Purpose                                                                                                                               |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| bookmarks            | Primary ID, normalized/canonical URL, domain/platform/type, collection, flags, saved/updated/open dates/count, versioned JSON payload |
| collections          | ID, parent, order and validated metadata; domain validation prevents cycles/missing parents                                           |
| tags / bookmark_tags | Independent tag names and many-to-many bookmark membership; orphan definitions retained in versioned state                            |
| settings             | Versioned collection/smart-rule/saved-search definitions and local preferences                                                        |
| bookmark_search      | FTS5 index using bookmark rowid; rebuilt when inconsistent; no SQL constructed from user strings                                      |
| bookmark_order       | Derived indexed manual positions; canonical ID order stays in settings                                                                |
| thumbnails           | Bounded bytes, access time; delete cascades with bookmark; 20MB LRU budget                                                            |

Indexes cover normalized/canonical URL, domain, platform, collection, flags and
saved/updated/open dates. Duplicate URLs are deliberately **not unique**: explicit
Add Anyway is supported. Transactions validate state before writing and atomically
apply bulk upserts/deletes/settings. Results reach Flutter only after commit.
If a worker dies/times out, outcome is uncertain: reopen before retrying; do not
pretend every transport error means rollback.

On Web, IndexedDB `handy-save-bookmarks` stores separate bookmarks/state/thumbnails
records and commits the equivalent changes in one transaction. No tiny shared
preferences string holds the full library. Browser search uses bounded page output
over the shared domain matcher; full-library fallback and quota are limitations.

Native recovery preserves main/WAL/SHM files before creating an empty database;
browser recovery must write a separate snapshot before clearing. Corrupt/unreadable
browser records may prevent preservation and therefore refuse reset. Recovery files
are local, not encrypted, and not automatically synchronized or securely erased.
