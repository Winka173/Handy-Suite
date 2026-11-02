# Handy Bookmark architecture

Repository inspection: existing apps use LocalApp/handy_ui for themes, EN/VI,
native monetization and settings; handy_files for bounded import/export;
handy_core for cancellation/ZIP checks; handy_notifications for platform adapters.
Keep/Recall provide offline domain patterns. Their business state is not reused.

Decisions before implementation:

- Add apps/handy_bookmark and pure packages/handy_bookmark_engine to the same workspace.
- Preserve the current StatefulWidget/local-controller approach; do not introduce
  an incompatible routing/state dependency solely for one app.
- Native persistence uses sqlite3 3.5.2 in a worker isolate. Version 3.8 requires
  hooks/meta versions incompatible with this pinned Flutter SDK; 3.5.2 supports
  its existing hooks 2.0.2. Do not override Flutter's meta SDK pin.
- Normalized SQLite tables/indexes, FTS where supported, transactional updates and
  explicit version migration. Web uses a per-record IndexedDB adapter and the same
  model; it does not store the entire collection in one small preferences value.
- Save a shared URL transactionally before acknowledging its native durable queue
  entry. Metadata is optional and explicit, never a requirement for saving.
- Native metadata resolves/validates DNS on each redirect and pins sockets to
  approved public IPs. Web cannot guarantee this through browser redirects/DNS;
  metadata reports unavailable there while all offline bookmark functions work.
- Reuse store adapters with app key save. Quick Save has no ads; Pro gates only
  optional smart collections/saved searches, not basic save/search/import/export.

SQLite reference: https://pub.dev/packages/sqlite3. Native binaries are bundled
through the package's build hooks, without a custom server. No cross-install sync.
