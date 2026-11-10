# Data schema and portability

Data schema 8 (2026-11-10; Advanced routine rules, reusable snapshots and execution traces; schemas1–7 migrate); sync protocol 1 and physical SQLite/IndexedDB version 2; isolated native `handy-habit.sqlite` / browser IndexedDB `handy-habit`.
No other app database is opened. Native tables: habits, events, routines, sessions,
operations (unique actor/sequence, entity index), singleton state metadata, and a device-local recovery table. Validated entity JSON plus indexed event habit/date/source,
habit foreign key, unique linked (session,step), and session status index.
SQLite WAL/FULL/FK, revision compare-and-swap, worker isolates and one transaction
for event + session updates. IndexedDB commits six data stores atomically; its seventh store holds device-local recovery; browser
commits currently rewrite stores. Future schemas/corruption refuse without blank reset.

Values are integer thousandths of displayed units, bounded to 1e12; count is whole
units, binary displayed daily total <=1000 (independent causal contributions retained), duration in minutes. Events are deltas. Daily-total
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
background pauses; crash recovery preserves saved foreground elapsed time, pauses and warns. Closed-app wall gaps add no elapsed time.
Elapsed duration caps at 366 days. No killed/background auto-complete promise.
The background rule is unchanged by the run notice (Android/iOS): leaving the app from the
runner still persists the pause first; the notice then states the step and the time left
as of that pause (`secondsLeft`), never counts down, and is cancelled on resume, finish,
abort or leaving the runner. Setting `runNotice` (bool) overrides; unset it follows
`notifications`. It is never shown in quiet hours or without the OS permission, which is
only requested by the two settings switches.

## Advanced routines (schema 8, R17/R18)

- `RoutineStep.logic`: `weekdays` (empty means every day), `habitNotDone` (positive habit ID), `minimumRemaining` (seconds), `dependencies` (prior step IDs), `stackAfter` (prior step ID, offered for linked habits), `branch` + `option` (`A`/`B`), `durations` (weekday 1–7 → seconds), and source `block` ID. Conditions are ANDed in a fixed order: day, habit availability/completion, time, prerequisites, branch. No expressions or executable code.
- Each branch name must contain both A and B. All dependencies/stack links point backwards, which excludes cycles and guarantees finite traversal. At most 200 expanded steps; each step is 0–86400 seconds. Invalid edits/imports fail before commit. Missing condition habits skip with an explicit unavailable reason.
- `Routine.blocks` and `.presets` contain named `StepBlock{id,title,steps}` snapshots (at most 50 each). No recursive references: insertion creates independent IDs, remaps internal dependencies/stacking and namespaces choices. Blocks append, presets replace draft steps. Saved sets are available from other routines. Editing/removing a source set never rewrites insertions or runs.
- Starting a run resolves weekday durations and captures immutable `inputs`: logical weekday, initial session budget (sum of plan seconds, or caller-supplied budget), habit values/targets/titles and already-completed IDs. Conditions evaluate only on reaching a step; completed linked contributions update the captured values. Paused/closed-app time consumes no budget. Later habit edits, routine edits or sync do not reevaluate captured decisions.
- `StepRun.reason` is a stable reason code; `evaluated` distinguishes an admitted step from one waiting on a decision. `RoutineSession.choices` records each choice; `trace` is deeply immutable, bounded to 10000 entries and append-only through session operations. The start entry contains the original plan and inputs; evaluation, choices, completion/skip/Undo/finish are retained. Undo requires later completed work to be undone first; changing a branch appends Undo/choice records. Closed sessions refuse mutation.
- Existing schemas migrate to the same linear path with empty rules/sets/inputs/choices/trace. JSON and ZIP retain all new data. Copy-import remaps nested step/habit/block IDs and trace/input references. Protocol1 merges new routine fields with the existing causal reducer; closed snapshots survive later routine edits. Restoration/sync never starts timers or reruns automation.
- Pro gates live in the app and are checked again at Save; running stored logic, backup, restore, export and sync remain Free. Entitlement never lives in a backup.

## Pauses (schema 2)

`pauses` is a top-level list beside `habits`; it lives in the state row (SQLite
`state.payload`, IndexedDB `state/snapshot`), so schema 2 originally required no physical upgrade (`user_version` 1). Schema 3 uses physical version 2. A pause: `id`, `from`, `until` (inclusive local dates, at most 366 days),
`reason` (<= 200 chars, may be empty), `habits` (IDs; empty = every habit). At most
1000 pauses; every named habit must exist. Overlapping pauses are allowed and read as
their union. Migration: data written as schema 1 has no `pauses` and reads as an empty
list; current reads normalize schemas 1–7 to8 and the next save writes8. Schema 1 carrying `pauses`, or an unsupported future schema, is refused without reset. Older apps refuse schema8; keep a backup before upgrading.

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

Portability. JSON/ZIP backups carry pauses (manifest schema5; schema1/2/3/4 backups still restore). Merge gives pauses new IDs and remaps their habit IDs. Markdown/PDF reports
list pauses that overlap the range with the counting rule.

JSON/ZIP are full backups. ZIP has manifest.json + data.json, SHA-256 and empty assets
list. 30MB limit; CRC/path/traversal/bomb/future-schema guards. Merge remaps entity and
step IDs and recalculates event hashes; repeated digests/active-session conflicts refuse.
Replace requires preview plus confirmation and durable pre-replace recovery. Imported rules stay disabled until opt-in; merge preserves existing notifications.

CSV log columns: id,habit_id,habit,local_date,value_milli,source,skipped,session_id,
step_id,note,updated_at,record_b64. When pauses overlap the range, a blank line and a
second table follow: pause_id,from,until,scope(all|chosen),habit_ids(space separated),
habits,reason,record_b64 with record `{schema:5,pause}` (schema2/3/4 records remain readable). Positive event records stay schema 1, so
a CSV without pauses is unchanged. Canonical schema+entry in record_b64 must match visible
fields (habit names excepted); formula-like display cells escaped, UTF-8 multiline notes round-trip. Log import
requires existing habit IDs, deduplicates identical IDs and refuses conflicts/orphans
atomically. Use ZIP/JSON to transfer full apps. Markdown/PDF are reports, not backups.
PDF embeds Vietnamese Noto fonts; >10k events use CSV/ZIP. Charts disclose last 52
periods; range exports remain complete. Detail history starts at30 rows and Show all expands every older entry in place; dated goals remain visible.

Future routine mappings and pending active-session mappings are checked against the
habit's tracking type during import/commit. Fractional count/binary mappings refuse
before a runner can get stuck. Tracking type and unit are fixed while entries, future
routine links or active session links exist; unlink/duplicate instead. Archived links
are explicitly shown as inactive in the runner and create no event.


## Schema 3 causal foundation and safe Undo

Top-level `operations`, `clockPolicies`, `trash`, `tombstones`, `undoBatch` and validated `entityOrder` (habit/routine IDs) supplement the unchanged entity lists. Native operations have their own indexed table; the other new metadata lives in state. Operations carry format 1, stable ID, actor/writer incarnation, actor sequence, Lamport counter, parents, kind/entity, batch, intent, before/after content hashes and bounded row payloads. Neither actor counters nor conflict ordering use wall-clock time. Restart creates a new writer incarnation, avoiding sequence reuse after replacing an older backup; persisted operation identities never change.

Legacy migration creates each event's revision ID from its canonical payload hash and an actor from its logical event ID. IDs, milli values, local days, source/session/step provenance, notes, updated instants and session event hashes are preserved. Schema 1 first supplies empty pauses. Parser accepts every emitted version1/2/3/4, and refuses unknown versions before a commit. Clock policies snapshot zone, dayBoundaryMinutes0–1439 and an increasing effective instant; old events never recompute their days. Schema3 policies migrate unchanged (midnight). Schema4 enables custom boundaries from Settings/Calendar. `habitDayAt` chooses the effective version by instant, constructs a local cutoff, shifts nonexistent times forward by the DST gap and chooses the first repeated occurrence in either hemisphere. Check-ins, reminder eligibility and trash share this logical day. A foreground timer refreshes views within one minute of the cutoff, and app resume refreshes immediately.

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


## R5/R6 presentation preferences

`settings.sidebarCollapsed` and `settings.reducedMotion` persist shell/motion choices without
creating check-in Undo batches. OS reduced motion always wins. `settings.habitDayParts` maps
habit IDs to auto/morning/afternoon/evening/anytime; auto infers the earliest enabled habit
reminder or linked live routine time. Copy-merge remaps these habit IDs and retains the
receiver's clock/settings. No historical event date, unit, appearance value or target is
rewritten by presentation changes. Calendar edits append an effective clock-policy version.


## Schema 5 — negative habits (R10/R11)

Physical SQLite/IndexedDB remains version 2: all new domain fields are in existing entity JSON. Readers accept every shipped schema 1–5; writers emit 5. Schemas 1–4 retain positive payloads and causal IDs/hashes; a missing `direction` means `build`. Positive serialization omits the new fields so older operation before/after hashes and Undo guards remain valid. JSON/ZIP manifests now say 5; schema 4 ZIPs and schema 2–4 pause CSV records remain readable.

A negative habit has `direction: reduce`, `type: count` (whole incidents), and immutable ordered `negativeGoals` (1–1000). Each goal: `id`, `from` (local date), `window: day|week`, `limit` (integer thousandths, 0 allowed, <=1e12, multiple of 1000), `weekStart` (1–7). First goal begins on `created`; later goals preserve historical ceilings. Changes from/to a weekly ceiling require both relevant week boundaries, so changing the device week preference cannot silently move a saved ceiling. No baseline or reduction percentage is inferred.

Incidents reuse manual `HabitEvent` deltas, with optional note and original instant/day. An explicit non-skipped zero event is an observation (“None today”); absence of events is unknown. Skip is never an observation. `HabitIndex.known` retains the distinction. `setManualTotal(... observed: false)` retracts manual observations, requiring zero total/no note/no skip; it is not a zero confirmation. Day intent operations also carry `observed` for negative records/edits. Existing row revisions, guarded domain Undo, batch retractions, ID collision checks and causal conflict candidates apply. Conflicted periods cannot earn credit; a resolving edit observes all candidates. No network sync is claimed by this slice.

Daily limits preserve explicit zero versus unknown. Past blank daily days remain hollow and are excluded from consistency and streak opportunities. Weekly limits sum incidents; once a complete week closes, blank days infer no incident. No synthetic observation/event is saved. Whole-week inference never crosses pause/skip/conflict/creation/archive/deletion/goal boundaries; such windows remain neutral, with no prorated ceiling. Today and open weeks earn no negative streak; within-limit closed periods extend it, over-limit periods break it. Unknown/conflict days do not lower consistency or break a run. Closed weekly heatmap cells use the final week result on every day; open weeks never look like earned success. This run7 rule supersedes the original run6 requirement to observe every day.

Progress counts use actual today separately from range end, so a past Sunday includes its closed week. Partial first/last weeks are excluded. Completed positive weekly quotas can count before week end; negative limits always wait for close. Ranges spanning day/week goal versions report mixed units as goals. UTC civil-date stepping preserves leap days and avoids DST hour arithmetic. Heatmaps derive from records and pauses, never modify history; no new schema or storage fields. Catalog IDs are stable constants; new instances and their routine steps get independent IDs only in drafts.

Routine plans and pending session mappings reject negative links; negative events with routine provenance are invalid. The runner also refuses to generate such an incident.

Full JSON/ZIP backups carry goals, all observations, notes, operations, trash and history. CSV keeps its visible header and positive schema-1 records; negative record_b64 uses schema 5, with `negativeHabit` metadata on the first exported row per habit and plain entries thereafter. Import validates the full batch, recreates missing negative habits from that metadata, deduplicates entries, and refuses mismatching existing habit configuration atomically. Empty negative habits without logs travel in JSON/ZIP. Markdown/PDF stats use the same closed-period metrics; reports are not full backups.

Host evidence: incident/none/unknown, open/closed day/week, pause/skip, fresh recovery, retraction, backfill, goal history, conflict resolution, JSON/ZIP/CSV, v1–v4 JSON+ZIP, DST spring/fall north/south, SQLite reopen and durable Undo. IndexedDB real-browser upgrade/quota/tab behavior and device checks remain unverified.


## Schema 6 — optional mood (R14)

One `MoodEntry` per local `day`, identity `mood:YYYY-MM-DD`. Required mood is an integer 1–5; optional energy is 1–5 or null. Note is a string up to4096 characters (empty allowed); tags are up to8 distinct trimmed nonempty strings, each up to40 characters. No inferred entries, no averages/correlation/medical claims. At most100000 entries; duplicate dates/IDs and invalid dates/timestamps/scales are refused.

`recordedAt`, `updatedAt`, optional `deletedAt` are strict UTC timestamps; updatedAt cannot precede recordedAt. Revision starts at1; save/edit/delete/restore require the observed revision and increase it. Backward/equal device time advances the timestamp by a microsecond. Day identity never changes with the device timezone/day boundary. Today uses the current clock policy; explicit history dates stay fixed. The UI refuses future dates.

Deletion is recoverable in mood history, independent of habit Trash and its30-day expiry. It retains the payload with `deletedAt == updatedAt`; Progress exposes Restore and immediate guarded Undo. Re-logging a deleted day starts with blank optional fields; explicit Restore keeps the old note/energy/tags. There is no individual permanent-mood-delete control in R14. Delete-all includes moods; external backup copies remain the user's responsibility.

`moods` lives beside pauses in SQLite state.payload / IndexedDB state/snapshot; physical version remains2, with no new tables/stores. Immutable lists and causal row operations (`kind: moods`, stable entity/date ID, observed parents, before/after, batch and undoOf) carry create/edit/delete/restore. Guarded Undo cannot overwrite a newer edit. Transport and cross-device conflict UI remain R15/R16; this is not a sync-completion claim.

Readers accept JSON/ZIP schemas1–6, writers emit6. Missing moods in old data become[]; habits/events/routines/sessions and existing operation payloads/hashes stay unchanged. All five old ZIP manifest versions remain accepted. Old apps refuse6: keep a backup before upgrade. `settings.showMoodToday` is an optional bool, defaults true; turning it off keeps data/history, reset preferences removes the override.

JSON/ZIP/plain/encrypted/auto backups and durable recovery carry live/deleted moods and operations. Copy-merge imports missing dates, deduplicates byte-equivalent canonical payloads, and refuses differing same-date entries before any write; no latest-clock-wins or ID remapping of mood dates. Preview discloses this rule and includes mood counts, including deleted entries.

CSV adds an optional table headed mood_id/local_date/mood/energy/note/tags/revision/recorded_at/updated_at/deleted_at/record_b64 after the existing log and optional pause tables. Visible cells and portable schema6 payload must match; notes/tags retain Unicode/newlines and formula-like cells are escaped. All entries in range, including deleted, travel. Import validates the entire batch, deduplicates identical entries and stops on conflicting dates. Existing positive schema1 / negative schema5 / pause schemas2–5 remain readable. Markdown/PDF remain habit summaries, not complete mood backups; use JSON/ZIP/CSV for mood.

Notes stay in local app data (not encrypted at rest) and exports/backups explicitly chosen by the user. Notification, paused-run and home-widget builders never receive mood fields. No mood reminders, permission requests or Pro gate are introduced. Host evidence covers validation, stale revisions, causal Undo, all formats, v1–v5 migrations, two-tap/skip/optional details, history/edit/delete/restore, preference hiding and real SQLite reopen. Browser/device/lock-screen delivery checks remain supervisor work.

## Schema 7 — causal sync projection (R15/R16)

Writers emit7; JSON/ZIP readers accept1–7, including schema6 moods. Physical
SQLite/IndexedDB remains2. Mood CSV portable payloads6 and7 are accepted. Other
CSV record formats keep their existing version rules. No new entity field is
needed: retained operations are the conflict evidence. The bump prevents older
readers from misinterpreting a binary day containing independent contributions.
Binary raw sum may exceed1000 only when every contribution has matching causal
event provenance; `HabitIndex.of` caps displayed progress at1000. Raw IDs and
routine links survive JSON/ZIP/store roundtrip.

### Remote protocol 1

`handy-habit/commits/<deviceUUID>-<sha256-of-envelope>.json` is immutable. Each
envelope contains `format: handy-habit-sync`, `version:1`, `minReader:1`,
`schema:7`, `size` (UTF-8 canonical operations byte length), `sha256` (payload),
and `operations`. Object keys sort recursively; operation order is Lamport then
stable ID. Filename hash protects the whole envelope. Limit30MB/file and200000
operations; invalid payload hashes, IDs, actor sequences, ancestry and schema
refuse the whole round before any upload or local write.

After a verified generation upload, an immutable
`handy-habit/versions/<deviceUUID>-<generationHash>.json` records
`format: handy-habit-device-version`, protocol/schema, device and generation.
Version receipts are validated before upload; missing referenced commits or
partial/missing downloads refuse. A generation without a receipt is still read,
so interruption between these uploads loses nothing. These per-device version
files avoid a shared mutable lock/version overwrite race: concurrent writers
append independent generations. Repeated same-name creates must have identical
bodies, including Drive duplicates after an uncertain POST response.

Every device retains its last successful operation base outside the library in
`habit-drive-device.json`, alongside device UUID, opt-in, selected account, last
success, five recent success times and last error code. No access token is stored.
The three-way result is the validated union of base, current local and every
complete remote generation. Absence from a snapshot is never a deletion. A
received result joins current local data again inside the controller queue so
edits made during network I/O survive and remain pending for the next round.

### Deterministic materialization and review

- Pre-ledger rows receive content-validated, deterministic identity seeds from
  the earliest before-image, once. Operation/actor-sequence collisions refuse;
  same logical event ID with different content refuses. The same routine step’s
  deterministic event ID may differ only in recording timestamp; its semantic
  contribution is projected once and the session’s event hash is repaired.
- Count check-ins and negative incidents union by independent event IDs. Undo
  retracts its observed operation/batch only. A stale replica cannot resurrect
  it. Binary contributions retain both provenance rows and display one success.
- An absolute total replaces manual contributions it observed; linked entries
  and concurrent additions survive. Concurrent absolute totals or skip versus
  add retain candidates in `dayOperationConflicts`. No automatic clock winner
  and no sum of two absolute totals. Projection omits disputed manual values;
  `conflict` days/periods are excluded from eligibility/streak calculations.
  Review chooses a total/skip and records parents observing all candidates.
- Same-day mood maximal revisions retain all payloads in the ledger. If their
  contents differ, no mood is projected or averaged. Sync shows each candidate,
  including Undo/removal, and explicit review observes them all. A later normal
  mood edit also observes the current heads. Other dates stay unchanged.
- Configuration patches change only fields changed from their before-image.
  Disjoint fields and ID-addressed routine steps merge; same-field concurrent
  edits apply in stable Lamport/operation-ID order. Schedule/goal histories sort
  by effective day; same-day duplicate revisions project by stable revision ID,
  with the original alternatives still retained in operations. Wall time never
  chooses a tracking-data winner.
- Concurrent row removal wins over an unobserved edit; observed restore can
  supersede Trash removal. Trash hides an edited item without losing its rows.
  Permanent tombstones dominate every stale edit; late offline payloads are
  redacted locally, preserving header/hashes. Dangling habit links clear;
  a targeted pause with no surviving target is removed, never broadened to all.
- Routine edits and sessions union. Independent session IDs survive. Only one
  active runner is projected; extra concurrent active sessions remain as aborted
  recovery records, deterministically. Remote anchors never start a local timer;
  an unchanged local anchor can remain on the recording device. Preferences,
  reminders, permissions, clock policies and runtime timer ownership stay local.
  Existing civil event/session dates never recalculate from wall timestamps.

There are no Habit attachments in this model. No compaction is performed without
replica acknowledgements. Remote generations can retain older/deleted payloads;
redaction applies to newly materialized generations, not already-uploaded copies.
To erase all cloud copies, the owner uses Drive Settings → Manage apps → Handy
Habit → delete hidden app data, after turning sync off on all devices. Switching
sync off or disconnecting itself deletes neither local nor remote data. Long
history growth, initial-sync latency, true network interruption and actual Google
authorization require the scale/device follow-up in [RELEASE](RELEASE.md).
