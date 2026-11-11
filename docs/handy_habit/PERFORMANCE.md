# Scale and reliability — run 15 (2026-11-11)

R26 is **PARTIAL**. These are Windows host JIT/test-runner measurements, not
release/device timings. The plan's reference-device targets remain unchanged:
feedback p95 <100ms, durable commit p95 <250ms at 100 habits/10k logs, cold start
<2s. No reference device was used. No limits were raised or records omitted.

## Fixtures and method

`packages/handy_habit_engine/tool/scale.dart` generates 1/10/100/500 habits,
1095 daily check-ins per habit (2021–2023), 200 routines with 200 finished
sessions, and 2000 mood entries. January 2024 is the next editable day.
The tiny fixtures deliberately retain the same routine/mood library.

Before is the retained run15 baseline against the committed implementation;
after is the serial run15b host sample. Each engine process starts fresh;
the index precedes the other projections. Today uses a real-font Flutter
390×844 widget render; check-in-to-frame includes controller bookkeeping and
the resulting frame with an in-memory store. It does **not** measure durable
SQLite, input dispatch latency or cloud delivery. Single samples and startup
JIT costs are noisy; differences of a few milliseconds are inconclusive.
The original100-habit process completed after its launcher's45s timeout;
its retained late records are included below. Baseline host load was not
controlled, so these observations are not a precise speedup experiment.

| Metric, ms (before → after) | 1 habit | 10 | 100 | 500 |
| --- | ---: | ---: | ---: | ---: |
| Today build | 505.391 → 457.230 | 127.583 → 114.913 | 900.321 → 151.677 | 18250.722 → 398.944 |
| Check-in to frame, memory | 489.398 → 74.971 | 6968.961 → 89.750 | — → 222.451 | — → 985.228 |
| Index | 4.838 → 4.527 | 11.047 → 8.336 | 270.637 → 42.781 | 10865.112 → 282.916 |
| Engine check-in | 82.828 → 1.729 | 1589.137 → 5.254 | 309064.469 → 38.956 | — → 402.021 |
| Progress year | 1.399 → 1.094 | 3.617 → 3.088 | 16.770 → 17.151 | 96.698 → 54.562 |
| Insights (92 days) | 0.910 → 0.761 | 2.229 → 2.291 | 12.543 → 12.079 | 87.130 → 50.261 |
| ZIP backup + restore | 132.426 → 113.375 | 1468.585 → 224.781 | 239977.008 → 1317.186 | >45s unfinished → capacity refusal (1326.601) |
| In-memory causal merge | 395.814 → 285.249 | 2605.066 → 850.687 | 327929.903 → 6715.043 | — → capacity refusal (1.386) |

“—” means the baseline stopped before that measurement, or the baseline host
check-in was intentionally skipped after the smaller runs stalled. It is not
a zero or a completed timing. A merge timing does not imply a transportable
generation. The 500-habit check-in is a synthetic memory projection only;
the production stores refuse that many rows before writing.

Separate SQLite test: 100 habits/10,000 logs with a seeded causal ledger,
one warmup then five commits. Warmup 118.813ms; sorted warm samples
34.121/39.628/42.355/45.969/92.046ms (nearest-rank p95 = maximum, small sample).
The earlier retained run15 sample was 129.353ms maximum; that is an intermediate
implementation comparison, not a committed-code baseline. Database 15,294,464
bytes; raw backup 9,080,932 bytes; process RSS 337,371,136 bytes. A check-in commits
one event and its ledger operations; unchanged habits are not rewritten.

## Changes and practical limits

- Group binary validation by habit/day instead of rescanning the event list for
  every binary habit and day. Group overflow provenance once.
- Typed immutable copies retain row objects. Weak validation/hash caches skip
  revalidating the same immutable snapshot/operation. Verified ledger appends
  reuse domain validation; replacements/redactions still validate completely.
- SQLite deltas run in a worker isolate; IndexedDB queues per-row deltas within
  its CAS transaction. No full database reread per check-in. Validation runs in
  the originating isolate before the immutable native snapshot is sent.
- Scope caches the index per state. Appearance has a separate notifier; a
  check-in keeps the `HandyApp` wrapper intact. Today retains its bounded rows
  and Show all behavior. Habits search debounces 180ms.
- Large-state validation/index rebuilds still scan the state, and initial sync
  still seeds/full-merges a ledger on the calling isolate. This is unresolved
  work, particularly on web. The 500-habit frame is still about a second.

The parser/storage guard is 200,000 rows per list and the backup/sync guard is
30,000,000 bytes (uncompressed backup data also bounded). Native and browser
stores now reject typed writes above the reader's limit before mutation; the
last committed snapshot remains readable. Sync encoding reports capacity before
returning an oversized generation. No silent truncation or partial restore.

| Fixture | Source JSON bytes | Source ZIP bytes | Causal generation |
| --- | ---: | ---: | --- |
| 1 / 1095 events | 823296 | 52470 | 2773859 bytes |
| 10 / 10950 events | 2521497 | 124279 | 9916772 bytes |
| 100 / 109500 events | 19700967 | 839220 | about 81.6MB; refused |
| 500 / 547500 events | 96927249 | refused | row capacity refusal |

The 81.6MB diagnostic was measured before adding the encoder's refusal; final
regression tests require `HabitSyncCapacity`. A synced ledger can also make the
100-habit backup exceed 30MB. The pre-sync backup success above is not a promise
of backup/sync support for every history of that habit count. Host process RSS
after the engine pipeline was 288/310/438/791MB, respectively; this is not peak
heap and is not evidence of low-memory device support.

Completing R26 needs a separately validated, versioned segmented snapshot and
causal checkpoint protocol, including replica membership/acknowledgements,
offline stale-replica rejoin, tombstone/redaction retention, Undo ancestry,
crash-safe publication and backwards-reader refusal. Deleting old operations or
raising the existing guards would not solve this safely. Keep R26 open.

## Regression and interruption evidence

`test/scale_test.dart`: all fixture sizes, exact totals, invalid rows/hash
rejection; index <10s, engine check-in <20s, year+insights <10s; supported
backup/restore <30s and merge <60s. Capacity failures are asserted explicitly.
Host widget tool: Today/check-in <10s, one commit; durable tool: max of five
warm samples <1s. These generous host regression budgets do not replace the
release acceptance targets above.

Existing native atomic restore/recovery, migration, stale-writer, failure and
sync interruption tests remain. New child processes are killed with SQLite WAL
transactions open (save/restore/schema-change) or folder staging incomplete.
They prove transaction rollback/staging exclusion, not end-to-end OS upgrades.
Automatic-effect write failure rolls its source back; retry/reopen cannot double
it. A typed oversized write is refused before changing the last snapshot.

Reproduce from engine: `dart run tool/scale.dart 100` (repeat for 1/10/500).
From app: `flutter test --no-pub tool/run15_performance_test.dart`, then
`flutter test --no-pub tool/run15_durable_test.dart`. Run serially for timings.
Raw results/logs: `apps/handy_habit/build/run15/engine-final.jsonl`,
`host-resume-final.jsonl`, `durable.json`, `engine-tests.log`, `app-tests.log`.
Retained engine baselines: `artifacts/habit-run15/before-{1,10,100,500}.jsonl`;
the Today baseline is `apps/handy_habit/build/run15/host-before.jsonl`.
