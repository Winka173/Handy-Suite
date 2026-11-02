# Handy Boards data schema

Portable schema 2 (reads schema 1). Native SQLite user_version 4; IndexedDB version 4. Stable UUIDs, canonical task payloads, transactional edits. Native SQLite indexed scope projections; IndexedDB schema parity. Relative managed asset keys and hashes, original user files untouched.

Kinds: workspaces, boards, categories, statuses, tasks, checklist, tags, attachments, dependencies, reminders, recurrence, occurrences, sessions, events, views, fields, rules, executions, templates, subjects, classes, grades. Task tags/custom values live on task; no duplicate view records. Parent/dependency cycles refused. UTC timed values plus IANA timezone; all-day dates explicit. Future schema refuses, no reset-on-error.

Task `exam` is optional metadata (durationMinutes 1..1440, location <=1000 chars,
materials <=10000 chars); its due timestamp means exam start. Duration is separate
from the task work estimate. All views and exports retain the same task UUID.
Saved views store a bounded <=30 condition list with AND/OR, typed ranges and
layout preferences. Unknown/malformed filters and invalid UI-facing preferences
are rejected before commit/restore. Asset `preview` is a managed relative path;
category `preview` is separately a 0..3 integer. Their types must not be conflated.

Native migrations are additive/transactional: v2 introduces immutable record/file
versions, deduplicated blobs and task/FTS projections; v3 retains revision headers;
v4 adds indexed FTS row-ID lookup and ordinal keyset scanning. Unknown newer
versions refuse to open without reset. Native 128-record decoded caches and
256-row keyset batches preserve old snapshots for Undo without eagerly reading
all asset bodies. IndexedDB separates file descriptors from immutable hash-keyed
bodies, adds board/global sort and trigram indexes, and aborts malformed legacy
file upgrades transactionally. CAS still controls every state publication.

Board workingCalendar/resourceCalendars are optional version-2 payload extensions:
weekdays 1..7, unique holidays, startMinute and minutesPerDay constrained to a day.
Categories remain independent of status. Widget publication opt-in is a local
preference; it never grants a store entitlement.
