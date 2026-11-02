# Data schema and portability

Schema 2 (2026-11-02; adds pauses); isolated native `handy-habit.sqlite` / browser IndexedDB `handy-habit`.
No other app database is opened. Native tables: habits, events, routines, sessions,
singleton state metadata. Validated entity JSON plus indexed event habit/date/source,
habit foreign key, unique linked (session,step), and session status index.
SQLite WAL/FULL/FK, revision compare-and-swap, worker isolates and one transaction
for event + session updates. IndexedDB commits all five stores atomically; browser
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
abort retains completed check-ins. Deleting a habit clears its entries/future links;
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
`state.payload`, IndexedDB `state/snapshot`), so no table changed and `user_version`
stays 1. A pause: `id`, `from`, `until` (inclusive local dates, at most 366 days),
`reason` (<= 200 chars, may be empty), `habits` (IDs; empty = every habit). At most
1000 pauses; every named habit must exist. Overlapping pauses are allowed and read as
their union. Migration: data written as schema 1 has no `pauses` and reads as an empty
list; the next save writes schema 2. Schema 1 carrying `pauses`, or any other schema,
is refused without a reset. An older app refuses schema 2 the same way.

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
  finished pause is unchanged. Deleting a habit removes it from pauses and removes a
  pause left with no habit (never widening it to every habit).

Portability. JSON/ZIP backups carry pauses (manifest schema 2; schema 1 backups still
restore). Merge gives pauses new IDs and remaps their habit IDs. Markdown/PDF reports
list pauses that overlap the range with the counting rule.

JSON/ZIP are full backups. ZIP has manifest.json + data.json, SHA-256 and empty assets
list. 30MB limit; CRC/path/traversal/bomb/future-schema guards. Merge remaps entity and
step IDs and recalculates event hashes; repeated digests/active-session conflicts refuse.
Replace requires two confirmations. Imported notifications stay disabled until opt-in.

CSV log columns: id,habit_id,habit,local_date,value_milli,source,skipped,session_id,
step_id,note,updated_at,record_b64. When pauses overlap the range, a blank line and a
second table follow: pause_id,from,until,scope(all|chosen),habit_ids(space separated),
habits,reason,record_b64 with record `{schema:2,pause}`. Event records stay schema 1, so
a CSV without pauses is unchanged. Canonical schema+entry in record_b64 must match visible
fields (habit names excepted); formula-like display cells escaped, UTF-8 multiline notes round-trip. Log import
requires existing habit IDs, deduplicates identical IDs and refuses conflicts/orphans
atomically. Use ZIP/JSON to transfer full apps. Markdown/PDF are reports, not backups.
PDF embeds Vietnamese Noto fonts; >10k events use CSV/ZIP. Charts disclose last 52
periods; range exports remain complete. Detail history loads 100 rows per page.

Future routine mappings and pending active-session mappings are checked against the
habit's tracking type during import/commit. Fractional count/binary mappings refuse
before a runner can get stuck. Tracking type and unit are fixed while entries, future
routine links or active session links exist; unlink/duplicate instead. Archived links
are explicitly shown as inactive in the runner and create no event.
