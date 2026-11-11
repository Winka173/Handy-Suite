# Sync architecture

Free, optional, off by default; local data remains usable offline. Engine
`src/sync.dart` / `causal.dart`; app `sync/drive_sync.dart`, `drive_provider.dart`,
`folder_provider.dart`, `folder_sync.dart` (authorization is in `drive_sync.dart`).
Protocol 1, domain schema 9, physical schema 2.

Writers emit immutable checksummed operation generations and per-device receipts,
avoiding a shared last-write-wins file/lock. Download/validate before upload;
unknown schema/protocol/corruption refuses. Apply in one durable CAS commit.
Additive check-ins/incidents union; concurrent absolute totals, skip/add and mood
alternatives stay Needs review until resolved explicitly. Exact Undo targets
observed contributions. IDs/ancestry/tombstones/session snapshots prevent
duplicates, stale resurrection and replay. Incoming active runs never start
timers; excess concurrent active runs become aborted recovery records.

| Platform | Source | Evidence / remaining |
| --- | --- | --- |
| Android | Data Sync only with `HANDY_DRIVE_SYNC=true`; Android Google sign-in, Drive appdata scope only; status/pending/activity/retry/Sync now/off/disconnect | Fake HTTP/SDK/controller/widget tests; actual signing/OAuth/consent/accounts/two-device delivery pending |
| Windows | Sync through a folder, chosen local directory, same causal generations/merge; vendor client optional for transport | Temporary-folder/process/interruption tested; two physical PCs/cloud client pending |
| iOS | No iCloud/Drive adapter/entitlement | Manual backup migration |
| Web | No automatic cloud/folder sync | Manual upload/download |

Android needs debug/upload/Play-signing Android OAuth clients, no Web/server
client ID. Tokens session-only. Setup: [RELEASE](RELEASE.md). Windows local Merged
does not prove another PC received files. Incomplete/newer/corrupt/unexpected
conflict copies stop merge. Open/resume, Sync now and active debounced changes
trigger sync; no terminated scheduler/idle filesystem watcher. Off/disconnect/
cancel deletes neither library; reconnect/account change is explicit.

Device clocks/preferences/reminders, running timer anchors, saved views/Studio,
rule definitions/history and credentials excluded. Ordinary rule event/pause
effects do sync. No attachments. Remote generations are not end-to-end encrypted;
sealed backup is separate. No Android↔iOS automatic sync.

Bounds: 30 MB/file, 200k operations, Android enumeration 10k files; no automatic
generation deletion/compaction. Ledger growth can exceed transport before row
guards; refusal never truncates. [Capacity](PERFORMANCE.md). Host convergence/
provider/process tests are not actual OAuth/cloud/device proof.
