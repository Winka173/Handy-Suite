# Settings inventory

Source: `lib/settings/settings_page.dart`, `settings_parts.dart`, `about.dart`,
`design/studio_page.dart`, `sync/` and kit backup settings. Actual controls only.

| Group | Controls / effect | Gate / default |
| --- | --- | --- |
| Sync | Windows Sync through a folder: choose, on/off, Sync now, status/error | Windows, Free, opt-in; device metadata |
| Convenience | Local rule add/enable/remove/history/Undo; Batch changes | Pro effects/apply; disabling Free; saved views live in Habits/Progress |
| Appearance | Studio preview/apply; System/Light/Dark; System/EN/VI; Comfortable/Compact; Reduce motion | System theme/language, comfortable, override off; OS reduced motion wins; Studio apply Pro |
| Habit preferences | Default daily/weekday schedule; count/amount default 1/3/8/10; Calendar: IANA zone, Monday/Sunday start, day boundary 00:00–23:59, backfill 1–3660 days | Daily/goal 1; stored clock policy retained; old dates never shift |
| Routines | Auto-start timers; completed-step haptics; exit confirmation | Timer on, haptics off, confirmation on; haptics switch Android/iOS only; Basic/Advanced in builder |
| Mood | Show mood on Today; mood help | On; hiding retains data |
| Home screen | Widget previews, selected habit/routine, names/privacy | Native Android; selection shared per type; other platforms explain preview limits |
| Pauses | Add/edit/end early/delete; help | Free, empty state when none |
| Notifications | Global reminders; paused-run notice; quiet hours; private text; per-habit/routine time/weekdays/enabled/snooze; add/edit/remove; test/retry/diagnostics | Native only; context before permission; names hidden by default |
| Diagnostics | Permission; Android exact/battery facts/links; last successful scheduling; test/retry | No pretend OS toggles; Windows permission unreadable; Web OS controls absent |
| Data | Automatic backup; gated Android Drive Sync; backup help; Trash; recover before last replace; ZIP/JSON/import backup or CSV/integrity | Free; Drive Android + define; recovery if checkpoint exists |
| Automatic backup | Enable, supported destination, daily/weekly, retention 3/7/14/30, encryption, status/error/Backup now | Device preferences, excluded from library backup/sync; Web manual only |
| Reset | Reset preferences; delete all local Habit data with strong confirmation | Reset keeps library/reminders/pauses/purchases; external copies not deleted |
| Pro | Status/benefits/native price/purchase/restore states | Android checkout; no developer grant toggle |
| Help & Learning | Searchable How to use; replay guide; What's New | Free, disposable practice |
| Privacy & About | Version/build/retry; policy; licences; support; More Handy apps | Policy publication pending owner; support apps.winka.studio@gmail.com; More apps hides absent listings |

Writes use immutable settings/controller persistence and retain failed drafts.
Reset removes only `habitPreferenceKeys`: Studio, mood prompt, theme/language,
density/motion, week/day/backfill, default goal/schedule and three routine options.
It retains time zone and device backup/sync configuration. There is no sound picker,
biometric lock, custom streak formula, independent negative-presentation switch,
health permission or cache-clear control.
