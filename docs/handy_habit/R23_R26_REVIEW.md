# Run 15 / 15b — convenience, folder transport, scale

R23 and R24 are source implemented and host tested. R25 is an explicit platform
gate. R26 remains partial because large histories exceed retained safety limits
and still need incremental/isolate work; see [PERFORMANCE](PERFORMANCE.md).
No shared packages changed. No git writes, devices, sibling source or secret
files were used. Existing unrelated working-tree changes were preserved.

## Delivered behavior

- Schema9 stores ≤100 named Habits/Progress views and ≤50 local rules in settings;
  readers accept schemas1–9, including schema8 ZIPs. Physical schema2 and sync
  protocol1 remain. Views save search/archive/order or fixed period/date/habit.
  Applying a view changes presentation only. New conveniences require Pro;
  non-Pro sees badges and can still read history or turn a rule off.
- Explicit habit selection → operation/options → exact per-habit preview → Apply.
  Archive, collection, holiday pause and existing reminder-time edits are atomic;
  revision changes refuse stale previews. One durable Undo reverses the batch.
  Reminder edits never enable a disabled reminder or request OS permissions.
- Foreground rules: routine finish → positive count +1, or holiday → pause one
  collection. No chains, background scheduling or retrospective routine replay.
  Stable effect IDs derive from rule+trigger; routine effect timestamp retains the
  source session start. Named history records the actual effect day/date span.
  Each simultaneously triggered rule has a separate Undo batch, all saved with
  the source in one transaction. Undo keeps the marker to prevent replay.
  Automatic save failures on open/resume show a local-data-safe error.
- Free Windows “Sync through a folder” is off by default and separate from Backup.
  The existing R15 driver/causal engine uses immutable generations over a chosen
  folder. App-owned `.part` staging, flush/rename and process locking protect local
  publication. Incomplete/corrupt/newer files and conflict copies stop the merge.
  The vendor client transports files; Habit merges them. Local success cannot
  assert delivery to another PC. No generation cleanup or compaction.
- No health integration, iCloud, iOS native widgets or dynamic shortcuts were
  added. Existing packages do not supply health adapters. Source/platform gates
  and runtime limits are in [PLATFORM_CAPABILITIES](PLATFORM_CAPABILITIES.md).

## Visual review

Contracts precede retained UI code in the Habit section of `UX_REDESIGN.md`.
Existing Nunito/oxblood/vermilion editorial style and the bead signature remain.
Questions: “Which view do I want again?”, “Exactly what will change?”, and
“What will Habit do for me?”. One primary action per step; real fixture data.

Host renders: EN/VI × light/dark ×320/390/1440 ×text1/1.5 =24 combinations,
nine scenes each,216 PNGs. Synthetic Pro/store responses are render fixtures.
Review folder: `apps/handy_habit/build/run15`, `index.html`, `sheets/`.

Critique against app-screen §2.7:
1. Saved view controls sit with their current filters; the batch preview leads
   with selected count and concrete changes; rule names and effects lead history.
2. Forms share edges and wrap controls; a wide modal stays bounded. Short lists
   leave normal page ground, without stretched decorative cards. Contact sheets
   now size landscape captures correctly instead of leaving tall blank bands.
3. Color stays on habit identity/progress, selected controls and the primary
   action. Nunito and warm light/dark grounds remain recognizably Habit.
4. Preview count comes from selected IDs; two selected habits produce two named
   rows and one Undo. History uses the same stored rule name/effect payload.
5. No selection disables Preview; unchanged previews cannot apply. Removed
   reminders are explicitly absent; disabled reminders remain disabled.
6. No new chart legends. Existing Progress remains data-driven and unknown
   days retain neutral/missing treatment.
7. At320/VI/text1.5, the batch title originally truncated. Changed it to “Sửa
   nhiều”, re-rendered all216 images, and inspected the corrected capture.
   Choice chips/actions wrap; history and rule explanations remain readable.

Four representative final shots: `final/390-en-light-100-saved-habits.png`,
`final/320-vi-dark-150-batch-select.png`,
`final/390-en-light-100-batch-preview.png`,
`final/320-vi-dark-150-rules-history.png`.
Four contact sheets: `01-saved-views.png`, `02-batch.png`, `03-rules.png`,
`04-wide.png`. No browser, emulator or physical-device claim.

## Checks and remaining gates

Engine201/app287 tests pass. Android build outcome is recorded in
the short run report and QA_PLAN. Both analyzers are clean. Host render24,
performance4 and durable1 tools pass separately. Full suites include actual
host SQLite/folder tests; web adapter changes remain source/analyzer checked.

Android debug build with Drive define currently fails at `validateSigningDebug`:
filesystem access denied for `debug.keystore.lock`. Retrying with writable Gradle
and Android home locations reached the same signing lock failure. No release key
was read or signing configuration changed. No successful current APK is claimed.

Supervisor: two physical Windows PCs plus a real cloud-folder client; process
interruption/file availability/Windows folder picker; real permissions, reminders,
store transactions; iOS/macOS toolchain; browser transactions/quota/eviction/tabs;
release reference-device timings and assistive-technology checks. Capacity and
remaining main-isolate work are unfinished code, distinct from these runtime gates.

## File map

App: `lib/convenience/{saved_filters,batch_page,rules_page}.dart`, app/controller/
scope, data `{store,store_native,store_web,delta}`, Habits/Progress, Pro demos/gates,
Settings, sync folder provider/page/driver metadata and Drive capacity errors.
Tests: run15 fixtures/UI/reliability/folder and two existing schema assertions.
Tools: scale widgets/durable/process children/screens/contact sheets.
Engine: convenience, models/schema, grouped calendar validation, causal typed
copies/hash validation, sync capacity and schema8 portable compatibility;
convenience/scale tests and existing schema assertions. Docs: Habit files and
Habit sections of plan, FUNCTIONS, UX_REDESIGN, UI_REVIEW, FEATURE_MATRIX and
KNOWN_ISSUES. Export test fixtures are restored from HEAD after verification.
