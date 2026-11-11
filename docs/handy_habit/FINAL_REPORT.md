# Handy Habit final report — R27, 2026-11-11

## A. Completion summary

R27 source/documentation slice completed: natural batch preview sentences EN/VI;
phone guide practice heading raised to30 logical px; story/final already30/44
without a density clamp. Six new regressions; real-app bilingual store renderer
and release documents/root Habit summaries. Data schema9/physical2/protocol1,
no schema/shared-package/version/signing change. This is a host-verified source
candidate, not full MASTER PROMPT/platform/store certification.

## B. Feature matrix

[Current feature × status × evidence](FEATURE_MATRIX.md) replaces run-by-run
claims. Free core habits/reduction/history/pauses/Trash/routines/Progress/mood,
templates/settings/guide/help/backup/export/supported sync are implemented and
host tested. Pro Advanced/insights/Studio/convenience are implemented with live
gates. Platform adapters/delivery and R26 capacity retain explicit limits.

## C. Competitor inspiration

| Inspiration from original plan | Shipped Habit equivalent | Remaining distinction |
| --- | --- | --- |
| Streaks: effortless check-in, distinct habits | Today's bead, icons/colors, goals and reduction incidents | No health-driven completion; Android widgets open app |
| Loop: meaningful history | Core streaks/consistency/week/month/year/heatmaps | Large-history capacity not fully solved |
| HabitNow: practical routines | Basic builder, linked habits, foreground runner/recovery | No killed-app timing promise |
| Habitify: flexible local insights | Effective goals/pauses, Pro comparisons/mood co-occurrence/suggestions | Deterministic local rules, no cloud AI/medical claims |
| TickTick: discoverable starts |44 habit/11 routine templates/13 collections; preview/customize | No project/calendar manager |

These are design inspirations from the existing audit/plan, not a new competitor
market review. Full historical decisions: `docs/HANDY_HABIT_PLAN.md`.

## D. Free versus Pro

[Exact entitlements](FREE_PRO.md). Unlimited basic habits, negative habits, core
history/heatmaps, basic routines and saved Advanced-plan execution, optional mood,
ordinary exports/encryption/backup/restore/supported sync are Free. Pro Lifetime
authors Advanced plans and adds explainable insights/designed PDF, Studio apply,
saved views/batch/local rules and ads removal. Android checkout only, localized
native price; fake-store tests do not prove actual billing.

## E. Settings, onboarding and help

[Inventory](SETTINGS_INVENTORY.md), [guide](ONBOARDING.md),
[19-topic coverage](HOW_TO_COVERAGE.md). Three-stage two-beat story, disposable
practice, final Start; Back/Skip/replay/contextual notification permission.
Nunito/vermilion/bead identity retained. Guide30/44 logical px, natural batch
action sentences; keyboard/reduced motion/large-text behavior retained. Windows
folder help and convenience help remain inline, not separate help-center topics.

## F. Backup and sync by platform

[Backup](BACKUP_ARCHITECTURE.md), [sync](SYNC_ARCHITECTURE.md),
[migration1–9](MIGRATION_NOTES.md), [platform matrix](PLATFORM_CAPABILITIES.md).
Manual JSON/ZIP/sealed/validated copy-merge/replace/recovery Free; native automatic
folders on lifecycle opportunities, Web manual only. Android Drive appdata
build-gated; Windows folder causal merge depends on vendor transport for remote
delivery. No iCloud/Web cloud adapter or Android↔iOS automatic sync. Data remains
local when sync is off; no terminated scheduler/end-to-end encryption claim.

## G. QA

[Commands/counts](TEST_RESULTS.md): app293, engine201, both analyze/format clean,
fixture verifier passed21 fixtures/39 tools. Store renderer2 tests/12 PNGs,
1080×2160 at3x, `apps/handy_habit/build/store/`. Visual24 matrix cases/96 renders,
`build/run16-shots/`; guide/batch review and screenshot critique recorded there.
Host only. Initial Habit export bytes restored; RELEASE.md Google Play untouched.
No devices/Gradle/other app source/secrets/git writes; no daemon started.

## H. Limitations: code versus external

[Known issues](KNOWN_ISSUES.md). Code: R26 segmentation/compaction and large-state
main-isolate work;30MB/200k guards; Android-only native widgets/checkout; foreground timers/
sync; no health/OS-shortcut/non-Android-widget adapters. External: privacy URL
pending owner, Play forms/licence key/testers, real OAuth/billing, providers,
device/SR/browser/Windows cloud/iOS hardware verification. Keep these distinct.

## I. Release readiness by platform

| Platform | Current evidence | Release verdict |
| --- | --- | --- |
| Android | Host source tested, prior draft Play setup; supervisor reports prior binary startup/guide on two BlueStacks Android11 instances | Final binary/physical-phone/full two-device/Play verification and policy/forms pending |
| iOS | Shared UI/data/native adapter source and host tests | macOS/Xcode/signing/build/native QA required; no checkout/iCloud/native widgets |
| Windows | Host SQLite/folder/process tests and UI source | Installed package/toast/two-PC cloud client/accessibility acceptance pending; no checkout |
| Web | Source/host widgets and IDB implementation | Actual browser/offline/update/quota/eviction/multiple-tab acceptance pending; manual backup only, no checkout/cloud sync |

## J. Remaining tasks by severity

1. Release blockers: owner publishes privacy policy; completes actual Data safety,
   rating/audience/Health/ads forms, OAuth clients/consent/licence key/testers;
   supervisor builds final binary and verifies actual billing/provider/device flows.
2. High: R26 capacity/compaction/segmentation and reference-device performance;
   installed upgrade/recovery and concurrent two-device/two-PC sync validation.
3. Medium: complete browser, iOS/Windows delivery and assistive-technology checks.
   (The schema-8 mood/pause CSV import gap was fixed on 2026-11-11 with a
   regression test for schemas 6-9 and refusal of 10.)
4. Low/deferred: broader help topic coverage, individual mood purge, optional
   health/native widgets/shortcuts where genuine platform adapters can be verified.

First supervisor checks: phone guide all stages at density~2.6/default+large text,
fresh/update/replay, then batch selection/preview/one Undo; detailed ordered
checks and store worksheet: [RELEASE_CHECKLIST](RELEASE_CHECKLIST.md).
