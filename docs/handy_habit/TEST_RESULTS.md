# R27 host test results — 2026-11-11

Windows host, Flutter 3.44.9 / Dart 3.12.2 workspace. No devices, Android Gradle,
iOS build, actual browser, release build, actual OAuth or store transaction used.
App6 new tests raise287→293; engine unchanged201. Commands below are run from
the indicated package; fixture verification from repo root.

| Directory | Command | Result | Log / artifact |
| --- | --- | --- | --- |
| `apps/handy_habit` | `flutter test --no-pub --reporter expanded` | 293 pass, no skips/failures | `build/run16-app-tests.log` |
| `packages/handy_habit_engine` | `flutter test --no-pub --reporter expanded` | 201 pass, no skips/failures | `build/run16-engine-tests.log` |
| App | `dart analyze` | No issues | `build/run16-app-analyze.log` |
| Engine | `dart analyze` | No issues | `build/run16-engine-analyze.log` |
| App | `dart format --output=none --set-exit-if-changed lib test tool` | 151 files, 0 changed | `build/run16-app-format.log` |
| Engine | Same format command | 33 files, 0 changed | `build/run16-engine-format.log` |
| App | `flutter test --no-pub test/run16_release_test.dart --reporter expanded` | 6 pass; also included in293 | `build/run16-focused.log` |
| App | `flutter test --no-pub tool/store_shots_test.dart --reporter expanded` | 2 pass,12 PNGs | `build/run16-store.log`, `build/store/` |
| App | `SHOTS_DIR=build/run16-shots flutter test --no-pub tool/run16_screens_test.dart --reporter expanded` | 24 pass,96 PNGs | `build/run16-visual.log`, `build/run16-shots/` |
| Root | `python tooling/verify-fixtures.py` | passed;21 fixtures,39 documented tools | Command JSON output |

Environment assignment above is shell shorthand. In PowerShell use
`$env:SHOTS_DIR='build/run16-shots'` or `$env:STORE_DIR='build/store'` before the
test command. STORE_DIR defaults to `build/store`; relative paths are app-local.
Tool tests are separate from the app293; do not add the focused6 again.

New regression coverage inspects actual guide RenderParagraph font size/scaler
and transform at1080×2400/density2.6 and3, EN/VI, plus natural archive sentences.
The practice-title and wording tests failed before the fixes and passed after.
Existing batch tests retain exact selection/stale rejection/one durable Undo,
disabled reminders, entitlement and failed-write behavior.

Store renders use the real HabitApp with in-memory disposable library and bundled
Nunito/Material icons; Android platform presentation, device plugins disabled.
No fake Pro purchase, marketing overlay or external data is required. Sample:
three positive habits and one reduction habit with deterministic Jan–Nov2026 observations and
one three-step morning routine. Totals derive from actual engine projections.
Each EN/VI prefix has `01-today`, `02-history`, `03-runner`, `04-year`,
`05-templates`, `06-reduce`; each1080×2160 from360×720 at3x. No on-device/store
capture claim. Twelve PNG dimensions checked by the renderer.

Guide/batch visual matrix: EN/VI ×light/dark ×320/415/1440 ×text1/1.5;
story/practice/final/archive. Review artifacts live in `build/run16-shots/`.
Written critique: `build/run16-review.md`; six guide/batch contact sheets and two
store contact sheets accompany the rasters in the app build directory.
Historical major-screen render matrices remain in earlier R-series reviews.
Typography uses30 logical px phone/44 wide; visible glyph ink is smaller than em.
No density compensation or suppressed accessibility scale is introduced.

App export tests rewrite `docs/qa/evidence/habit-export/*`; all eleven files were
restored byte-for-byte from the session's initial copies, preserving pre-existing
changes. No git writes. RELEASE.md Google Play section was not changed.

Supervisor-reported previous binary startup/guide on two BlueStacks Android11
instances is limited emulator evidence. Final R27 physical-device, providers,
reboot/battery, browser/IDB, iOS, actual two-device/two-PC transport and real Play
purchase/restore remain unchecked. No new native-build result or daemon exists.
