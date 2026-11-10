# R14 mood — host review, 2026-11-10

Source implemented, engine/unit tested, widget tested and real SQLite tested on the Windows host. No emulator, device, browser runtime or store verification in this run. Schema5 →6; physical SQLite/IndexedDB stays2. No shared-package changes, git writes, devices or secrets.

## Product and data decisions

- Today keeps habits first and adds one quiet optional line after them. Tap the line, then a labelled feeling to save. No keyboard, note, energy, tag or mood entry is required for habits. Turning off Show mood on Today preserves history. Progress follows its selected range, independently of the habit filter.
- One entry per local date; required mood1–5, optional energy1–5, note<=4096, up to8 distinct trimmed tags<=40. Revision guards, strict timestamps, stable date IDs, immutable rows and causal ancestry support later sync. Transport/correlations remain later slices.
- Delete retains a recoverable payload in mood history, outside habit Trash and its30-day expiry. Undo and Restore preserve details. Re-logging a deleted date starts with blank optional fields; Undo can recover the deleted payload. There is no individual permanent-mood-delete action in R14.
- JSON/ZIP/sealed/automatic backups and durable pre-replace recovery carry mood. CSV includes a separately validated table, including deleted entries. Identical same-date moods deduplicate; conflicting dates stop merge/import before writes. Old schemas1–5 and old CSV records remain readable, without rewriting old habit/event payloads.
- Notes remain local and in user-chosen exports; local data and plain backups are unencrypted. Reminder/paused-run/home-widget paths do not include mood. No new permissions, health claims or Pro gate. Help has17 bilingual searchable topics.

## Visual critique and fixes

Both required UI skills were read from the specified local paths. The R14 design contract preceded implementation in Habit's section of UX_REDESIGN.md. Boards' focused card sheet and Bookmark's help/settings source supplied sibling mechanics; Habit's Nunito, oxblood/vermilion/ochre and bead signature remain its own.

- Question/hierarchy: Today still leads with habit beads; mood is one line after habits. Quick logging presents five words with identical styling, rather than red/green scoring or font emoji. Details disclose optional fields only on request. Progress leads with dated labels, with no invented average or inference for missing days.
- Edges/density: the first pass truncated the long Vietnamese sheet title at320px/150%. Short Mood/Tâm trạng fixes it; detailed editing uses the entry date as its title. A single Skip avoids duplicate Cancel/Skip actions in the quick view. Optional details keep the existing pinned Save, scroll and dirty-draft guard.
- Desktop: the first pass put mood under the long habit/routine column, leaving unused space beside it. The final pass puts history below the calendar in the left column. The560px desktop dialog stays bounded, while narrow layouts use a full page.
- Typography/colour: actual bundled Nunito and Material icons loaded; all five mood states use words with equal visual weight. EN/VI, light/dark,320/390/1440 and text1/1.5 wrap without render exceptions. The final matrix follows the fixes; contact sheets cover every combination.
- Calendar: unsupported U+25CB is completely removed from the month cell. A drawn hollow ring sits below day2. The regression test renders EN/VI calendars and checks every Text rune against all bundled Nunito cmaps, while separately requiring the drawn unknown mark.
- Arithmetic: the unchanged fixture has6 habits and2 routines; mood fixture logs7 dates, deletes one. Since today is2 November, the selected November view honestly contains2 live dates. Habit names are user content and remain Vietnamese in both locales. No typed independent totals.

## Validation and artifacts

- App `flutter test --no-pub`:156 passed. Engine:129 passed. Both `dart analyze` clean; changed Dart files formatted, final unchanged-format checks clean.
- Added app checks: two-tap/no-keyboard/no-note, skip/Esc/dirty draft, edit/delete/Undo/Restore, hidden prompt with unaffected habit check-in, save failure/busy/retry, re-log after deletion, history range/Show all, notification/widget payload independence, real SQLite reopen/Undo and two bundled-font glyph checks.
- Engine checks: scales/date/tags/note/IDs, stale revisions, monotonic edits/delete/restore, causal Undo/newer-edit refusal, JSON/ZIP/CSV/tamper/range, all five older JSON+ZIP formats, deduplication and conflicting-date refusal. Existing119 engine tests remain green; old schema-output expectations now say6.
- `tool/mood_screens_test.dart`:25 passed, comprising24 matrix combinations ×6 surfaces plus the calendar glyph case:145 PNGs. Folder: `C:/Users/Winka/AppData/Local/Temp/habit-run8-shots/`; `index.html` and `review/` contact sheets are local review artifacts.
- Four representative shots: `390-en-light-100-today-logged.png`, `320-vi-dark-150-log.png`, `320-vi-light-150-details.png`, `1440-en-light-100-progress-mood.png`. Calendar: `1440-en-light-100-progress-month-glyph.png`.
- Logs: Temp `habit-run8-app-tests.log`, `habit-run8-engine-tests.log`, `habit-run8-shots.log`. Export-test evidence is restored byte-for-byte after tests; no regenerated QA evidence is retained.

Supervisor still needs native upgrade/restart/restore, IME/back/swipe, screen reader, actual lock-screen delivery and real IndexedDB upgrade/quota/tab checks. Existing platform/build/store evidence is historical and does not certify R14.
