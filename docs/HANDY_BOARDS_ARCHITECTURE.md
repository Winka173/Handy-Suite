# Handy Boards architecture

2026-11-02 audit before coding. Ten independent Flutter apps. Flutter 3.44.9/Dart 3.12.2; retain pins. No AGENTS.md found. Plain controllers/Navigator/Handy kit, native SQLite workers/CAS, per-record IndexedDB, shared files/portable ZIP/notifications/monetization.

Add apps/handy_boards and packages/handy_boards_engine. No imports from other apps. Immutable canonical task UUID across every view. Category/status/tag independent. Optional Study metadata uses ordinary tasks. New isolated schema 1, no migration/reset of other apps. Validate whole state before transaction, revision CAS, publish after commit. Errors preserve old data. Future schemas refuse. Undo/Redo bounded by memory.

Reuse shared UI/files/core/notification/monetization packages and repository patterns, not another app database. Pure Dart domain engine. Windows host can build Android/Windows/Web; iOS/physical/store unavailable. Adapters remain honest about verification.

Implemented continuation: domain parts isolate model validation, commands, planning,
portability and extras. UI modules reuse BoardForm for typed dialogs, with dedicated
multi-condition saved-view builder and canonical exam editor. Domain mutations are
pure; preview never calls persistence/notification adapters. Controller commit
serializes changes, validates, applies real SQLite/IndexedDB CAS, then publishes.
Native task state is never imported across apps. Date-only math uses UTC calendar
arithmetic, timed values use IANA zones and explicit DST ambiguity choices.

Verification tooling records production dependency-closure hashes before/after
host tests, native runs, builds and screenshots. Checkpoint rejects stale artifacts.
Screenshots must be freshly written during their passing run. Native recovery must
retrieve the original process test response; it cannot promote log messages to PASS.
