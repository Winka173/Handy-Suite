# Platform capabilities — run 15

Matrix describes shipped source and gates. Host tests and Android compilation are
separate from OS delivery, real billing, cloud transport and release readiness.
Data schema9; SQLite/IndexedDB physical2; immutable sync protocol1.

| Capability | Android | iOS | Windows | Web |
| --- | --- | --- | --- | --- |
| Offline habits, positive/reduction goals, schedules, archive/trash/Undo | SQLite worker | SQLite source | SQLite worker | IndexedDB source |
| Today, backfill, pauses, streaks/core Progress | Free | Free source | Free | Free source |
| Basic routines, foreground runner, recovery, sessions | Free | Free source | Free | Free source |
| Advanced routine authoring; running saved plans | Pro authoring / Free running | Same gate; no checkout | Same gate; no checkout | Same gate; no checkout |
| Optional mood, energy, notes/history | Local / Free | Same source | Same source | Same source |
| Bundled habit/routine templates and collections | 44/11/13, Free | Same | Same | Same |
| Smart insights, suggestions, correlations, focused heatmaps, reports | Local / Pro | Same source/gate; no checkout | Same source/gate; no checkout | Same source/gate; no checkout |
| Studio themes/icons/Today/runner appearance | Pro apply / Free preview | Same gate; no checkout | Same gate; no checkout | Same gate; no checkout |
| Saved Habits and Progress views | Pro; local settings/backup | Same source/gate | Same source/gate | Same source/gate |
| Batch archive/collection/holiday/existing reminder time | Pro; checked preview/one Undo | Same source/gate | Same source/gate | Same source/gate |
| Routine-finish +1 / collection-holiday rules | Pro; foreground, named history/Undo | Same source/gate | Same source/gate | Same source/gate |
| Manual backup, validated restore, export | Free picker/share; ZIP/JSON/sealed | Files source | Native dialogs | Upload/download |
| Automatic folder backup | On open/background opportunities; picker | App Files location; source | User folder; source | Unavailable; manual only |
| Google Drive appdata conflict-aware sync | Free; HANDY_DRIVE_SYNC=true + owner OAuth | Unavailable | Unavailable | Unavailable |
| Sync through a folder | Hidden | Hidden | Free; off by default; chosen folder; R15 generations/merge | Hidden |
| iCloud sync | Unavailable | Unavailable; no adapter/entitlement | Unavailable | Unavailable |
| OS reminders | Permission/inexact schedule; diagnostics | Permission/local source | Kit toast source; OS on/off unreadable | In-app plan only |
| Diagnostics/system settings/Test | Permission/exact/battery facts and links | Permission/local source/settings link | Source; OS on/off unknown | Unsupported OS controls hidden |
| Paused-run notice | Native local source | Passive local source | Native toast source | Unavailable |
| Native home widgets | Today / One habit / Routine; compact/large/theme/privacy/Pro palette | Preview only | Preview only | Preview only |
| Widget check-in/Start/Resume links | Opens Habit; changes inside app | No native widget | No native widget | No native widget |
| Independent dynamic OS shortcuts | Not implemented | Not implemented | Not implemented | Not implemented |
| Health Connect / Apple Health completion | Not implemented; no dependency | Not implemented; no dependency | Not applicable | Not applicable |
| Lifetime purchase/restore | Native Play Billing; verified device cache; real transactions unverified | Unavailable | Unavailable | Unavailable |
| Ads/removal | Configured Android host; Pro removes ads | No supported checkout/ad host | No supported checkout/ad host | No checkout |
| Guide/searchable help/EN-VI/theme/keyboard/reduced motion | App source / host renders | Same source | Same source | Same source |

Rules do not chain, scan old finished sessions, or use a background scheduler.
They can be turned off without Pro. Replacement restore imports rules disabled;
copy-merge keeps receiver configuration. Definitions, saved views, clocks, reminders
and folder paths are not synced. Ordinary event/pause effects are synced. Named
rule history stays local/backed up. A missed holiday start is applied within the
editable backfill window when the app next opens; actual dates appear in history.

The user chooses a local Windows directory, optionally inside OneDrive or Drive
for desktop. The vendor client transports files; Habit performs the causal merge.
Local “merged” does not confirm delivery to another PC. Sync runs on open/resume,
Sync now, and debounced local changes; no idle filesystem watcher. Incomplete,
corrupt/newer files and unexpected conflict copies stop the merge. Turning off or
cancelling folder choice never deletes local data. No generation deletion/compaction.
This is separate from rotating Backup.

Reminders: ≤200 rules / earliest50 occurrences within400 days. Exact alarms are
not requested. Actual boot/battery/permission/delivery, Windows toast, iOS and web
quota/eviction/multiple tabs remain runtime gates. Widgets share selection per
type, open the app, and have no terminated-app midnight refresh. iOS needs owner
macOS/Xcode/signing; no iOS build was run here.

Windows adapter tests use temporary folders, independent host processes and
termination; two physical PCs and a real cloud-folder client remain unverified.
See [performance/capacity](PERFORMANCE.md) and [review](R23_R26_REVIEW.md).
