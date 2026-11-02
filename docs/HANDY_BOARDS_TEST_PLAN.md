# Handy Boards test plan

Latest host run (2026-11-02): **48 engine + 31 app tests PASS**, both analyzers clean.
Actual logs: `docs/qa/evidence/boards-engine-tests.log`, `boards-app-tests.log`,
`boards-engine-analyze.log`, `boards-app-analyze.log`. The source/artifact-bound
summary is `boards-checkpoint.json`; inspect its `current` checks.

```powershell
Push-Location packages/handy_boards_engine
dart analyze
flutter test --no-pub
Pop-Location
Push-Location apps/handy_boards
flutter analyze --no-pub
flutter test --no-pub
Pop-Location
python tooling/boards-validate-exports.py
```

Engine coverage: UUID/category-status independence; subtree moves, independent
trash restore, duplication; custom defaults; Unicode; all-day/timed range and DST
gap/fold rejection; seconds-preserving reschedule; bounded recurrence/restart;
dependency cycles/path; grades; persisted focus and midnight allocation; bounded
app-open rules, pure preview, reminder/generation actions and execution tokens;
ZIP/JSON/assets/checksum/path guards and reference-only merge; CSV/Markdown;
safe template/subtask/default clone with double recurrence opt-in; malformed images; typed malformed backup/preferences; weekly aggregation;
retained-history timezone boundaries; zero-duration milestones; dependency-date
conflicts; mixed deadline ordering; plain-text grade threshold validation.

App coverage: native SQLite reopen/integrity/future-schema/CAS/rollback/Undo;
four-category and Kanban parity; Today/Calendar identity; capture error retains
input; six responsive widths/VI; Study target; focus; genuine Pro gate plus
test-owned native channel for advanced rendering; Table edit/Undo; rule preview
cancel/save; typed multi-select; week/day calendar identity; repeated-property saved-view OR
conditions and backup-preserved layout. No fixture is used
to unlock production.

Independent PyMuPDF/openpyxl validates three real PDFs + XLSX and records hashes.
Performance at 100/1000/10000/50000 tasks is measured host time/RSS in
`boards-performance.json`, not a mobile performance guarantee.

```powershell
$env:SHOTS_DIR='../../review-shots/boards'
$env:FLUTTER_ROOT=(Split-Path -Parent (Split-Path -Parent (Get-Command flutter).Source))
Push-Location apps/handy_boards
flutter test --no-pub tool/screens_test.dart tool/detail_screens_test.dart
Pop-Location
./tooling/boards-native.ps1 -Phase write
./tooling/boards-native.ps1 -Phase read
```

97 widget screenshots: seven basic screens plus editors/advanced tools, bundled fonts, 320/375/430/768/1024/1440,
dark mode and 200% Vietnamese. Includes task detail/editor, rule editor, export, Study, Focus, week Calendar and six advanced tabs at phone/desktop/200% VI. Error states are not exhaustive.
Native runner uses dedicated emulator 5570 (`HandyTrip_QA_API35`) and QA-only
`boards-qa.sqlite`. It creates Study/four categories and a task, changes status via
UI, sets due/checklist/subtask via controller, checks backup equality, then restarts
and checks identity/integrity. Driver transport disconnect/recovery is recorded
separately; recovery reads the same running test's actual result. Native images:
`docs/qa/evidence/screenshots/boards-native-*.png`.

Still required: external share/extension cancel/delivery; permission deny/grant,
reminder tap/background delivery; native gestures; browser quota/multi-tab/PWA;
Windows installed UI; iOS/physical devices; official purchases/refunds/consent.
The full master scope remains IN_PROGRESS. No blanket bug-free claim.

Latest native rerun: a temporary ADB-offline read failure is preserved as
`boards-native-read-offline-failure.json/.log`. The subsequent fresh read returned
real success (transport exit 0), checked persisted task IDs and SQLite integrity.
Do not discard the failed attempt or infer success from its log.
Added real SQLite 1 MB asset byte reopen/removal/persisted Undo test.

Use `./tooling/boards-shots.ps1` for source-bound screenshots: it requires all
97 PNGs to have been written during that passing run and records exit/source hashes.
Use `python tooling/boards-checkpoint.py` only after host/native/build/shot/export
checks; stale source, changed artifacts or failed evidence make it exit nonzero.

Exam continuation: 48 engine + 31 app tests. Dedicated exam form edits date/time,
duration/location/materials on the existing task, preserves category/UUID and
round-trips backup. Duration 1..1440 minutes is validated; file/reminder actions
reuse task detail. Review suite now has 97 widget PNGs plus six emulator PNGs.
The newest native driver also disconnected after finishing tests; the same-process
reconnect retrieved its genuine success/report. Inspect per-run transport fields.

Localization/accessibility batch: 48 engine + 31 app tests. Added Vietnamese
priority/weekday labels, DST error with retained input, form switch/date/select
semantics, checkbox task identity, Ctrl+Enter exactly-once save, and a timed UTC
deadline crossing into the prior local day. Date labels use Flutter's locale
formatters after conversion to the board timezone; portable ISO payloads are
unchanged. Unknown errors retain their diagnostic text; full error localization
and physical TalkBack/VoiceOver certification are not claimed.

The latest batch reruns host tests, fresh screenshots and Web build/worker QA.
Prior native/Windows/AAB/MSIX evidence remains source-stamped. A successful
uiWebChecksCurrent is deliberately separate from allRecordedChecksCurrent; stale
native artifacts keep the full checkpoint check nonzero. Do the full platform
release sweep after the remaining source changes, not after each small UI edit.

Conditional export field verification: template-only recurrence settings remain
hidden for other formats. Hidden fields do not block saving an unrelated format.
Large-text boolean labels occupy the full dialog width with their controls below,
avoiding the narrow label column seen in screenshot review.

Remaining-work verification (2026-11-02): 52 engine + 41 app cases, plus two real
Edge/Chromium IndexedDB tests. The latter use dart test rather than Flutter's
Windows CanvasKit test server; no simulated IndexedDB is used. New tests cover
v1 upgrade failure rollback, lazy immutable assets, Undo after deletion, competing
writers, async ZIP/JSON round trips/cancel, SQL indexed paging/filter parity,
actual native paged UI refresh, immediate/cancel progress dialogs, 33 MB native
ZIP stage/replace/merge, captured-revision export and worker cancellation.
Run ./tooling/boards-browser.ps1 and ./tooling/boards-performance.ps1 separately.
The performance test creates 50000 fixture tasks in a disposable test database;
it never seeds production user data. Reported RSS includes fixture/test VM memory.
Screenshot suite now requires 103 fresh PNGs including Study reports and working
calendar at 320 px/200% text. Production source starts empty.

Data-volume interpretation: stress fixtures (50000 tasks, 33 MB backups) live in
fresh test-owned temporary databases/directories and are removed by teardown.
Review PNGs and build outputs are QA/release artifacts, not default user content.
The APK/AAB still contains runtime libraries/fonts/platform plugins; artifact
size must be assessed independently from fixture or source-repository size.
