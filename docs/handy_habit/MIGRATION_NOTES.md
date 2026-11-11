# Migration notes: schemas 1 through 9

Current writer: engine `habitSchema = 9`. JSON/ZIP accepts every schema 1–9,
normalizes defaults and writes 9 next save. Future schema/protocol refuses before
changes, without blank reset. Older apps cannot read newer exports; retain a
separate ZIP/sealed copy. Domain version is independent of physical SQLite/
IndexedDB 2 and sync protocol 1.

| Introduced | Migration / preservation |
| --- | --- |
| 1 | Original habits/effective schedules/events/routines/sessions/settings; stable IDs, thousandths, civil days retained |
| 2 | Missing pauses becomes empty; inclusive all/chosen-habit ranges |
| 3 | Causal operations/revisions/ancestry/hash baselines, clock policies, Trash/tombstones, durable guarded Undo/order; physical upgrade to 2 |
| 4 | Effective day boundaries; older policies retain midnight; old event dates never move |
| 5 | Missing direction means build; reduction goals/incidents/explicit zero; positive serialization keeps legacy hashes |
| 6 | Missing moods becomes empty; optional/deleted payloads retained, stable identity per civil day |
| 7 | Causal sync projection/conflict alternatives/resolution/materialization, protocol 1; no timestamp winner for check-ins |
| 8 | Advanced logic/blocks/presets, frozen run inputs/choices/trace; old basic plans remain basic; copy import remaps nested references |
| 9 | Saved filters/convenience rules default none, <=100 views/50 rules, local history/guarded Undo; no physical/protocol bump |

SQLite 1→2 preserves first flushed pre-v2 recovery database using VACUUM including
WAL pages. One transaction adds operations/recovery/indexes and user_version 2;
interruption rolls back, retry retains original recovery. IndexedDB 1→2 adds
operations/recovery in upgrade transaction; versionchange closes connections,
blocked tabs report errors. Browser upgrade/quota/interruption remains runtime QA.

Copy-merge remaps IDs, imports reminders off, keeps receiver settings; not sync.
Replace checkpoints receiver first, disables imported rules and commits at new
revision. Pro/credentials/device backup destinations do not migrate in library
files. CSV record versions are separate, not full schema-9 library. R27 introduces
no schema change.

CSV caveat: current schema-9 mood/pause record allowlists omit8, although previous
writers emitted8. Such old CSV records refuse safely; use JSON/ZIP8 for complete
migration. This source-reviewed compatibility gap is tracked in [KNOWN_ISSUES](KNOWN_ISSUES.md).

Evidence: engine `data_safety_test.dart`, `negative_test.dart`, `mood_test.dart`,
`routine_rules_test.dart`, `convenience_test.dart`, `sync_test.dart`; app
`store_test.dart`, `restore_ui_test.dart`, `recovery_test.dart`,
`run15_reliability_test.dart`. Host migration/reopen is separate from installed
upgrade acceptance. [DATA_SCHEMA](DATA_SCHEMA.md) retains historical field
decisions; this table gives current reader behavior.
