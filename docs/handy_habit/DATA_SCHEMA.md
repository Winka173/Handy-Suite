# Data schema and portability

Data schema 3 (2026-11-10; causal revisions, clock policy, trash); physical SQLite/IndexedDB version 2; isolated native `handy-habit.sqlite` / browser IndexedDB `handy-habit`.
No other app database is opened. Native tables: habits, events, routines, sessions,
operations (unique actor/sequence, entity index), singleton state metadata, and a device-local recovery table. Validated entity JSON plus indexed event habit/date/source,
habit foreign key, unique linked (session,step), and session status index.
SQLite WAL/FULL/FK, revision compare-and-swap, worker isolates and one transaction
for event + session updates. IndexedDB commits six data stores atomically; its seventh store holds device-local recovery; browser
commits currently rewrite stores. Future schemas/corruption refuse without blank reset.

Values are integer thousandths of displayed units, bounded to 1e12; count is whole
units, binary daily total <=1000, duration in minutes. Events are deltas. Daily-total
editing replaces manual contributions and preserves linked entries. Immutable entities
and deeply frozen settings; stable local dates, strict timestamp clocks/offsets and
1900-2200 calendar bounds. Changing timezone never shifts saved dates.

Effective-dated schedules snapshot target/recurrence/week start. Weekly changes require
a week boundary. Global week-start edits affect new plans. Switching daily/weekly units
starts a new streak segment; metrics describe that segment and exports retain old logs.
Skip is neutral, not success; open current periods are not failures. Weekly quotas count
distinct days and exclude partial first weeks, including reporting ranges. Archive pauses
eligibility from tomorrow; unarchive closes the pause through yesterday, preserving history.

Sessions snapshot step plans. Expected-step IDs reject stale double taps. Event + step +
cursor commit together. Undo removes only its own unchanged event (hash protected);
abort retains completed check-ins. Trashing retains entries/links for 30 days; permanent deletion clears entries/future links;
historical session snapshots remain. One active session. Stopwatch in foreground,
background pauses; crash recovery estimates only 0-24h wall gaps, pauses and warns.
Elapsed duration caps at 366 days. No killed/background auto-complete promise.
The background rule is unchanged by the run notice (Android/iOS): leaving the app from the
runner still persists the pause first; the notice then states the step and the time left
as of that pause (`secondsLeft`), never counts down, and is cancelled on resume, finish,
abort or leaving the runner. Setting `runNotice` (bool) overrides; unset it follows
`notifications`. It is never shown in quiet hours or without the OS permission, which is
only requested by the two settings switches.

## Pauses (schema 2)

`pauses` is a top-level list beside `habits`; it lives in the state row (SQLite
`state.payload`, IndexedDB `state/snapshot`), so schema 2 originally required no physical upgrade (`user_version` 1). Schema 3 uses physical version 2. A pause: `id`, `from`, `until` (inclusive local dates, at most 366 days),
`reason` (<= 200 chars, may be empty), `habits` (IDs; empty = every habit). At most
1000 pauses; every named habit must exist. Overlapping pauses are allowed and read as
their union. Migration: data written as schema 1 has no `pauses` and reads as an empty
list; current reads normalize schemas 1/2 to 3 and the next save writes 3. Schema 1 carrying `pauses`, or an unsupported future schema, is refused without reset. Older apps refuse schema 3.

Counting rule. A paused day for a habit is a scheduled day inside a pause that covers
it. Status order is future, not scheduled, skipped, completed, partial, **paused**,
then open/missed: a paused day done (or begun) anyway shows as done (or begun).

- Daily kinds: a paused day not done is left out entirely (not eligible, not missed,
  the run is neither extended nor broken). A paused day done counts like any done day.
- Weekly quotas: quota = ceil(weeklyTarget x (7 - paused days in that week) / 7). A week
  whose quota is 0 (wholly paused) is skipped and keeps the run. Days done count toward
  the week whether paused or not; paused days not done are no opportunity. The existing
  partial-week rule still applies against the prorated quota.
- Reminders: habit reminders skip days the habit is paused; routine reminders skip days
  inside a pause for every habit. The paused-run notice uses the same quiet hours.
- Edits: a new or moved start may not be earlier than today - backfill. Ending early
  sets `until` to yesterday; a pause that starts today or later is removed instead; a
  finished pause is unchanged. Permanently deleting a habit removes it from pauses and removes a
  pause left with no habit (never widening it to every habit).

Portability. JSON/ZIP backups carry pauses (manifest schema 3; schema 1/2 backups still restore). Merge gives pauses new IDs and remaps their habit IDs. Markdown/PDF reports
list pauses that overlap the range with the counting rule.

JSON/ZIP are full backups. ZIP has manifest.json + data.json, SHA-256 and empty assets
list. 30MB limit; CRC/path/traversal/bomb/future-schema guards. Merge remaps entity and
step IDs and recalculates event hashes; repeated digests/active-session conflicts refuse.
Replace requires preview plus confirmation and durable pre-replace recovery. Imported rules stay disabled until opt-in; merge preserves existing notifications.

CSV log columns: id,habit_id,habit,local_date,value_milli,source,skipped,session_id,
step_id,note,updated_at,record_b64. When pauses overlap the range, a blank line and a
second table follow: pause_id,from,until,scope(all|chosen),habit_ids(space separated),
habits,reason,record_b64 with record `{schema:3,pause}` (schema 2 records remain readable). Event records stay schema 1, so
a CSV without pauses is unchanged. Canonical schema+entry in record_b64 must match visible
fields (habit names excepted); formula-like display cells escaped, UTF-8 multiline notes round-trip. Log import
requires existing habit IDs, deduplicates identical IDs and refuses conflicts/orphans
atomically. Use ZIP/JSON to transfer full apps. Markdown/PDF are reports, not backups.
PDF embeds Vietnamese Noto fonts; >10k events use CSV/ZIP. Charts disclose last 52
periods; range exports remain complete. Detail history currently shows 30 rows plus export; pagination is planned in R6.

Future routine mappings and pending active-session mappings are checked against the
habit's tracking type during import/commit. Fractional count/binary mappings refuse
before a runner can get stuck. Tracking type and unit are fixed while entries, future
routine links or active session links exist; unlink/duplicate instead. Archived links
are explicitly shown as inactive in the runner and create no event.


## Schema 3 causal foundation and safe Undo

Top-level `operations`, `clockPolicies`, `trash`, `tombstones`, `undoBatch` and validated `entityOrder` (habit/routine IDs) supplement the unchanged entity lists. Native operations have their own indexed table; the other new metadata lives in state. Operations carry format 1, stable ID, actor/writer incarnation, actor sequence, Lamport counter, parents, kind/entity, batch, intent, before/after content hashes and bounded row payloads. Neither actor counters nor conflict ordering use wall-clock time. Restart creates a new writer incarnation, avoiding sequence reuse after replacing an older backup; persisted operation identities never change.

Legacy migration creates each event's revision ID from its canonical payload hash and an actor from its logical event ID. IDs, milli values, local days, source/session/step provenance, notes, updated instants and session event hashes are preserved. Schema 1 first supplies empty pauses. Parser accepts every emitted version 1/2/3, and refuses unknown versions before a commit. New clock policies snapshot zone, midnight boundary and effective instant; old events never recompute their days. Custom day boundaries are not enabled yet.

App mutations append row revisions in the same transaction as their materialized changes. Manual commands additionally retain `addDelta` versus `setManualTotal` and exactly observed contribution IDs. Deterministic union is idempotent, rejects ID/sequence/hash/ancestry collisions and exposes concurrent absolute-edit or skip/add candidates without choosing a timestamp winner. This is storage groundwork; cross-device projection/resolution and providers belong to R15/R16.

Undo persists the last reversible batch ID and inverses only its own unchanged rows; it appends retractions with exact `undoOf` IDs, survives process restart, preserves unrelated rows and refuses newer edits/reference violations. Failed commits do not publish or clear Undo. Imported replacement/permanent deletion are recovery/confirmation operations, not whole-state snapshot Undo. Ordinary changes to preferences/timers may clear the most recent Undo action, matching existing UI behavior.

Native physical 0→1 creation then 1→2 migration preserves the first flushed `handy-habit.sqlite.pre-v2.sqlite` (or `<test-path>.pre-v2.sqlite`) using SQLite VACUUM to include committed WAL pages. One transaction creates operations/recovery/indexes, normalizes metadata and sets user_version 2. Interrupted migration rolls back; retry reuses the original recovery file. Unknown physical versions refuse before journal writes. IDB 1→2 only adds operations/recovery stores inside the browser upgrade transaction, leaving existing records intact; it closes on versionchange and reports blocked tabs. Normalized data is written at the next CAS commit. Browser writes request IndexedDB strict durability; the browser/OS still owns eviction and actual durability. Interruption/quota behavior remains source-only until runtime QA.

## Trash and permanent deletion

Trash metadata: id/kind/entity, deletedAt/expiresAt UTC (exactly 30 days), deletion localDay. Original entities, events, reminders and routine links remain in place; live getters/reminder projections exclude trash. Days-left is ceil(remaining/24h), clamped 0–30. Future habit eligibility stops after deletion day; restoring retains that inactive gap and returns the same ID, archive flag and surviving references. No active session may reference an entity being trashed. Routine history snapshots remain after permanent deletion.

Purge on open is transactional/idempotent. It removes expired payload/history and habit references from routines/reminders/chosen pauses, never broadening an empty chosen pause into “all”. Lightweight tombstones and immutable operation headers/content hashes remain; inverse payloads belonging to erased items are redacted so Undo cannot recreate them. Unrelated check-in operation payloads remain. Previously exported backups, historical session snapshots and device recovery copies retain their documented contents; this is not secure erasure. No tombstone expiry is tied to the 30-day UI window.

## Backup metadata and durable replacement recovery

ZIP/JSON writers add `backupCreatedAt` outside the logical state; ZIP manifest/data schemas must agree. Legacy backups with no recorded date display “Date not recorded”. Preview shows input file size, recorded date, original schema and all entity/pause/trash counts. Sealed payload type is detected from the decrypted bytes; an automatic `.hseal` file need not include `.zip` in its filename. Shared authenticated encryption/password UI is reused unchanged.

Merge remains a copy import, remapping entity/step/trash IDs and valid links, preserving expiry and source provenance, leaving imported rules off. Remapped events get fresh deterministic revision baselines; this is not sync. Its repeated-import digest uses canonical logical state, excluding backup creation time.

Before Replace, the app saves the complete current state in a separate durable device-local recovery record under revision CAS. Only after that transaction succeeds does the replacement transaction run, with another CAS. Failure rolls back live data; recovery stays available after restart via Settings / Your data / Recover before last replace. A failed checkpoint stops replacement. Recovery restores at a new local revision, preserving the checkpoint. Ordinary backups/merge do not export or import the recovery store, and replacement leaves it intact. The next pre-replace checkpoint overwrites it. Local database, recovery and plain exports are unencrypted; `.hseal` files are authenticated/encrypted. No new cryptography was introduced.

Manual habit/routine order persists independently of SQLite row IDs or IndexedDB key ordering. Order-only edits append guarded order revisions; domain Undo restores their IDs/order and refuses changed membership or newer order. Old data without entityOrder preserves the repository order seen before migration.
