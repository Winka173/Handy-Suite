# Handy Boards import/export

Full JSON/ZIP: app handy-boards/schema2 (reads schema1), all entity collections, preferences,
relative assets and ZIP manifest with size/SHA-256. Decode validates directory paths,
entry/expanded bounds, checksums, IDs/references/cycles and schema before preview.
Preview -> Merge or Replace -> explicit confirm -> CAS transaction. Replace asks
again; merge remaps only reference fields/keys and asset paths, never matching user
text. Imported system reminders are disabled; replacement restore also disables home-widget names. Store entitlement never comes from
these files. Backup is private and unencrypted; originals are never overwritten.

Native ZIP streams metadata/assets to private staging, then saves through SAF,
UIDocumentPicker or a new uniquely named desktop file. Progress and Cancel are
real. Native ZIP import stages a <=512 MB input; <=10000 entries, <=100 MB metadata,
<=12 MB per asset, <=300 MB live assets and <=402 MB total expanded. It rejects
traversal, duplicates, oversized/unsupported central directories, expansion limits,
compression-ratio bombs, CRC and SHA-256 mismatches before review/commit.
33 MB export -> stage -> replace/merge round-trip is tested with actual files.

Browser/JSON remain <=30 MB with <=1000 guarded ZIP entries. Async serialization
checks bounds incrementally, reads asset bodies on demand and yields for Cancel.
Error/cancel leaves the library intact; Undo is session-only. Destination provider
permissions/cancel/cleanup require per-device QA; a provider cleanup failure is
reported explicitly. No public destination is written before preparation succeeds.

Canonical task CSV columns: id,title,category,status,priority,due,notes,record_b64.
Payload preserves task fields; visible columns must match. Formula-leading cells
are prefixed. Original board/category/status/tag/field dictionaries must exist;
conflicting task UUIDs refuse. Use full ZIP for transferring devices. Mapped CSV
(title required; notes/due/status optional) creates new task IDs after column review.
CSV <=3 MB/50000 rows, UTF-8, strict quoted fields. All-day mapped due YYYY-MM-DD.

Markdown checkbox lists and plain lines create canonical tasks after preview.
Markdown export intentionally contains title/completion only; it is a checklist
interchange, not lossless full backup. CSV/JSON preserve richer task data as above.
ICS exports due events (all-day or UTC), UTF-8 fold/escape; no recurrence rules in ICS.
PDF summary excludes note/attachment bodies; personal task titles remain private.

Pro exports: valid XLSX inline string cells (no formula injection), safe board
template JSON without original UUIDs/history/attachments/private notes/field values and
printable Study PDF (timeline PDF removed 2026-11-03). Independent readers PyMuPDF/openpyxl verify actual files.
Templates preserve subtask links, checklist structure (completion reset), field definitions/defaults and category/status ordering.
Recurrence definitions (including dates/timezone) require explicit opt-in on BOTH
export and import. Imported definitions start disabled until reviewed in the task
recurrence editor. Past occurrences/reminders/executions are never cloned.
Template ZIP packages contain only `template.json` (<=3 MB) and a schema-1
manifest with byte count/SHA-256. The decoder guards traversal, entry sizes and
checksums before preview. They intentionally contain no user media. Full backups
use a distinct manifest and preserve attachments. Package round trips and corrupted
checksums/unsafe paths are automated-tested.
Trello JSON: board name, lists -> statuses, cards -> canonical tasks, named labels
-> tags, notes, start/due instants, archived cards/lists and flattened checklists.
Preview requires explicit completed-list selection; dueComplete never guesses
workflow completion. Category stays separate. Optional HTTP(S) attachment links
are references only; no remote content is downloaded. Members, comments, covers,
custom fields and automation do not transfer. Fresh IDs avoid collisions. This
is a local documented subset, not an API integration. No implicit cross-app DB access.
