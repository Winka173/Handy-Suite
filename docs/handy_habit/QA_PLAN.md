# QA evidence and reproduction

## Current R8/R9 host pass · run 5b · 2026-11-10

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

2026-11-01, Flutter 3.44.9 / Dart 3.12.2, Windows host. Baseline before schema/config
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
