# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Flutter 3.44.9 / Dart 3.12.2 monorepo (Dart pub workspace + melos) of independent, local-first apps: no backend, no cloud AI. Business model is Free + Ads + Pro Lifetime. Project docs are mostly in Vietnamese. Targets: Android, iOS, Windows, Web (PWA).

Apps in `apps/handy_*`: `tools`, `docs`, `media`, `dev`, `keep`, `recall`, `bookmark`, `spend`, `habit`, `trip`, `boards` (README says "six apps"; `handy_bookmark` (named Handy Save until 2026-11-02), `handy_spend`, `handy_habit`, `handy_trip` and `handy_boards` were added later and are in the workspace; `handy_trip_engine` and `handy_boards_engine` are their engines).

## Commands

Run from repo root (PowerShell). Bootstrap must be used instead of plain `flutter pub get` on Windows — it retries resolution once per app and creates the Windows plugin symlink junctions:

```powershell
./tooling/flutter-bootstrap.ps1
dart run melos run analyze --no-select      # dart analyze in every package
dart run melos run test --no-select         # flutter test --no-pub, concurrency 1, packages with test/
```

Single package / single test (from that package's directory):

```powershell
flutter test --no-pub
flutter test --no-pub test/portable_zip_test.dart
flutter test --no-pub test/core_test.dart --plain-name "name of test"
```

Formatting is enforced in CI per package on `lib` and `test`:

```powershell
dart run melos exec --dir-exists=lib -- dart format --output=none --set-exit-if-changed lib
dart run melos exec --dir-exists=test -- dart format --output=none --set-exit-if-changed test
```

Run / build:

```powershell
Set-Location apps/handy_tools; flutter run -d windows
./tooling/flutter-builds.ps1 -Apps @('tools','docs','media','dev','keep','recall','bookmark') -Target web   # or windows | apk
```

Node 22.13+ / Python 3 tooling (QA only, not app code):

```powershell
npm ci --ignore-scripts
npm run typecheck          # tsconfig.tools.json
npm run format:check       # prettier over docs/config/tooling
python tooling/verify-fixtures.py
npx vitest run --config tooling/vitest.re2.config.ts          # RE2 web bridge only
npm test                   # RE2 + PWA worker tests; requires Web builds of the apps first
```

CI web builds use `--no-web-resources-cdn`, then `node tooling/flutter-offline.mjs <app>` before the PWA worker test (`vitest.pwa.config.ts -t '<app> worker'`).

Android emulator integration/screenshot runner: `./tooling/flutter-screenshots.ps1 -App media -Scenario editor -Device emulator-5558` (scenarios: native, pdf, capture, guide, recovery, conversion, camera-share, large-project, state, reader, parity, video-transform, editor).

## UI/UX rule (mandatory)

Every UI/UX change, whether a new screen, a flow, a component or a restyle, must be driven by the two installed skills. Invoke them explicitly; do not work from memory of them:

1. **`design-taste-frontend`**: these are app screens, so follow its `references/app-screens.md` run. Inventory the data and the user's jobs, name each screen's one question and finding, choose the style's "face" and **one signature element per app**, build, then critique the screenshots against §2.7 before reporting.
2. **`frontend-ui-engineering`**: write a design contract before code (job, primary action, states, responsive rules, patterns to reject). Cover empty, loading and error states, accessibility, and widths 320–1440.

The UI is being **rebuilt from scratch**. The old UI is a feature checklist only (with `docs/FUNCTIONS.md`), never a layout or flow reference. Do not carry over the old structure (list → push a page per item, bottom tabs or rail copied from the old app) unless the skill run justifies it. Write each app's contract in `docs/UX_REDESIGN.md` first. Every app ships on Android, iOS, Windows and Web, so each contract states its platform behaviour (navigation, back, shortcuts, adaptive controls, web URLs).

## Architecture

**Layering.** Logic lives in pure-Dart engine packages; Flutter UI lives in apps and `handy_ui`. Native capabilities (capture, camera, notifications, PDFium, store/ads) are reached through adapter packages so engines stay testable on the host.

- Engines (pure Dart, per app domain): `handy_tools_engine`, `handy_dev_engine`, `handy_docs_engine`, `handy_media_engine` (depends on docs engine), `handy_inventory` (Keep), `handy_recall`, `handy_bookmark_engine`.
- Foundation: `handy_core` (cancellation, portable ZIP with manifest/checksum/path checks, `sealed.dart` password-locked backups that are written without the password) → `handy_files` (bounded import/export, safe filenames; `auto_backup.dart` + `backup_folder.dart`: folder backups via SAF on Android (its own Kotlin plugin), the app's Files folder on iOS, any folder on Windows, none on web) → `handy_workflow` (cross-tool text workflows) → `handy_storage` (local snapshots, recovery, IndexedDB on web).
- Platform adapters: `handy_capture` (also Windows screenshots), `handy_scan` (QR only), `handy_ocr` (on-device OCR: ML Kit on Android/iOS, `Windows.Media.Ocr`; only Docs and Media depend on it, so the others don't carry ML Kit), `handy_pdf` (PDFium), `handy_notifications` (Android/iOS/Windows; Windows toasts are mirrored in preferences because the plugin lists pending ones by id only), `handy_home_widget` (Android home-screen widgets for Habit, Spend, Recall; the native `HandyWidget.kt` in each app only draws strings the app sends), `handy_store` + `handy_monetization` (purchases/ads/entitlements; per-platform `listingUrl` feeds "Other Handy apps").
- `handy_ui` is the shared UI package — **the app owns persistence**, `handy_ui` never stores user data.
  - **New design kit** (`package:handy_ui/kit.dart`, `lib/kit/`): theme, components, settings page, platform behaviour (page transitions, adaptive dialogs, haptics, named routes for web URLs). Rebuilt so far: **Tools** (a single-screen "bench", `apps/handy_tools/lib/bench/`), **Dev** ("Inspect | Requests", `apps/handy_dev/lib/inspect/` and `requests/`) **Keep** (things grouped by where they are now, `apps/handy_keep/lib/home/`, `item/`) **Recall** (Today + full-screen review, `apps/handy_recall/lib/home/`, `review/`) **Bookmark** (formerly Save: Not-sorted strip + places, `apps/handy_bookmark/lib/shell/`, `home/`, `library/`), **Docs** (a desk of unfinished work as paper stacks, `apps/handy_docs/lib/desk/`, `scan/`, `write/`, `pdf/`, `read/`) **Media** (a studio of guides shown as film strips, `apps/handy_media/lib/studio/`, `guide/`, `image/`, `capture/`; subtitles moved to Tools) and **Spend** (Today's free-to-spend figure over the "promised money" bar, ledger by month, plan, accounts, four-step statement import; `apps/handy_spend/lib/today/`, `entry/`, `ledger/`, `plan/`, `accounts/`, `import/`, `settings/`, `shell/`; hue `#2E7D32`; the dong is written `đ` because the bundled faces lack `₫`) and **Habit** (Today's habits as bead strings, today's bead is the one-tap check-in; routines with a step-by-step runner; `apps/handy_habit/lib/today/`, `habits/`, `routines/`, `insights/`, `settings/`, `shell/`, `runner.dart` + `runner_view.dart`; hue `#B42318`, so a missed day is never drawn red). Shared bench pieces live in the kit: `HandyTopBar`, `showHandyCatalog` (Ctrl K), `HandyChainBar`. Every app now runs on the kit. Direction (2026-11-02): **each app looks like its own product**. The kit shares behaviour, spacing and accessibility; each app passes its own `HandyBrand.<app>` to `HandyApp` (faces, corners, grounds, pastel/edgeless panels, mark tile, dark-first). Styles: Tools achromatic ledger (IBM Plex Sans), Dev data terminal opening dark (Space Grotesk), Docs framed sheet (Literata titles), Media true black opening dark (Bricolage), Keep framed sheet on cardboard (Be Vietnam Pro), Recall accent ladder (Lexend), Bookmark newspaper ledger (Newsreader titles), Spend pastel tiles (Geist), Habit editorial greeting (Nunito), Trip timetable daybook (Archivo), Boards editorial workspace (Plus Jakarta Sans, magenta `#A61C8E`; indigo is banned). The brand also sets layout: `heading` (`HandyHeading` plain/rule/caps/mono/large, read by `HandyLabel`), `rows` (`HandyRows.open` draws `HandyGroup` between hairlines, Bookmark), `frame` (Docs and Keep: the page is a sheet inset 8px in a tinted frame, drawn by `HandyApp`) and `lineSelect` (Dev: selections are a 1px line of the hue). Geist/Bricolage/GeistMono ship in `handy_ui`; any other face lives in the app's `fonts/` with its OFL text as an asset (static weights cut from Google Fonts, full Vietnamese checked). Families go through `handyFontFamily`, never `package:` (a theme's package sticks through `copyWith`). Each app keeps its one hue from `docs/UX_REDESIGN.md`; `formatFigure` for displayed numbers.
  - **Legacy widgets**: `handy_ui.dart` (`HandyScaffold`, `handyTheme`) and `local_app.dart` (`LocalApp`) must stay: `handy_pdf`, `handy_scan` and several integration tests still use them (Spend no longer does). `workflows.dart` (`SharedWorkflowPage`) stays for Docs text workflows. The other legacy widgets (catalog page, preferences backup, tool memory, settings cleanup, image frame) were deleted; use the kit (`showHandyCatalog`, `HandySettingsPage`, `HandyPictureFrame`).
  - Shared settings pieces: `HandyAutoBackup` + `HandyAutoBackupSection` (`kit/backup.dart`; each app builds its own backup bytes, settings live in device preferences, never inside the data) and `openSealedBackup` for restoring `.hseal` files; `HandyMoreApps` sits in every settings page and hides itself until a sibling has a store page. Apps hand things to each other only by links that pre-fill (`handy-keep://new?…` from Spend, `handy-recall://new?…` from Bookmark), never by sharing data.
  - Motion lives in `kit/motion.dart` (`HandyMotion`, `HandySwap`, `HandyReveal`): feedback and continuity only, zero when the OS asks for reduced motion. Dates come from `pickHandyDate`, never typed.
  - Data colours: `HandyPalette` / `HandyDot` (`kit/palette.dart`) give the user's own things (collections, places, decks, folders, guides, HTTP methods) one of 8 identity hues, minus those within 25° of the app's hue. Show them as a dot or a pale tint beside the name, never as coloured icons per category, and keep each thing's index stable across filters and screens.
  - `python tooling/review-shots.py [app…]` collects every rebuilt app's shots and transition GIFs into `review-shots/index.html` (git-ignored).
  - `python tooling/device-tour.py --device <serial> [app…]` runs each app's `integration_test/tour_test.dart` on an Android device or BlueStacks (e.g. `127.0.0.1:5560`), films it with `adb screenrecord` and writes `device-tours/index.html` (git-ignored). These are emulator runs, not physical-device evidence.
  - In a rebuilt app, keep logic out of the views (for example `qr_history.dart`'s controller), keep the old data-safety assertions in its widget tests, and render review shots with `SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart` from the app folder.

Each app is a thin composition (`lib/main.dart` → `app.dart` → screens) wiring engines + `handy_ui`. Each app has its own identity, data, store config and PWA cache; apps don't share business state. State management is plain `StatefulWidget` + local controllers — don't introduce a routing/state framework for one app (explicit decision in `docs/HANDY_BOOKMARK_ARCHITECTURE.md`).

**Handy Bookmark specifics** (`docs/HANDY_BOOKMARK_*.md`): native persistence is `sqlite3` 3.5.2 in a worker isolate (pinned — 3.8 needs hooks/meta versions incompatible with the pinned Flutter SDK; don't override Flutter's `meta` pin). Web uses a per-record IndexedDB adapter with the same model. On-device storage names (`handy-save.sqlite`, the `handy-save-*` IndexedDB databases, preference keys, Windows `ProductName`) and the backup format ids (`handy-save`, `handy-save-zip`) keep the old name on purpose: renaming them would strand existing data or old backups. Shared URLs are saved transactionally before acknowledging the native share queue; metadata fetch is optional and pins sockets to validated public IPs (unavailable on web).

**Vendored deps.** `third_party/re2` and `third_party/json_schema` are wired via `dependency_overrides` in the root `pubspec.yaml`. Dev's regex uses RE2 (with a web bridge tested in Node VM). JSON Schema never fetches external `$ref`s — the 27 skipped remote-schema tests are intentional.

## Doc/registry coupling

`python tooling/verify-fixtures.py` fails unless:

- `docs/tool-registry.json` lists exactly 22 Handy Tools and 35 Handy Dev tools, **in the same order** as `_tool('id'…)` calls in `packages/handy_tools_engine/lib/src/tools.dart` and `DevTool('id'…)` calls in the Dev engine source named in the registry;
- every tool id appears in backticks in `docs/FUNCTIONS.md`;
- every file in `test-fixtures/manifest.json` matches its sha256.

Adding/removing/reordering a tool therefore requires updating the registry, the expected count in `verify-fixtures.py`, and `FUNCTIONS.md`. Feature status lives in `FEATURE_MATRIX.md`, limits in `KNOWN_ISSUES.md` — keep them in sync with behavior changes.

## Data rules (from docs/DEVELOPMENT.md)

- Validate an entire import before committing anything; ZIPs are checked for path traversal, checksums and size limits. Exports are copies; never overwrite the user's source file, and keep originals on error/cancel.
- Schema changes need a version bump and a roundtrip test.
- Never dereference external URIs without an explicit user action. Secrets/tokens are session-only: never logged, autosaved, or included in default exports.
- Media editor drafts: separate repository, 500 ms debounce, serialized writes; save to library first, then clear draft (a cleanup failure must not be reported as a save failure). Pan mode never mutates layers. Sharing uses a reviewed flattened PNG, never the editable ZIP.
- Size limits (scanner 4 Mpx/page, Markdown render 100 KB, WebP 4 Mpx, MP4 5 min/30 MB, etc.) are documented in `docs/FUNCTIONS.md`; keep code and docs consistent.

## QA evidence

`python tooling/verify-flutter-checkpoint.py` validates logs/artifacts under `docs/qa/evidence` (source/artifact hashes, driver-reconnect results). It needs real build outputs — never fabricate evidence or edit failing logs into passes. Coded, unit-tested, and device-tested are distinct statuses; don't claim device/iOS/store verification that hasn't happened. Never commit store secrets or signing keys (`config/monetization.example.json` is the template; see `docs/STORE_SETUP.md`).

Lints of note (`analysis_options.yaml`): `avoid_print`, `cancel_subscriptions`, `close_sinks`, `use_build_context_synchronously`.
