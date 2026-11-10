# Handy Habit — consistency audit, runs 11–12

## Run12 corrections and R21

Run11's Help index and shell rows below are historical and superseded here.
Real source and screenshots were checked again; the supervisor's remaining gaps were valid.

| Area | Sibling behaviour | Run12 correction | Status |
| --- | --- | --- | --- |
| Help index | Tinted Replay introduction card, Topics, soft-square icon/title/summary/chevron rows | Same structure in Habit palette; search retained below replay; no numbers even when filtered; drawn previews in detail only | Host tested/rendered |
| Today identity | App mark and app name on phone | Actual assets/icon.png, 28px; same mark in wide sidebar; wide content bar names current destination | Host tested/rendered |
| Creation | Boards labelled New board FAB | Contextual New habit / New routine FAB, same shape/anchor/placement; removed duplicate inline routine New; secondary Add menu keeps other paths and pause; 104px list-bottom space | Host tested/rendered |
| Routines/Progress/Settings/pushed top bars | Destination/title/back mechanics | Reviewed: main pages have no detail Back; wide sidebar supplies identity; Settings and pushed pages keep title/back and content heading; no unrelated chrome added | Existing + new navigation tests retained |
| Pro | Live feature stage, free comparison, price/Buy/Restore, title-right badges | Nine shipped Advanced routine demos; every badge selects its demo; Learn about Pro preserves draft; Pro group before Help | Host tested/rendered |
| Store | Shared native lifetime adapter, no local ownership switch | NativeLifetimeStore via HandyApp's MonetizationHost/LifetimeController; Android config habit/productId + androidPublicKey; native read now fetches localized price, normal handy_store dependency | Android debug compiled; real Play checks pending |

Evidence: `apps/handy_habit/build/run12/` has round1/final 24-case Habit rasters,
fresh sibling captures from each app's own directory (correct asset bundles), six
priority sheets and per-matrix sheets. All prices/ownership in host shots are synthetic
test responses, never proof of billing. [Detailed critique and limits](R21_REVIEW.md).
R19 and R20 remain open. Run11 shared K1–K4 follow-ups below remain unchanged.

## Historical run11 audit

Completed on 2026-11-10 against the real Bookmark and Boards source and host renders.
Result: **22 Habit gaps fixed**, plus **4 shared-kit follow-ups**. No sibling, engine,
shared-package or schema changes. Pro purchase/demos remain explicitly assigned to the next run.

The screen contracts were written before implementation in `docs/UX_REDESIGN.md:3521`.
Habit keeps Nunito, the editorial greeting, vermilion/oxblood/ochre, and bead strings.
A missed day remains hollow, never a red warning.

| Area / gap | Bookmark / Boards behaviour | Habit baseline | Gap | Fix / evidence | Done |
| --- | --- | --- | --- | --- | --- |
| Shell S1 | Utility actions end with Settings | Gear before Add | Action order | Add before gear; phone shell before/after 01 | Done |
| Shell S2 | Main content has 16 phone / 24 wide gutters | Main lists always 16 | Wide spacing | Today, Habits, Routines, Progress, Help, Sync and Trash responsive gutters | Done; shared HandyPage exception below |
| Pushed pages P1 | Back on pushed pages | Standalone Sync omitted leading | Missing escape | Explicit Sync Back; route matrix including routines, editors and missing route | Done |
| Navigation | Job-based phone controls; wide fold and reopen at top, remembered | Today/Routines/Progress; 224 sidebar / 64 rail | No new gap | Existing sidebar persistence tests; phone jobs retained; primary destinations intentionally have no detail Back | Done, retained |
| Lists L1 | Visible More and pointer menus | Open detail to access actions | Hidden actions | 48px More; same actions on row long-press/right-click; labelled keyboard alternative | Done |
| Lists L2 | Deleting from a list leaves the list open | Detail deletion unconditionally popped any current route | Wrong navigation from new row menus | Capture originating route; only pop that detail after commit; list/detail tests for both entities | Done |
| Lists / headings | Caps expand in place, See all beside heading | Existing Capped/HandyReveal and section actions | No new gap | Today/history/library/progress/routine cap tests still pass; selection/scroll stay on same route | Done, retained |
| Feedback F1 | Timed Undo and shared motion | Initial timed Undo, result/default animations | Reduced-motion mismatch | persist:false and HandyMotion for Undo, result/error and link fallback; test expiry and zero motion | Done |
| Feedback F2 | Current result describes current action | Rapid announcements could queue stale results | Stale Undo messages | clearSnackBars before newest announcement; rapid-message test | Done |
| Settings T1 | Values under label, Pro badge title-right only when locked | Trash count trailed row | Inconsistent value placement | Localized item count below Trash label | Done |
| Settings T2 | Data controls before Help/About; MoreApps at end | Reset/delete group below About/MoreApps | Group order | Appearance/defaults/reminders/pauses → Data → Reset → Help → About → HandyMoreApps | Done |
| Settings / free features | Backup, restore, sync, export free; native auto-backup section | Same kit components and free ownership | No new gap | HandyAutoBackupSection, openSealedBackup, MoreApps retained; existing free/Pro tests | Done, retained |
| Help H1 | Drawn screen fragments accompany learning | Text-only index | Missing pictures | Each numbered topic has a scaled real-control drawing, excluded from duplicate semantics | Done |
| Help H2 | Relevant pictures beside instructions | Text block imitation after all instructions | Missing teaching detail | Per-step drawings: beads, entry controls, face scale, runner/progress, dates, settings and backup controls; relevant control ringed | Done |
| Help H3 | Previous/Next and Back one level | Back exited help, no adjacent topics | Navigation discontinuity | Local Back/Esc index before exit; Previous/Next; unique outgoing article anchors during HandySwap | Done |
| Help H4 | Stable topics, search, contextual entry and replay | Search dropped topic numbering | Number stability | Numbers preserved in results; accent-insensitive EN/VI search, no match/Clear, contextual routes and replay tested | Done |
| Guide | Two-beat story, pretend practice, final teaching + Start; Back/Skip/Enter | Run 5 implementation matches | No new gap | Re-rendered all stages and practice targets; replay from Settings/Help; no writes/permission prompt in guide | Done, retained |
| Backup / restore / recovery / export | Preview, confirm replacement, recovery, no mutation on cancel/error | Run 2/8 preview and safety flows | No new gap | App portability/export tests, engine roundtrip/validation tests; CSV/ZIP/JSON/PDF flows retained | Done, retained |
| Trash | 30-day retention, remaining days, confirmed permanent delete | Retention already matches | Wording covered by W1 | Restore retains records/links, irreversible deletion has no Undo; tested | Done |
| Sync | Optional free Drive appdata; account/privacy/status; local data retained on disable | Run 9/10 provider and conflict review | Back covered by P1 | Off/connecting/ready/error/conflict/privacy rendered; provider and merge tests remain green | Done |
| Mood M1 | Pickers communicate by shape, label and state | Plain text feeling chips | Missing visual scale | Five drawn faces with distinct expressions, labels, selected semantics and tick; aligned faces; two taps from Today; Enter saves | Done |
| Mood M2 | Destructive edits confirm, cancel keeps data | Immediate mood deletion | Missing confirmation | Confirm before commit; optional fields survive deletion/Undo/history restore | Done |
| Motion O1 | Shared appear/change transitions; reduced motion = zero | Local dialogs/sheets used Flutter defaults | Modal motion ignored preference | HandyMotion animation styles on all Habit-owned showDialog/bottom-sheet/menu entry points, including pretend practice; help HandySwap; existing Reveal/Appear retained | Done; shared helpers below |
| Accessibility A1 | Full touch targets and readable calendars | Narrow progress month cells <48 and text overflow | Cell size and wrapping | Minimum 48px days; horizontal week scrolling only when needed; 1.5/2x route checks | Done |
| Accessibility A2 | Accessible date selection | Year heatmap had 14px hit areas | Tiny targets | Year cells and blank placeholders 48px, month heading height scales; horizontal scroll retained; day opens details | Done |
| Accessibility A3 | Section actions wrap under large text | Routine Edit steps overflowed fixed heading row | 320px / 2x overflow | Stack heading/action at constrained width, retain full label | Done |
| Accessibility A4 | Primary task remains visible at small widths | Added More squeezed text, pushed first bead below existing 60% test | Density regression | Stack bead/More in narrow or enlarged-text phone rows; original position assertion unchanged | Done |
| Accessibility / keyboard | Labels, logical focus, Enter/Space, Esc/Back, contrast | Existing defaults and forms; new gesture node was unlabelled | Transient regression fixed within L1 | Exclude duplicate pointer semantics; actual More remains focusable; light/dark guidelines and palette contrast tests pass | Done |
| Wording W1 | Short labels, singular/plural, EN/VI parity | 1 days/steps/records/items in several paths | Count grammar | Trash, topics, routines/blocks/drafts, runner, schedules, streaks, backfill, mood history and import summaries | Done |
| Wording W2 | Plain language in Settings | Local-first in explanatory copy | Jargon | Saved on this device. No account needed. EN/VI explanatory parity retained | Done |
| Empty/loading/error | Explain state, next action, keep data/draft on failure | Existing empty, retry, dirty-draft and conflict surfaces | No new gap | Existing failure/recovery tests; rendered empty Today, empty Progress, no-match Help and Sync status variants | Done, retained |
| Pro | One-time lifetime, live demos, badge title-right only for non-Pro | Advanced routines gated and demo affordances present; final paywall deferred | Purchase/demo screen belongs to next run | Existing entitlement tests pass; do not infer billing/store verification | Not this run, explicit brief deferral |
| Shared K1 | Desired wide gutter 24 | HandyPage hardcodes 16, also in siblings | Shared page primitive | Habit-owned pages fixed locally; migrate shared HandyPage padding centrally | Not Habit's; no shared edits allowed |
| Shared K2 | Desired headings resize under enlarged text | HandyLabel trailing fixes height 48, no wrapping | Shared heading primitive | Habit routine caller adapts locally; central responsive trailing contract needed | Not Habit's; local overflow fixed |
| Shared K3 | Desired menu targets ≥48 | HandyMenuButton items use 44 and ellipsis text | Shared menu primitive | Habit entity menus use local 48px entries and icon More; shared migration belongs to supervisor | Not Habit's; Habit menus fixed |
| Shared K4 | Desired zero motion everywhere | confirmHandy/showHandyMessage/openSealedBackup use shared Flutter defaults | Shared modal/message contract | Habit-owned entry points and scope fixed; shared helper animation-style API remains supervisor work | Not Habit's; no shared edits allowed |

## Coverage and evidence

Source references: Bookmark `shell/save_shell.dart`, `scope.dart`, `ui/capped.dart`,
`settings/{save_settings,how_to_page,how_to_mocks}.dart`, `library/trash_page.dart`,
`welcome/`, `pro/`, `sync/`; Boards `home/`, `scope.dart`, `settings/`, `welcome/`,
`pro/`, `sync/`. The references describe mechanics; a board/card is not a habit/routine.

Habit inventory reviewed: Today and all habits; habit creation/edit/appearance/history,
amount/check-in and pause forms; templates/gallery/preview; routine creation/basic/advanced,
step/block/template/condition/branch controls, detail, runner and saved sessions; Progress
week/month/year/filter/day details and review; mood log/details/history/deleted/conflict;
all Settings groups, About/legal/support/licenses, How to use index/search/19 topics,
guide story/practice/final; Trash; restore/recovery/export; Sync off/pending/connecting/
ready/error/conflict/account/privacy. Main destinations are shell pages, not detail pages.

Evidence root: `apps/handy_habit/build/run11/` (git-ignored, real host raster output).
The retained baseline is `before/`; same render tools write `after/`. `references/` adds
96 sibling PNGs from both locales × both themes × both requested widths; the earlier
55 Boards + 207 Bookmark shots remain under `siblings/`, including guide and Pro flows.
`tool/run11_reference_screens_test.dart` imports the siblings' own renderer/fixtures
without modifying their source. `inventory.json` lists exact matched/missing/new filenames.
`index.html` links originals, every matched before/after pair and contact sheets.

Six priority before/after sheets (each also includes both structural references):
`01-shell.png`, `02-help-index.png`, `03-help-detail.png`, `04-mood.png`, `05-sync.png`,
`06-settings.png` in `sheets/`. `matrix-*` sheets compare normal-text screens at 390/1440,
EN/VI, light/dark; `coverage-*` includes enlarged text and less common states. Additional
320px ×2 real-font renders are prefixed `r11-320-`. Marketing/store verification is not claimed.

Validation: app **205 tests**, engine **175 tests**; 18 new run11 tests. Existing behavioural
assertions retained; old menu finders and mood-delete tests updated for the actual controls
and confirmation. Search test now asserts stable numbering. The old screenshot journey
now searches a real template title and follows preview → customise, fixing its pre-existing
failure. Format and analyze are clean in both packages. Rendering logs retain early failures;
`regression-shots.log`, `final-shots.log` and `mood-final-shots.log` record corrected reruns.

Visual critique: the main figure answers today's kept/due question and still leads to a
single-tap bead; no added dashboard chrome. Main-list edges now follow the responsive grid.
Moods communicate by expressions plus text, without red/green status. Help diagrams now
show the actual controls beside each instruction. Large-text overflow is fixed through
reflow/scrolling. Trade-off: the accessible year view shows fewer weeks at once, with the
rest in its horizontal scroller; no days/data were removed. The original 320px first-bead
position check remains enforced. Shared-helper motion/spacing limits above remain explicit.

Exports are restored byte-for-byte to the saved run11-start originals after tests; those
originals already differ from HEAD and are not regenerated as purported release evidence.
No emulator, device, live account, browser, billing or store validation was performed.
