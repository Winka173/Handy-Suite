# Handy Habit feature matrix

Updated 2026-11-10 (R14 run 8; earlier evidence below is historical).
Source and tests exist; release certification is separate.
No row below claims physical-device or real-store verification.

| R14 feature | Status | Host evidence | Remaining |
| --- | --- | --- | --- |
| Optional two-tap mood, energy/note/tags, edit/delete/Undo/Restore | IMPLEMENTED / UNIT + WIDGET TESTED | App156 / engine129; validation/revision/causal Undo, optional fields, skip/failure/retry, unaffected habits, SQLite reopen | Native upgrade/restart/IME/back/SR |
| Range-based Progress mood history, Today preference, bilingual Mood help | IMPLEMENTED / WIDGET TESTED | Show all/range/restore, preference hiding keeps data, reminder/widget payload independence;25 render cases /145 PNGs | Native lock-screen delivery and real browser runtime |
| Schema6/physical2, all old JSON/ZIP formats and mood CSV table | IMPLEMENTED / HOST TESTED | v1–v5 migration, roundtrip/live/deleted/optional data, CSV validation, duplicate/conflicting-date refusal | Real provider backup/restore and IndexedDB upgrade |
| Month calendar unknown mark uses drawing instead of missing Nunito glyph | IMPLEMENTED / WIDGET TESTED | EN/VI rendered text checked against all bundled cmaps; corrected day2 screenshot | Device font/render follow-up |

See [R14 review](R14_REVIEW.md). Deletion is recoverable, without habit Trash's expiry; no individual permanent-mood-delete control. Correlation and sync transport remain later work.

| R12/R13 feature | Status | Host evidence | Remaining |
| --- | --- | --- | --- |
| 44 habit / 11 routine templates,13 collections, bilingual accent-folded search and featured picks | IMPLEMENTED / UNIT + WIDGET TESTED | Stable catalog IDs, original32 retained, defaults/content/EN-VI, independent routine/step IDs; search/category/no-match and goal-chip routes | Native keyboard/SR follow-along |
| Preview → customisation → save once, blank creation and cancel | IMPLEMENTED / WIDGET TESTED | Habit/reduce/routine drafts; rapid save, zero writes on preview/cancel; existing save-error retention tests preserved | Native back and durable create on device |
| Week/month/year Progress, calendar and overall/per-habit year heatmap, streak/consistency/routine completion | IMPLEMENTED / HOST TESTED | App145 / engine119 pass; leap/DST/quota/pause/unknown/conflict/ranges/Show all/zero/backfill/exports; full24-case render matrix | Device/SR/browser runtime |
| Closed weekly inference and honest daily denominators | IMPLEMENTED / UNIT + WIDGET TESTED | Blank closed week uses recorded incidents, daily blank stays hollow/excluded; actual-today past range boundary, mixed day/week goal units | Real rollover/travel |

See [R12/R13 review](R12_R13_REVIEW.md). Schema5/physical2 unchanged; no new platform certification.

| R10/R11 feature | Status | Host evidence | Remaining |
| --- | --- | --- | --- |
| Count incidents, explicit none/unknown, daily/weekly ceilings and goal history (schema5/physical2) | IMPLEMENTED / UNIT TESTED | Engine103 pass; 21 negative tests cover counts/zero/open-close/day-week/pause/skip/retract/backfill/conflict/history/JSON-ZIP-CSV/v1–v4/DST north+south | Real clock/travel/upgrade and IndexedDB runtime |
| Basic intention/ceiling editor; mixed Today +1/Undo/None; neutral beads; history/month/review | IMPLEMENTED / WIDGET TESTED | App138 pass, including 9 R11 widgets + negative SQLite reopen/Undo; duplicate fresh goal and zero-activity counts | Native back/touch, screen reader, device persistence |
| Negative routine guard and bilingual help | IMPLEMENTED / HOST TESTED | Picker + engine reject negative mappings; routine-origin incidents refused; searchable 16th topic and real bead mock | Device follow-along |
| Practice coach placement + R11 visual matrix | HOST RENDERED / REVIEWED | 24 EN/VI × light/dark × 320/390/1440 × text1/1.5; create/Today/history/review/Progress, plus two practice cases; see R10_R11_REVIEW and QA_PLAN | No new device/browser/store certification |

| R8/R9 feature | Status | Current host evidence | Remaining |
| --- | --- | --- | --- |
| Three-stage guide, two story beats, isolated Today practice, one Start | IMPLEMENTED / WIDGET TESTED | All microsteps + Do it for me, Back/Esc/Enter/Skip, replay and practice leave state/backup unchanged, returning-user bypass, no launch permission | Native OS back/first-launch/update/replay and assistive tech |
| Searchable illustrated help, contextual entry, replay | IMPLEMENTED / WIDGET TESTED | 15 EN/VI topics; accent folding, no match/clear, filtered count without numbers; all articles rendered | Device follow-along / screen reader |
| Grouped persisted Settings, reminder privacy/permission/test, preference-only reset | IMPLEMENTED / WIDGET TESTED | Values/errors/defaults/reset/no free Pro badge; friendly zone/current GMT/DST; app128 + engine82 pass | Actual native delivery/haptics/public privacy/support URLs |
| R8/R9 visual finish | HOST RENDERED / REVIEWED | 24 matrix combinations + motion check pass; 949 PNGs incl. continuations; [critique](R8_R9_REVIEW.md) / [commands and logs](QA_PLAN.md) | No new device/browser/build/store certification |

| P0 area                                                                           | Code                                       | Host evidence                                                                                                                                                                                                                                                         | Platform evidence / remaining gap                                                                                                |
| --------------------------------------------------------------------------------- | ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Habit CRUD, types, targets, sorting, grouping, archive/backfill/Undo              | IMPLEMENTED                                | UNIT_TESTED: engine + UI creation/check-in/cancel                                                                                                                                                                                                                     | Native UI integration tracked below                                                                                              |
| Effective recurrence, strict/weekly streaks, DST, skip/current periods            | IMPLEMENTED                                | UNIT_TESTED: recurrence, immutable versions, weekly/day boundaries, filtered partial week, quantities                                                                                                                                                                 | Physical timezone/clock changes not verified                                                                                     |
| Pauses (all or chosen habits), neutral days, prorated weekly quota, reminders off | IMPLEMENTED 2026-11-02 (schema 2)          | UNIT_TESTED: 24 engine (streak/metric/quota across boundaries, edit/end/delete, reminders, quiet hours, schema 1 migration, JSON/ZIP/merge/CSV/MD); UI: Today rest + End early/Undo, per-habit menu, Settings list, delete-habit cleanup; SQLite schema 1 -> 2 reopen | Device/OS date-change behaviour and assistive tech not verified                                                                  |
| Paused-run notice on leaving the runner (Android/iOS), tap reopens `/run/<id>`    | IMPLEMENTED 2026-11-02                     | UNIT_TESTED with a fake port: text/time left, timer stays paused, cleared on resume/abort, off/denied/quiet hours, launch tap routes                                                                                                                                  | Source only: no emulator/device run; real plugin show/cancel/tap, iOS passive level and Android lock-screen privacy NOT VERIFIED |
| Routine library/detail, eight starters in New, atomic draft add/edit/drag/up-down/link/save/dirty guard | IMPLEMENTED R7 2026-11-10 | HOST UNIT/WIDGET: draft isolation, discard, retry/save-once/stale edit, actual drag; rendered EN/VI light/dark 320/390/1440 text 1/1.5 | Device drag/IME/back/swipe and assistive tech not verified |
| Focused runner, pause/skip/complete/exit confirmation, typing-safe shortcuts, recovery and credited-habit summary | IMPLEMENTED R7 2026-11-10 | HOST UNIT/WIDGET: exactly-once retry, required/canSkip, native restart, background pause, note typing, summary, reduced motion; full render matrix | No terminated timer guarantee; device kill/reopen, keyboard, notification and screen reader checks pending |
| Routine Lite (removed 2026-11-03)                                                 | REMOVED                                    | UNIT_TESTED: feasible/infeasible/untimed/original unchanged                                                                                                                                                                                                           | Reusable variant requires verified Pro                                                                                           |
| Calendar, history, weekly/monthly trends, date/habit/category/routine filters     | IMPLEMENTED                                | UNIT_TESTED: metric denominators and responsive tabs                                                                                                                                                                                                                  | Charts disclose max 52 visible periods; reports keep range                                                                       |
| Local reminders, quiet/DST/weekdays, snooze/preview/cancel                        | IMPLEMENTED                                | UNIT_TESTED: pure schedule/cap/DST                                                                                                                                                                                                                                    | Android deny/grant run recorded separately; iOS source only, Windows/Web in-app due list                                         |
| SQLite, CAS, indexes, migration, integrity/corruption handling                    | IMPLEMENTED                                | INTEGRATION_TESTED on host: real SQLite, stale write, rollback, future/corrupt preservation, 10k events                                                                                                                                                               | Power loss/physical low-memory not verified                                                                                      |
| Web IndexedDB atomic persistence                                                  | IMPLEMENTED                                | Analyzer + Web compilation                                                                                                                                                                                                                                            | Browser eviction/quota/offline runtime NOT VERIFIED                                                                              |
| JSON/ZIP full backup, merge/replace and CSV log import/export                     | IMPLEMENTED                                | UNIT_TESTED: roundtrips, ID/hash remap, duplicate/conflict/path/checksum/truncation/size refusal                                                                                                                                                                      | Real OS document providers need QA                                                                                               |
| EN/VI PDF/Markdown/CSV reports and cancellation                                   | IMPLEMENTED                                | UNIT_TESTED: real export bytes, cancel preserves state; PDF independently decoded                                                                                                                                                                                     | Not a backup format; PDF limited to 10k events                                                                                   |
| EN/VI, dark/light, 3 destinations / folding sidebar, keyboard and named areas | IMPLEMENTED | Host/widget:320/390/768/1024/1440, EN/VI/light/dark/text1.5 screenshots, routes/keyboard/reduced motion/fold persistence | Real browser refresh/back-forward, device keyboard and screen reader remain unverified |
| Ads consent + Pro Lifetime purchase/restore + Lite variants                       | IMPLEMENTED using shared official adapters | Shared adapter tests; no fake purchase switch in production                                                                                                                                                                                                           | BLOCKED: publisher IDs, signing, consent accounts, official sandbox transactions                                                 |
| Android / Windows / Web builds                                                    | IMPLEMENTED                                | See current build records, not old console output                                                                                                                                                                                                                     | Must have exitCode=0 AND unchanged source; emulator != hardware                                                                  |
| iOS / real stores / physical devices                                              | Source/config implemented                  | NOT VERIFIED                                                                                                                                                                                                                                                          | BLOCKED: macOS/Xcode, physical devices and publisher accounts unavailable                                                        |

Evidence: [engine](../qa/evidence/habit-engine-tests.log),
[app](../qa/evidence/habit-app-tests.log), [analysis](../qa/evidence/habit-analyze.log),
[UI renderer](../qa/evidence/habit-ui-shots.log), [QA plan](QA_PLAN.md),
[release checklist](RELEASE_CHECKLIST.md). Platform/build results are summarized in QA_PLAN.
P1 pauses/vacations added 2026-11-02; widgets/challenges/advanced dependencies remain deferred.

## Final local candidate

2026-11-02 pauses and paused-run notice: 62 engine + 33 app host tests and 32 review
renders pass; the fingerprint and audit below predate them and were not re-run.

Current source fingerprint: `8fdddea05ac1124d94285f6649e89ccfe59c4cb761738d6b4d5b9a2d8a55b5c0`.
[Audit](../qa/evidence/habit-qa-audit.json): success=true, releaseReady=false.
1,775 host tests passed / 28 platform-conditional skipped, 29/29 test packages;
Habit contributes 38 engine + 20 app tests. Five additional UI-render tests pass.
Android native core, two-process recovery and notification deny/grant have real driver
responses on this source; failed transport logs remain recorded. APK, unsigned AAB,
Windows EXE/MakeAppx-validated unsigned MSIX and Web compile with unchanged source.
Browser worker is Node-VM tested; browser runtime, iOS, hardware and real stores are
not verified. [35 UI captures / 36-page PDF](../qa/evidence/habit-ui-review.pdf).

Implementation does not mean every editor gesture has independent device evidence.
Creation/check-in/cancel/Lite/recovery and main-area accessibility are automated;
archive semantics, mapping validation, reorder preservation and import safety have
engine coverage. Physical drag/keyboard/assistive-tech/file-provider QA remains in
the release checklist. Source uses real adapters; test file sinks are test-only.


### Run 2 data-safety update (2026-11-10)

| Habit feature | Status | New evidence | Still needs verification |
| --- | --- | --- | --- |
| Restore preview and sealed errors/cancel | IMPLEMENTED | Host widget tests: size/date/original schema/counts, wrong password, tamper, cancel, stale preview; decrypted ZIP signature | Real OS document provider and file-picker lifecycle |
| Durable pre-replace recovery / atomic rollback | IMPLEMENTED | Real SQLite tests: checkpoint failure stops replace, failed commit rolls back, restart recovery, CAS; recovery excluded from backups | Storage pressure/process interruption on devices; browser quota |
| Schema3 causal operations / physical2 migration | IMPLEMENTED FOUNDATION | v1/v2 JSON+ZIP migration/roundtrip, deterministic IDs, operation union/collisions/absolute candidates, native interrupted-migration retry | Full sync reduction/conflict UI/provider in R15/R16; real IndexedDB upgrade |
| Domain Undo across restart | IMPLEMENTED | Persisted inverse batch and exact retractions, refuses changed rows, preserves unrelated rows, existing appearance/check-in regressions | Real process kill/reopen and assistive tech |
| Habit/routine trash (30 days) | IMPLEMENTED | Host engine/widget/native: restore IDs/links, days-left, neutral retained gap, active-run guard, purge/restart/idempotence, backup/merge, permanent cleanup | Device clock/expiry29–30 days, real screen reader |
| Trash / preview responsive presentation | HOST WIDGET TESTED | EN/VI, light/dark,320/1440,150%text; trash reduced motion; real-font host screenshots inspected | Device/browser input/focus and iOS adaptive dialog |

The original schema2 pause row above describes its introduction; run2 writers used3, run3 writers use4 and physical stores remain2. Copy-merge remaps incoming event revisions as independent copies, not sync. No shared-package changes in run2.

### Run 3 R5/R6 update (2026-11-10)

| Habit feature | Status | Host evidence | Still needs verification |
| --- | --- | --- | --- |
| Three-area shell, named routes / legacy routes, sidebar224→rail64 | IMPLEMENTED / WIDGET TESTED | Routes and parent fallback, Ctrl/Cmd N/F/comma/1–3, typing exemption, Back/Esc, persistent fold/reopen | Browser URLs/refresh/back-forward, native keyboard, OS back |
| Today bead + Undo, time-of-day grouping and in-place Show all | IMPLEMENTED / WIDGET TESTED | One-tap commit and durable Undo, stable row position, bead top60% on320/390 at1.5text, inferred/explicit groups, caps | Real rapid taps, rotation, accessibility technology |
| Basic/Advanced editor and dirty-exit safety | IMPLEMENTED / WIDGET TESTED | Cancel/Back/Esc discard/keep, save failure/retry/busy, draft survives navigation; appearance and Advanced regressions pass | iOS swipe/keyboard and physical device lifecycle |
| Complete in-place history and dated targets | IMPLEMENTED / WIDGET TESTED | Records past30 visible, old target survives schedule edit, narrow/large-text day-list mode | Screen reader/calendar input and large real libraries |
| Versioned day-boundary policy, schema4 / physical2 | IMPLEMENTED / UNIT + WIDGET TESTED |0–1439minutes, v1–v3 reads, JSON/ZIP, north/south DST gaps/folds, old dates fixed, shared reminder/trash day, foreground rollover | Real midnight/travel/clock changes and device upgrade |
| Host visual review | RENDERED / INSPECTED | EN/VI, light/dark,320/390/1440, text1.0/1.5, sidebar/dirty/history extras; film asserts durable check-in | No device/browser/store claim; full illustrated help is R9 |
