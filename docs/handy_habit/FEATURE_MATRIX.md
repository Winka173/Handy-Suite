# Handy Habit feature matrix

Current R27 source, 2026-11-11: data schema 9, physical schema 2, sync protocol 1.
This table supersedes historical run matrices. Host evidence means unit/widget or
local process execution, never OS delivery, real OAuth, billing or production.
[Commands/counts](TEST_RESULTS.md); [platform gates](PLATFORM_CAPABILITIES.md).

| Feature | Status | Evidence / limit |
| --- | --- | --- |
| Unlimited basic habits; binary/count/quantity/duration; icons/colors/groups/order/search | Implemented, host tested | App `ui_test.dart`, `appearance_test.dart`, `run3_ui_test.dart`; engine `engine_test.dart`; finite safety limits, no commercial habit quota |
| Daily/weekday/N-day/N-days-per-week schedules, effective goals, time zones/day boundaries | Implemented, host tested | Engine `engine_test.dart`, `day_boundary_test.dart`, `timestamp_test.dart`; saved civil days never move |
| Bead check-in, totals/backfill, skip, guarded durable Undo | Implemented, host tested | App `recovery_test.dart`, `run3_ui_test.dart`; engine `data_safety_test.dart`; stale edits refuse |
| Reduction incidents, explicit zero/unknown, day/week ceilings/history | Implemented, host tested | Engine `negative_test.dart`; app `run6_negative_test.dart`; no health auto-completion |
| Pause/vacation, archive, 30-day habit/routine Trash | Implemented, host tested | Engine `pause_test.dart`; app `pause_ui_test.dart`, `trash_ui_test.dart`; mood deletion has separate recoverable history |
| Basic builder, positive habit links, runner, recovery/session summary | Implemented, host tested | App `run4_routines_test.dart`, `recovery_test.dart`; engine `engine_test.dart`; foreground timing only |
| Nine Advanced routine capabilities; saved plans runnable Free | Implemented, host tested | Engine `routine_rules_test.dart`; app `run10_advanced_test.dart`, `pro_test.dart`; Pro author/edit |
| Optional mood/energy/notes/tags, edit/delete/restore | Implemented, host tested | Engine `mood_test.dart`; app `mood_ui_test.dart`; excluded from notification/widget payloads |
| Week/month/year Progress, calendar/heatmap, streaks/consistency, weekly review, sessions | Implemented, host tested/rendered | Engine `run7_progress_test.dart`; app `run7_library_progress_test.dart`; EN/VI store rasters |
| 44 habit / 11 routine templates / 13 collections | Implemented, host tested | Engine `template_catalog_test.dart`; app `run7_library_progress_test.dart`; preview/customize/save |
| Month/quarter/group comparisons, difficulty/misses, suggestions, mood co-occurrence | Implemented, Pro, host tested | Engine `smart_test.dart`; app `run13_smart_studio_test.dart`, `run14_test.dart`; explainable, no causation/medical claim |
| Focused heatmaps and designed insight PDF | Implemented, Pro, host tested/rendered | Same tests; core Progress and ordinary exports Free |
| Three Studio palettes, Today layout/spacing, six extra icons, runner appearance | Implemented, Pro apply, host tested | `run13_smart_studio_test.dart`, `contrast_test.dart`; Free preview/fallback retains choices |
| Saved Habits/Progress views; batch archive/group/pause/existing reminder times | Implemented, Pro, host tested | Engine `convenience_test.dart`; app `run15_test.dart`, `run16_release_test.dart`; checked preview/one Undo |
| Routine-finished +1 / collection-holiday local rules | Implemented, Pro, host tested | Same tests and `run15_reliability_test.dart`; foreground, no chains, <=50 definitions |
| JSON/ZIP/sealed backup, CSV import/export, preview/copy-merge/replace/recovery | Implemented, Free, host tested | Engine `data_safety_test.dart`; app `restore_ui_test.dart`, `export_test.dart`, `store_test.dart`; [architecture](BACKUP_ARCHITECTURE.md) |
| Rotating automatic folder backups | Source wired, host UI tested | Shared kit; lifecycle opportunities, not terminated-app scheduling; actual providers pending |
| Causal sync and Android Drive appdata provider | Implemented, host tested | Engine `sync_test.dart`; app `drive_provider_test.dart`, `drive_sync_test.dart`, `sync_ui_test.dart`; actual OAuth/two-device delivery pending |
| Windows folder sync | Implemented, host process/folder tested | `folder_sync_test.dart`, `run15_reliability_test.dart`; two physical PCs/vendor client pending |
| Reminders, quiet/private text, diagnostics/test | Source/host tested; delivery pending | App `device_test.dart`, `run14_test.dart`; Android/iOS/Windows source, Web in-app only |
| Three Android widgets, compact/large/privacy/Studio palette/launch links | Source/feed tested; launcher QA pending | App `run14_test.dart`; native Kotlin renderer; no closed-app midnight refresh |
| Guide, 19 searchable EN/VI help topics, settings, keyboard/reduced motion | Implemented, host tested/rendered | `run5_learning_test.dart`, `run11_consistency_test.dart`, `run16_release_test.dart`; phone practice headline now 30 logical px too |
| Android Play Lifetime, localized price/restore/verified cache, ads removal | Source + fake-store host tested | `pro_test.dart`; active product/draft uploads supervisor-reported; real transactions pending |
| iCloud, non-Android checkout/widgets, health adapters, dynamic OS shortcuts | Not implemented/not offered | Honest platform copy; no completion claim |
| Very large histories/initial sync | Partial | [Measured capacity](PERFORMANCE.md); 30 MB transport/200k rows per list, compaction/segmentation outstanding |

Supervisor reports the previous debug build starts and shows the guide on two
Android 11 BlueStacks instances. This is limited emulator evidence for that binary,
not final R27, physical-phone, cloud-convergence or transaction certification.
