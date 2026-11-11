# Backup and restore architecture

All backup/restore/export is Free. Source: engine `src/portable.dart`, app
`settings/data.dart`, `controller.dart`, `data/` stores; shared
`handy_core` sealed format and kit `HandyAutoBackupSection` are reused.

JSON/ZIP schema 9 accepts schemas 1–9. Entire input, size, ZIP paths/checksums,
manifest/data schema agreement and references validate before commit. Limit
30,000,000 bytes and 200,000 rows per list. Preserve habits/schedules, events/notes,
routines/frozen sessions, pauses, live/deleted moods, causal operations,
Trash/tombstones/order and library settings. Creation date is outside logical
state. No attachment model. Recovery, store grants, OAuth tokens, backup
destinations/passwords and sync metadata excluded. Local database/plain exports
are unencrypted.

| Operation | Behavior |
| --- | --- |
| ZIP/JSON | Private-data confirmation, system export; cancel preserves source/data |
| Sealed | Shared authenticated `.hseal`; decrypt then detect ZIP/JSON; wrong password/corruption/cancel refuses; forgotten password unrecoverable |
| Preview | File size, recorded date or Date not recorded, original schema, entity counts |
| Merge | Copy import: fresh IDs, repaired links, repeated-import digest, imported reminders off, receiver clock/preferences retained; not sync |
| Mood merge | Same-date identical payload deduplicates; different payload refuses whole merge |
| Replace | Confirm, durable pre-replace checkpoint under CAS, then replacement under CAS; checkpoint failure blocks replace; failed commit keeps live data |
| Recovery | Separate local record survives restart; restore at new revision; normal backups exclude it; next checkpoint replaces it |
| Rules | Replacement disables imported convenience rules; copy-merge keeps receiver settings/rules |
| CSV | Validated logs plus optional pause/mood tables; Unicode/formula-like escaping; not full routines/settings/causal backup |
| Markdown/basic PDF | Range reports; PDF refuses >10k events; ZIP/CSV for larger reports |
| Smart PDF | Pro designed insight report; ordinary Free export unaffected |

Automatic copies run on app open/background opportunities, daily/weekly,
retaining 3/7/14/30, optional encryption/status/error/Backup now. Configuration is
device-local, not library data/sync. No terminated-app scheduling guarantee.

| Platform | Manual | Automatic destination / evidence |
| --- | --- | --- |
| Android | System files/share | Chosen SAF folder, compatible cloud document providers; runtime/provider permissions pending |
| iOS | Files source | App Files location; build/provider unverified here |
| Windows | Native dialogs | User folder; host filesystem tests do not certify every provider |
| Web | Download request/upload | No automatic folder backup; check saved file; quota/eviction runtime pending |

Cloud backup folder is not conflict-aware sync. External backups, recovery copies
and historical session snapshots are not securely erased by Trash/delete-all.
Host tests cover invalid/future files, roundtrips/migrations, cancellation/failure,
copy-merge/replacement/recovery and SQLite reopen. Real providers/process kill/
power loss remain acceptance work. [Migration](MIGRATION_NOTES.md),
[sync](SYNC_ARCHITECTURE.md).
