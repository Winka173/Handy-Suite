# Handy Habit run14 — insights polish and R22

Source, host tests, host rasters and Android compilation are separate from OS delivery.
No devices, emulators, browser runtime, real store transactions or git writes were used.
Schema8 / physical2 / sync protocol1 stay unchanged. No shared package was modified.

## Insights

- Each section leads with its computed finding; supporting figures retain denominators and dates.
- Method text is in one disclosure per section. Goal cards use one sentence, Accept / Not now and a quiet tomorrow note. Mood is one sentence per habit with a small never-causation footnote.
- English/Vietnamese short dates and ranges are shared by the screen/PDF. Preview shows the friendly Settings zone; PDF omits the zone. No visible ISO dates or raw IANA IDs.
- Five filters remain behind compact scrollable chips, with active count/Clear and localized weekday names. Selected outcomes filter dates, not historical records.
- Focused heatmaps reuse the yearly calendar: 48px cells, weekday alignment, habit colours, neutral missed days and hollow unknowns. Tap opens counts/date details; one legend.
- Desktop comparisons pair side by side. Narrow layouts keep one scroll column. Methods, filter sheets and dates remain readable at text1.5.

## Platform behavior

| Surface | Implemented | Limits / supervisor verification |
| --- | --- | --- |
| Android reminders | Habit/routine rules; quiet hours; private text; explanation before permission; flexible inexact scheduling; earliest50 within400 days; refresh on opening/changes | No exact-alarm request or exact-time promise. Permission/revoke/channel/lock screen/battery/force-stop/reboot delivery needs device checks. |
| Diagnostics | Permission; Android exact/battery read-only facts; links to notification/battery system Settings; device-local last successful schedule/next plan/count; Test/Retry/Refresh | Unknown/denied/error/loading/unsupported states are distinct; a prepared schedule is not delivery proof. Timestamps live in preferences, excluded from data backups/sync. |
| Windows | Kit app identity and Windows details wired for reminders/test/paused runs; system Settings link | Permission on/off cannot be read. Source wired only; no Windows toast runtime claim. |
| iOS | Existing permission/local notices retained; settings link | No iOS build/runtime on this Windows host. |
| Web | In-app planned reminders; unsupported OS notification switches hidden | No background notifications. |
| Android widgets | Today progress / selected habit / routine launcher; compact and large RemoteViews; system light/dark and three Pro studio palettes; names privacy; refresh after app changes/open | Same selection for every instance of a type. Quick check-in opens Habit with Undo; amounts/reduction open for review. Routine opens Start/Resume. No background writer, pin/install claim or midnight refresh while closed. Launcher controls timing/resize; long names can truncate. |
| iOS / Windows / Web widgets | Settings previews and accurate platform note | No native provider supported by this kit. |

Widget/notification payloads explicitly select strings/counts/IDs; habit notes, routine steps and mood notes never enter them. Removed/archived selections cannot silently change to a different quick-check-in target. Pro loss restores free palette while retaining preferences.

## Verification and visual critique

- App265 / engine191 pass `flutter test --no-pub`; all18 new run14 tests cover dates, filter count/Clear, 48px details, diagnostics states/system links, private/flexible native scheduling and three widget feeds/row clearing. Both analyzers clean.
- Render matrix: EN/VI × light/dark ×320/390/1440 ×text1/1.5, plus six palette and four synthetic permission-state previews. `tool/run14_screens_test.dart` uses production screens with labelled synthetic history/OS/store fixtures.
- First pass found clipped diagnostic subtitles and long app-bar labels at320/text1.5, a desktop stack wasting horizontal space, and a PDF heading orphan. Fixed with full-wrapping rows, shorter app-bar labels, paired desktop findings, aligned yearly heatmaps and inseparable PDF heading/evidence. Re-rendered; actual PDF text is decoded independently.
- Artifacts: `apps/handy_habit/build/run14/index.html`; six summary shots in `sheets/01-insights.png` through `06-widgets.png`; per-case matrix sheets, raw round1/final rasters and 24 actual PDF first pages. Reproduce with `tool/run14_contact_sheets.py`.
- Debug APK built with `--dart-define=HANDY_DRIVE_SYNC=true`; native widgets/diagnostics compile. Build-only evidence. The home_widget KGP future-compatibility warning remains upstream; no plugin upgrade in this slice.
- Export tests rewrite `docs/qa/evidence/habit-export`; originals are restored byte-for-byte after verification.

## Supervisor device pass

1. Android: grant/deny/revoke, global and per-rule enable, quiet hours, pauses, private lock screen, exact status without request, battery link and delayed/blocked delivery, Test, reboot and app upgrade.
2. Launcher: add all three types, resize compact/large, tap binary/count vs amount/reduction, Undo, routine Start/Resume, delete/archive selection, names off, Pro loss, all palettes/light-dark, locale changes and reopen after midnight.
3. Windows: actual toast scheduling/show/cancel and system-disabled notices; iOS permission/passive paused-run behavior on owner toolchain.
