# QA evidence and reproduction

## Current R17/R18 host pass · run10 · 2026- 11-10

- App 187/187 and engine 175/175: `flutter test --no-pub --reporter expanded` in each package. Logs: root `build/habit-run10-app-tests.log` and `build/habit-run10-engine-tests.log`.
- `dart format --output=none --set-exit-if-changed lib test` and `dart analyze lib test` clean in both; app screenshot harness is also formatted/analyzed.
- New engine `routine_rules_test.dart`: 17 cases for each condition, branches/Undo, blocks/presets/remap, dependencies/stacking, weekday durations, time budget/foreground elapsed, frozen inputs/closed traces, true v1–v7 JSON+ZIP migration, nested sync merges/convergence and past-session preservation.
- New app `run10_advanced_test.dart` + `google_authorization_test.dart`: 9 cases covering Basic default/reveal/badges/non-saving demo/Pro edit and entitlement loss/free existing run/skip+branch explanations/stack prompt/atomic blocks+presets/SQLite restart; SDK fake asserts no client IDs and exact appdata authorization/denial/expiry/forget/revoke.
- `SHOTS_DIR=.../apps/handy_habit/build/run10-shots flutter test --no-pub tool/run10_screens_test.dart`: 24 passes, 168 PNGs plus six contact sheets; EN/VI × light/dark ×320/390/1440 ×text1/1.5. Basic/Advanced/free badges/demo/condition/branch/summary. [Critique and fixes](R17_R18_REVIEW.md).
- 11 pre-existing files under `docs/qa/evidence/habit-export/` restored from a pre-test copy and SHA-256 checked. No git writes, devices, browser runtime, secrets, signing or store operations. Android clients table and Google Play section verified unchanged.

## Current R15/R16 host pass · run 9 · 2026- 11-10

- App178 / engine158 tests pass; both `dart analyze` clean; `dart format` clean. Engine28 sync tests plus a new schema6 migration case; app11 controller +7 HTTP +4 gate/route/review tests added. Schemas1–6 migrate to7; physical2.
- Cases: simultaneous check-ins/incidents; three-device six-order convergence; binary provenance/cap; absolute versus addition; absolute/skip review; remote/local Undo; concurrent mood edit/removal/review; habit fields/schedules/archive; Trash/edit/restore/duplicate Trash/purge/redaction; routines/steps/linked idempotence/sessions; duplicate IDs/sequences; clock skew; base ancestors; concurrent/interrupted uploads; corrupt/truncated/checksum/missing download/newer schema and version receipt refusal.
- Controller: opt-in/cancel, local preferences, offline pending/retry, edits in flight, metadata corruption, restart, foreground/debounce, auth/quota, off/disconnect/rejoin and disable during upload. HTTP: appdata scope, paginated complete listing,401 refresh,503 backoff,quota,immutable multipart/read-back,duplicate bodies,partial pagination/network refusal.
- `tool/sync_screens_test.dart`:24 passing combinations, six states, top/detail/privacy;432 PNGs per pass in app `build/run9-sync-pass1` and `build/run9-sync-final`. [Critique/fixes](R15_R16_REVIEW.md).
- Android debug APK with HANDY_DRIVE_SYNC=true compiled, Google Sign-In plugin included and registered; no install. Scoped offline Dart dependency resolution and Android-only plugin generation avoided other-app edits; build used writable Gradle/Android/Kotlin cache homes. Logs under `apps/handy_habit/build/run9-*`.
- Owner still creates Cloud project/consent/Android clients/SHA-1/public web client ID. No actual OAuth, devices, browser runtime, iOS or store test. [Exact setup and supervisor cases](RELEASE.md). APK compilation is not Google authorization evidence.
- Export-test evidence is restored byte-for-byte after the final app test. Remote old generations retain payloads until manually removed; no compaction, E2EE or closed-app scheduling claimed.

## Current R14 host pass · run 8 · 2026- 11-10

- App156 / engine129 tests pass; both `dart analyze` clean and changed Dart files formatted. Schema6, physical SQLite/IndexedDB2; old schemas1–5 and CSV formats preserved.
- Two-tap/optional/skip/edit/delete/Undo/Restore, preference hiding/unaffected habits, failure/busy/retry, privacy payloads, glyph cmap and real SQLite reopen are host tested. [R14 review](R14_REVIEW.md) records decisions and limits.
- `tool/mood_screens_test.dart`:25 cases,145 PNGs, EN/VI × light/dark ×320/390/1440 × text1/1.5, after critique fixes. Six surfaces per combination: unlogged/logged/hidden Today, quick sheet, details, Progress; plus day2 glyph capture. Folder/index/contact sheets: `C:/Users/Winka/AppData/Local/Temp/habit-run8-shots/`.
- Logs: Temp `habit-run8-app-tests.log`, `habit-run8-engine-tests.log`, `habit-run8-shots.log`. Export-test QA evidence restored byte-for-byte; no new evidence retained there.
- No devices, emulator, browser runtime, build or store tests in this run. Supervisor: upgrade/restart/IME/back/SR, native backup/provider restore, lock screen and IndexedDB/quota/tab checks.

## Current R10/R11 host pass · run 6 · 2026- 11-10

- App `flutter test --no-pub`: **138 passed** (9 R11 widget tests + 1 SQLite negative persistence/Undo test added). Engine: **103 passed** (21 negative tests added).
- App + engine `dart analyze`: clean; `dart format` and final unchanged-format check cover app lib/test/tool and engine lib/test.
- Schema5 / physical2: incidents, explicit zero/unknown, day/week open-close, skip/pause, recovery, causal retraction/conflict resolution, backfill, goal history, JSON/ZIP/CSV, v1–v4 JSON+ZIP fixtures, New York/Sydney DST spring/fall and 04:00 week closure; real SQLite reopen and durable Undo.
- `tool/run6_screens_test.dart`: 26 cases (24 locale/theme/width/scale combinations + 2 practice-placement checks); final matrix source is re-rendered after critique fixes. 242 PNGs (10 surfaces per combination + 2 practice shots). Folder `C:/Users/Winka/AppData/Local/Temp/habit-run6-shots/`, contact sheets under `review/` and `index.html` for browsing.
- Local logs: `C:/Users/Winka/AppData/Local/Temp/habit-run6-app-tests.log`, `habit-run6-engine-tests.log`, `habit-run6-shots.log`. Early concurrent Flutter invocations hit the shared test-cache compiler race; those were stopped and all final invocations run serially per package.
- [Visual critique](R10_R11_REVIEW.md). No device, emulator, real browser, store, new build or OS delivery checks in this run. Historical platform evidence below does not certify changed source.

## Current R8/R9 host pass · run 5b · 2026- 11-10

- App `flutter test --no-pub`: **128 passed**; engine: **82 passed**.
- Both `dart analyze` clean; `dart format --output=none --set-exit-if-changed`
  clean on app lib/test/tool and engine lib/test. Two inherited unformatted app
  files (app.dart/scope.dart) received formatting only.
- `tool/run5_screens_test.dart`: **25 passed**, comprising 24 combinations of
  EN/VI × light/dark × 320/390/1440 × text 1/1.5 and one real-animation gather
  check. First matrix passed before the final frame-clipping fix; full final
  matrix passed after it. **949 PNGs**: 912 surface captures, 36 enlarged-text
  picture continuations, one animation midpoint. Includes all 15 help articles,
  all seven practice states, search/no match, every Settings group and empty Today.
- Captures/review board: `C:/Users/Winka/AppData/Local/Temp/habit-run5-shots/5b/`
  (`index.html`, contact sheets under `review/`). Logs in the same Temp root:
  `habit-5b-app-final.log`, `habit-5b-engine-tests.log`,
  `habit-5b-matrix-final.log`. These are local artifacts, not checked-in evidence.
- New regression checks friendly GMT labels, current DST and half-hour offsets;
  existing help test now verifies unnumbered filtered / numbered complete lists.
  Replay/practice unchanged-state-and-backup, all microsteps, keyboard/back,
  persistence/failure/reset and permission opt-in regressions still pass.
- [Visual critique and remaining device work](R8_R9_REVIEW.md). Host widget
  rendering only; no device/emulator/browser/store checks or new builds in 5b.
  Historical platform evidence below does not certify the changed source.

2026- 11-01, Flutter 3.44.9 / Dart 3.12.2, Windows host. Baseline before schema/config
changes is preserved in habit-baseline-*. Initial Spend analyze errors were pre-existing;
current full-workspace analysis passes after concurrent existing-app work. No unrelated
app was reset or deleted. Work is on real Flutter implementations, not production mocks.

## Executed

- 38 engine tests: four recurrences, exact quantities/types, calendar bounds,
  UTC/DST/year/week boundaries, strict/weekly/open/skip semantics, filtered partial
  weeks, immutable schedule targets/week starts, archive pauses, backfill and retries.
- 20 app tests: real SQLite migration/WAL/FK/CAS/reopen; actual SQL-trigger failure
  rolls back event and session together; unknown/corrupt bytes preserved; 100 habits,
  100 routines, 10k events and 1k sessions; controller commit/error/Undo behavior.
  Creation/check-in/cancel, Lite/runner and background/recovered timer tests. Real
  PDF/CSV/MD/JSON/ZIP bytes EN/VI with cancellation and roundtrip validation.
  Four accessibility cases cover all four main areas, light/dark, 390/1440 widths:
  contrast, Android/iOS target size and accessible labels. Tabs also fit 320/768/1024/1440.
- Remaining 27 workspace packages passed their host tests. Combined: 1,775 passed,
  28 platform-conditional skips, 29/29 packages. These are host tests, not 1,775 native
  device tests. Full workspace analyze and Habit analyze pass.
- Five actual-font widget screenshot tests; 29 widget captures plus six Android
  emulator captures = 35 images / 36-page review PDF. Native capture source is
  HandyHabit_QA_API35, Android API35 x86_64. No physical-device claim.
- Android: native SQLite check-in/reopen, linked exactly-once completion, original
  Lite template preservation, ZIP roundtrip/corrupt refusal, integrity and paused resume.
  A two-launch force-stop/reopen scenario checks different process IDs, one persisted
  linked event, preserved cursor and paused/recovery warning. Notification deny/grant,
  maximum 50 pending schedules, generic bodies, immediate display and cancellation.
- PWA worker is tested in Node VM, separately from Web compilation. This does not
  prove IndexedDB runtime, offline installation or browser eviction/quota behavior.

Review [final audit](../qa/evidence/habit-qa-audit.json) before using artifacts.
It checks current app/shared-source fingerprints, actual driver responses, APK/AAB/MSIX
checksums, all test-package coverage and screenshot/PDF hashes. `success` is a local
candidate-evidence result; `releaseReady` remains false.

## Exact entry points

From each package: `flutter test --no-pub`. Run separately in
`packages/handy_habit_engine` and `apps/handy_habit`; invoking native SQLite tests from
workspace root lacks that app's native-asset hook context. `dart analyze lib test tool
integration_test` in the app. `dart run melos run analyze --no-select` for workspace.
Other packages: `dart run melos exec --concurrency=1 --dir-exists=test
--ignore=handy_habit --ignore=handy_habit_engine -- flutter test --no-pub`.

Set FLUTTER_ROOT to the installed SDK, then `flutter test --no-pub tool/screens_test.dart`
in the app. `python tooling/habit-ui-review.py` packages actual images.
Build using `tooling/flutter-builds.ps1 -Apps @('habit') -Target web|windows|apk`;
`tooling/flutter-msix.ps1 -App habit`; `tooling/habit-aab.ps1` for unsigned release AAB.
For an owned HandyHabit_QA_API35 emulator on 5570 only: `tooling/habit-native.ps1`,
`tooling/habit-notifications.ps1`, `tooling/habit-recovery.ps1`.
Audit: `python tooling/habit-qa-audit.py`.

## Findings fixed and harness limitations

Recovery originally notified the controller during widget build. It now starts after
frame one; a regression test and different-process Android scenario verify the fix.
A weekly date filter could include check-ins before its selected range; partial first
weeks are now excluded. Reminder lookahead originally missed 90-day intervals; it now
looks 400 days ahead, limits 50 OS schedules / 200 reminder rules, and tells the user to
reopen for refresh. Long foreground elapsed time is bounded rather than rejected at 24h.

ADB transport intermittently disconnects on this emulator. Failed original logs are
preserved. Reconnect helpers require the original surviving PID, unchanged source,
VM identity and a real successful driver response; log text alone never counts as pass.
Recovery tests use --keep-app-running, then an explicit force-stop: Flutter drive's
default successful cleanup uninstalls the app, which would invalidate a persistence test.
Test file sinks exercise actual export bytes; they do not prove OS picker access.
PDFs are additionally decoded with PyMuPDF; Vietnamese title/numbers and missing-glyph
checks are in habit-export/pdf-decoded.json. Large-data timings are host samples, not
Android frame-rate or browser performance certification.

## Not verified / release prerequisites

macOS/Xcode/iOS build; physical devices; TalkBack/VoiceOver/Windows Narrator and extreme
text scaling; real OS document providers/share destinations; storage exhaustion/power
loss/low-memory process kills; delayed/reboot reminder delivery; browser IndexedDB quota,
eviction, install/offline/update lifecycle; official store purchase/restore/refund,
consent, release signing/identities and store approval. Windows MSIX is unsigned and
MakeAppx-validated, not installed or Store-approved. No guarantee of precise background
notifications/timers. SQLite and backups are unencrypted; local access controls only.

Notification-denied UI capture exercises the production permission button and actual
SQLite settings with POST_NOTIFICATIONS revoked and USER_FIXED on the dedicated QA
emulator. Grant tests clear these flags and use the real OS plugin. This proves denied
handling, not a human interaction with the OS permission dialog. A final linked-mapping
regression rejects fractional counts on import and active sessions; archived links are
visible as inactive and step completion does not fabricate a check-in.


## R12/R13 run 7 host evidence

- App: `cd apps/handy_habit; flutter test --no-pub` —145 pass (`build/run7-app-tests.log`).
- Engine: `cd packages/handy_habit_engine; flutter test --no-pub` —119 pass (`build/run7-engine-tests.log`). Both scoped `dart analyze` clean; `dart format --output=none --set-exit-if-changed lib test` unchanged.
- Render: from app, `$env:SHOTS_DIR='build/run7-shots'; flutter test --no-pub tool/run7_screens_test.dart` —24 matrix tests,336 PNGs; `build/run7-shots.log`. See R12_R13_REVIEW.md for fixture, critique and limits.
- New regression coverage:16 engine cases in template_catalog_test/run7_progress_test, seven widget flows in run7_library_progress_test; earlier template/negative tests updated to current requirements, no deletion/skip. Save-error/busy/stale tests remain.
- No device/emulator/browser/store check performed in run7; native/SR/browser/platform follow-up remains with supervisor. No claims from host pictures about OS permissions or persistence runtime.


## Run14 / R22 — 2026-11-11

App265/engine191 host tests,18 new run14 cases; both analyzers clean and scoped format check.
24 matrix cases plus a supplemental palette/permission render case; actual PDF pages decoded
for EN/VI short dates, no ISO/raw zone, and heading/evidence page integrity. Debug APK with
Drive define compiles. Review: [R22_REVIEW](R22_REVIEW.md); artifacts under
`apps/handy_habit/build/run14` (index, six summary sheets, raw rasters, PDFs, logs).
No device evidence: supervisor owns notification permission/reboot/exact/battery/delivery,
Windows/iOS notices and Android launcher placement/resize/theme/refresh/quick check-in.

## Run15 / R23–R26 — 2026-11-11

App287/engine201 host tests pass, including deterministic rule effects, separate
Undo for simultaneous rules, automatic save errors, schema8 ZIP migration,
typed storage capacity refusal, WAL process termination and folder publication.
Both analyzers clean; scoped format verification includes lib/test/tool.
Render24 matrix cases /216 PNGs; performance4 widgets and durable1 host test
pass separately. [Review](R23_R26_REVIEW.md), [host numbers/limits](PERFORMANCE.md).
APK command with `HANDY_DRIVE_SYNC=true` reached debug signing but failed on
access denied to `debug.keystore.lock`, including a fresh workspace Android home;
no current APK success, install or device check claimed. R26 remains partial.
Browser delta transactions are source/analyzer checked; actual IndexedDB runtime,
two-PC cloud-folder behavior and release/device timing remain supervisor gates.
