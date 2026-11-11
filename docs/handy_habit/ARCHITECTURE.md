# Handy Habit architecture and audit

Audit before implementation, 2026-11-01: eight independent apps, nineteen shared packages,
Flutter 3.44.9/Dart 3.12.2, plain controllers and Navigator, shared HandyApp/kit,
SQLite 3.5.2 workers and browser IndexedDB. Reuse existing pinned dependencies;
no Riverpod/router replacement, backend, AI, generic timer/flashcard/work tracking.

Add handy_habit and handy_habit_engine. Reuse handy_ui, handy_core ZIP safeguards,
handy_files, handy_notifications DeviceNotifications, and real monetization adapters.
Native SQLite uses indexed entities/logs with revision CAS and WAL/FULL, worker isolates;
Web IndexedDB uses one atomic transaction. Habit and routine state share one commit
for linked completion. New isolated namespace com.example.handysuite.habit; provisional
store IDs and no live publisher configuration. Never open another app's database.

Baseline: habit-baseline-tests.log passed engine/UI. Baseline analyze found existing
Spend today_page missing plan/recurring.dart and openBillEditor. Web Spend build exit0
but source changed during execution; not stable snapshot evidence. Preserve these edits.

Implementation now has nine apps and twenty shared packages. `handy_habit_engine` owns
calendar, streaks, state validation, routine transitions, reminders and portable
formats. App owns controller, native/IDB repositories, permission adapter and screens.
No fork of the shared UI library. Four requested mobile areas, adaptive rail and web
named routes; one vermilion hue (#B42318), bead strings for one-tap check-in and a step-by-step runner (UI rebuilt 2026-11-02). See the
mandatory design contract in ../UX_REDESIGN.md. Native workers never write UI state;
controller publishes only after commit. App-specific fingerprints include all shared
packages/root config and exclude other app edits, preserving honest build evidence
while a separate session edits existing apps. Test-only file sinks are not production
implementations or proof of OS provider access.

Run15/schema9: convenience rules remain pure Dart, with local configuration and
named markers backed up in settings; effects use normal causal data rows. The
controller records each rule's Undo batch and commits source/effects atomically.
SQLite computes row deltas in a worker; IndexedDB queues deltas inside CAS.
Validation/hash caches are weak and keyed by immutable snapshots/operations;
replacements/redactions revalidate. Appearance notifications are independent of
domain changes, keeping the app wrapper stable. A scope caches each state's index.
Windows folder sync reuses the R15 driver/protocol over a separate local metadata
file and immutable folder provider. Vendor clients only carry the files.
Capacity/main-isolate limitations and unfinished checkpoint design are documented
in [PERFORMANCE](PERFORMANCE.md); R26 is not complete.
