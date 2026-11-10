# R17/R18 host review · 2026- 11-10

Source implemented; host unit/widget/SQLite tested. No devices, browser runtime, store or real Google OAuth verification in this run.

Design contract: Habit's R17/R18 paragraph in `docs/UX_REDESIGN.md`, written before UI code. Applied `design-taste-frontend` app-screen run and `frontend-ui-engineering`; references were Boards' real Pro gates/settings badges and existing Habit draft/runner mechanics. Existing Nunito/Habit palette retained; beads remain the app's single signature. No new style lottery or photo assets.

App-screens §2.7 critique:

1. Question/hierarchy: Basic shows name, step count and duration; Advanced reveals named rule/library controls with one-line explanations. Branch selection now owns the runner's largest content: clocks, Undo and step actions stay hidden until a choice. Summary leads with actual completed/skipped counts.
2. Edges/density: bounded form/runner measure on desktop, full single scroll on 320/390; labels and buttons wrap at 150%. Long forms scroll behind a pinned Save. Sparse branch screens deliberately contain only the decision and skip explanation; no filler panels. App-bar titles may ellipsize, while form names and step names remain readable in content.
3. Colour/face: Nunito, vermilion duration data and oxblood/peach primary remain Habit's identity. Flat grounds, neutral navigation, no icon tiles/gradients/new palette. Pro is text to the right of the control title, including wrapped VI titles.
4. Arithmetic: fixture has 3 candidate steps: 10-minute weekday walk + two 5-minute alternatives =20 planned minutes. On Saturday with B chosen: 1 completed, 2 skipped, 0 actual minutes in the synthetic rapid run; no linked credit. Planned total describes all original candidates, including explained skips. Remaining candidate time before choice is 10 minutes. Engine tests independently cover actual elapsed, time thresholds, weekday overrides and exactly-once credit.
5. States: zero actual time prints 0:00; no invented habit credit. Non-Pro demo changes Monday/Saturday locally and writes nothing. Basic/Advanced/demo/branch/skipped/summary and save-failure/dirty/entitlement-loss states have widget coverage. No purchase link or fake product price exists.
6. Encoding/labels: duration-strip segments come from saved seconds; weekday chips match the rule, branch buttons show actual path titles, summary reasons come from saved codes. Day/branch explanations use text as well as track treatment. Third-round badge layout fixes badges wrapping below their titles.
7. Phone/platform: shell is absent in builder/runner; 48px Material actions and wrapping controls remain reachable at 320/text150. Focus/native buttons and existing Back/Esc/dirty guards remain. Reduced motion flows through existing kit/MediaQuery handling. Device screen-reader and native back checks remain with supervisor.

Rounds: first matrix 120 PNGs caught branch clock/Undo noise and condition-heading capture position; fixed both. Second matrix 168 PNGs included non-Pro badges/demo and caught badge wrapping at 320/150; fixed with a fixed trailing badge. Third matrix 168 PNGs passed 24 tests. All six viewport/locale contact sheets inspected; representative originals checked at full resolution. Flutter host raster/widget captures are the evidence; HTML DOM inspector/linter does not validate native Flutter widgets and was not presented as a browser pass.

Final folder: `apps/handy_habit/build/run10-shots/` (gitignored). Each stem is width-locale-theme-100/150. Scenes: `builder-basic`, `builder-advanced-free`, `pro-demo`, `builder-advanced`, `condition`, `branch`, `summary`. Six `contact-<width>-<locale>.jpg` sheets show all 24 combinations.

Checks: engine 175/175; app187/187 (`flutter test --no-pub`), 17 new engine tests and 9 new app/auth tests; format reports0 changes and analysis clean in both packages. App host SQLite restart preserves advanced choices/rules/trace; engine validates all nested sync fields in both merge orders. Root changes stay inside Habit entries. 11 pre-existing Habit export artifacts restored and SHA-256 checked byte-for-byte.

Limits: no new browser/device/APK/store certification. Live Google account identity is owned by Google's authorization sheet, not exposed as an email to Habit. Pro purchase/restore/paywall work remains R21; existing imported advanced routines run without Pro. Reusable sets are nonrecursive snapshots; editing a source affects future insertions only. Conditions use captured session inputs, not background automation.
