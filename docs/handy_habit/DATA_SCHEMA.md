# Data schema and portability

Schema 1; isolated native `handy-habit.sqlite` / browser IndexedDB `handy-habit`.
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

JSON/ZIP are full backups. ZIP has manifest.json + data.json, SHA-256 and empty assets
list. 30MB limit; CRC/path/traversal/bomb/future-schema guards. Merge remaps entity and
step IDs and recalculates event hashes; repeated digests/active-session conflicts refuse.
Replace requires two confirmations. Imported notifications stay disabled until opt-in.

CSV log columns: id,habit_id,habit,local_date,value_milli,source,skipped,session_id,
step_id,note,updated_at,record_b64. Canonical schema+entry in record_b64 must match visible
fields; formula-like display cells escaped, UTF-8 multiline notes round-trip. Log import
requires existing habit IDs, deduplicates identical IDs and refuses conflicts/orphans
atomically. Use ZIP/JSON to transfer full apps. Markdown/PDF are reports, not backups.
PDF embeds Vietnamese Noto fonts; >10k events use CSV/ZIP. Charts disclose last 52
periods; range exports remain complete. Detail history loads 100 rows per page.

Future routine mappings and pending active-session mappings are checked against the
habit's tracking type during import/commit. Fractional count/binary mappings refuse
before a runner can get stuck. Tracking type and unit are fixed while entries, future
routine links or active session links exist; unlink/duplicate instead. Archived links
are explicitly shown as inactive in the runner and create no event.
