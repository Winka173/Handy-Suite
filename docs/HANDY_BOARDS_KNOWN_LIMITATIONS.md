# Handy Boards known limitations

Feature code in the remaining-work batch is implemented. This is not a claim of
store readiness or exhaustive bug freedom. See the feature/platform matrices and
source-bound QA checkpoint for actual coverage.

No Mac/Xcode, physical phone or publisher accounts are available. iOS WidgetKit,
share extension, App Group entitlement, quick actions and document picker source
are integrated but their build/runtime/provisioning remain UNVERIFIED. Android
emulator evidence is separate from physical permission/provider/background tests.
Windows installer/store UI, official purchase/refund/restore and consent testing
remain release gates. Real IndexedDB tests do not certify the complete Web UI or
PWA update lifecycle in every browser.

Working calendars and the workload tab were removed on 2026-11-03; calendars saved
before then stay in the data, unused. Study reports
use actual saved assessments/tasks, not official or predicted academic grades.
Trello import is a documented local JSON subset, not API synchronization.

Native full ZIP export is streamed; ZIP import stages files before preview and
transactional merge/replace. Source <=512 MB, expanded <=402 MB including metadata,
<=10000 entries, metadata <=100 MB, each managed asset <=12 MB and live assets
<=300 MB. Browser/JSON downloads remain <=30 MB/1000 entries. These are explicit
bounds, never silent truncation. Browser exports yield/cancel between records and
assets; native export-only workers can be interrupted. A confirmed restore's DB
transaction is atomic and not interrupted halfway through COMMIT. Imported system
reminders and home-widget task names start disabled on replacement restore.
Study printable <=1000
tasks/100 categories. PDF font coverage is bundled EN/VI, not every writing system.

Native metadata is version-addressable with a bounded decoded-record cache; assets
are read on demand. Browser metadata remains resident (asynchronous IndexedDB
cannot supply synchronous domain references); file bodies do not. List/Table use
indexed page queries; other aggregate views scan canonical records. Very short
searches and platforms without trigram FTS use a bounded cursor/LIKE fallback.
Recorded host RSS includes fixture creation/test VM and is not mobile memory QA.
Snapshot versions and immutable blobs are retained for Undo and active readers;
live-asset quotas are not a cap on the physical SQLite/IndexedDB file. No secure
erasure/automatic cross-process history compaction is claimed. Undo is session-only.

Widgets show the last app-published snapshot, not a continuously running background
scheduler. Task names require explicit opt-in; revocation clears published rows.
Windows/Web have no simulated native widget or scheduled system notification.
Web/Windows keep the in-app reminder center; closed-browser delivery is not promised.

Files/notes are local and not encrypted by the app. Backups include private original
assets and need explicit review. Android SAF providers may refuse deletion of an
incomplete destination copy; this is reported instead of claiming it was removed.
Browser download completion means dispatch, not verified disk persistence. No
backend/account/paid AI/cloud collaboration or cross-store entitlement fabrication.
